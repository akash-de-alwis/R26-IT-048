from __future__ import annotations

import logging
import os
import pickle
import warnings

import numpy as np

from .hotspot_service import get_hotspots_near_point

logger = logging.getLogger(__name__)

# ── SECTION 1: Model loading ─────────────────────────────────────────────────

_MODEL_FILE = os.path.join(os.path.dirname(__file__), "..", "data", "risk_model.pkl")

MODEL = None
FEATURE_COLS: list[str] = []

try:
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        with open(_MODEL_FILE, "rb") as _f:
            _pkg = pickle.load(_f)
    MODEL = _pkg["model"]
    FEATURE_COLS = _pkg["feature_cols"]
    logger.info("Loaded %s (ROC-AUC %.4f)", _pkg.get("model_name"), _pkg.get("roc_auc"))
except FileNotFoundError:
    logger.warning("risk_model.pkl not found — prediction will use fallback defaults.")
except Exception as exc:
    logger.warning("Could not load risk_model.pkl: %s", exc)

# ── SECTION 2: Feature engineering ───────────────────────────────────────────

_VEHICLE_COLS = [
    "vehicle_Bus", "vehicle_Car", "vehicle_Jeep", "vehicle_Lorry",
    "vehicle_Motorcycle", "vehicle_Three Wheeler", "vehicle_Van",
]

_CAUSE_COLS = [
    "cause_Bad Visibility", "cause_Careless Driving", "cause_Driver Fatigue",
    "cause_Out of Control", "cause_Overtaking", "cause_Speeding",
    "cause_Vehicle Malfunction",
]

_ROAD_COLS = [
    "road_Aruggoda Road", "road_Galle Road", "road_Hirana Road",
    "road_Horana Road", "road_Morawinna Road", "road_Old Galle Road", "road_Other",
]

_PERIOD_COLS = [
    "period_Afternoon", "period_Evening", "period_Late Night",
    "period_Morning", "period_Night",
]


def _derive_period(hour: int) -> str:
    if 6 <= hour <= 11:
        return "period_Morning"
    if 12 <= hour <= 16:
        return "period_Afternoon"
    if 17 <= hour <= 20:
        return "period_Evening"
    if 21 <= hour <= 23:
        return "period_Night"
    return "period_Late Night"  # 0–5


def build_feature_vector(request_data: dict) -> list:
    vec: dict[str, int] = {col: 0 for col in FEATURE_COLS}

    # Temporal
    vec["hour"] = request_data["hour"]
    vec["day_of_week"] = request_data["day_of_week"]
    vec["month"] = request_data["month"]
    vec["is_night"] = request_data["is_night"]
    vec["is_weekend"] = request_data["is_weekend"]

    # Vehicle one-hot
    vehicle_col = f"vehicle_{request_data['vehicle_type']}"
    if vehicle_col in vec:
        vec[vehicle_col] = 1

    # Cause columns — unknown at prediction time, stay 0

    # Road columns — unknown at prediction time, stay 0

    # Period one-hot
    vec[_derive_period(request_data["hour"])] = 1

    return [vec[col] for col in FEATURE_COLS]


# ── SECTION 3: Prediction ─────────────────────────────────────────────────────

def predict_risk(request_data: dict) -> dict:
    if MODEL is None:
        return {
            "risk_probability": 0.5,
            "risk_score": 50.0,
            "risk_level": "MEDIUM",
        }

    features = np.array([build_feature_vector(request_data)])
    proba = MODEL.predict_proba(features)
    risk_probability = float(proba[0][1])
    risk_score = round(risk_probability * 100, 1)

    if risk_score >= 65:
        risk_level = "HIGH"
    elif risk_score >= 40:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW"

    # Hotspot proximity boost: nearby HIGH hotspot elevates LOW → MEDIUM
    if risk_level == "LOW":
        nearby = get_hotspots_near_point(
            request_data["latitude"], request_data["longitude"], radius_m=300
        )
        if any(h["risk_score"] >= 70 for h in nearby):
            risk_level = "MEDIUM"

    return {
        "risk_probability": round(risk_probability, 4),
        "risk_score": risk_score,
        "risk_level": risk_level,
    }
