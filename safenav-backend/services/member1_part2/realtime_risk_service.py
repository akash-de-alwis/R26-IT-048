import pickle
import os
import json
from datetime import datetime
from math import radians, sin, cos, asin, sqrt

from .schemas import (
    RealtimeRiskRequest,
    RealtimeRiskResponse,
    RiskLevel,
    RiskFactor,
    VehicleType,
    WeatherCondition,
    RoadCondition,
    WeatherSnapshot,
)
from .weather_service import get_current_weather
from .road_condition_service import infer_road_condition

MODEL_PATH = os.path.join(
    os.path.dirname(__file__), '..', '..', 'risk_model.pkl')

HOTSPOTS_PATH = os.path.join(
    os.path.dirname(__file__), '..', '..', 'hotspot_risk_scores.json')

_model_bundle = None
_hotspots = None


def _load_model():
    global _model_bundle
    if _model_bundle is None:
        with open(MODEL_PATH, 'rb') as f:
            _model_bundle = pickle.load(f)
    return _model_bundle


def _load_hotspots():
    global _hotspots
    if _hotspots is None:
        with open(HOTSPOTS_PATH) as f:
            _hotspots = json.load(f)
    return _hotspots


# ── Multipliers (research-backed) ────────────────────────────────────────────

WEATHER_MULTIPLIERS = {
    WeatherCondition.CLEAR: 1.00,
    WeatherCondition.CLOUDS: 1.05,
    WeatherCondition.MIST: 1.30,
    WeatherCondition.FOG: 1.50,
    WeatherCondition.RAIN: 1.40,
    WeatherCondition.HEAVY_RAIN: 1.70,
    WeatherCondition.THUNDERSTORM: 1.85,
}

ROAD_CONDITION_MULTIPLIERS = {
    RoadCondition.DRY: 1.00,
    RoadCondition.WET: 1.20,
    RoadCondition.SLIPPERY: 1.50,
    RoadCondition.POOR_VISIBILITY: 1.45,
}

VEHICLE_BASE_MULTIPLIERS = {
    VehicleType.CAR: 1.00,
    VehicleType.VAN: 1.05,
    VehicleType.JEEP: 1.05,
    VehicleType.BUS: 1.15,
    VehicleType.LORRY: 1.20,
    VehicleType.THREE_WHEELER: 1.25,
    VehicleType.MOTORCYCLE: 1.40,
}


def speed_multiplier(speed_kmh: float) -> float:
    """Risk grows non-linearly with speed."""
    if speed_kmh < 30:
        return 0.85
    if speed_kmh < 50:
        return 1.00
    if speed_kmh < 70:
        return 1.20
    if speed_kmh < 90:
        return 1.50
    if speed_kmh < 110:
        return 1.85
    return 2.20


def haversine_m(lat1, lon1, lat2, lon2) -> float:
    R = 6371000
    dLat = radians(lat2 - lat1)
    dLon = radians(lon2 - lon1)
    a = (sin(dLat / 2) ** 2
         + cos(radians(lat1)) * cos(radians(lat2)) * sin(dLon / 2) ** 2)
    return 2 * R * asin(sqrt(a))


def hotspot_proximity_multiplier(lat: float, lon: float):
    """Return (multiplier, nearest_distance_m)."""
    hotspots = _load_hotspots()
    if not hotspots:
        return (1.0, None)

    nearest_dist = float('inf')
    nearest_risk = 0

    for h in hotspots:
        d = haversine_m(lat, lon, h['latitude'], h['longitude'])
        if d < nearest_dist:
            nearest_dist = d
            nearest_risk = h['risk_score']

    if nearest_dist > 500:
        return (1.0, nearest_dist)

    distance_factor = max(0, (500 - nearest_dist) / 500)
    risk_factor = nearest_risk / 100
    multiplier = 1.0 + (distance_factor * risk_factor * 0.6)

    return (multiplier, nearest_dist)


def base_model_probability(lat: float, lon: float, vehicle_type: str) -> float:
    """Use the existing trained model to get baseline severity probability."""
    bundle = _load_model()
    model = bundle['model']
    feature_cols = bundle['feature_cols']

    now = datetime.now()
    hour = now.hour
    dow = now.weekday()
    month = now.month
    is_weekend = 1 if dow >= 5 else 0
    is_night = 1 if (hour < 6 or hour >= 20) else 0

    features = {col: 0 for col in feature_cols}
    features['hour'] = hour
    features['day_of_week'] = dow
    features['month'] = month
    features['is_weekend'] = is_weekend
    features['is_night'] = is_night

    veh_key = f'vehicle_{vehicle_type}'
    if veh_key in features:
        features[veh_key] = 1

    if 6 <= hour < 12:
        features['period_Morning'] = 1
    elif 12 <= hour < 17:
        features['period_Afternoon'] = 1
    elif 17 <= hour < 20:
        features['period_Evening'] = 1
    elif 20 <= hour < 24:
        features['period_Night'] = 1
    else:
        features['period_Late Night'] = 1

    feature_vector = [features[c] for c in feature_cols]
    proba = model.predict_proba([feature_vector])[0][1]
    return float(proba)


# ── Main entry point ──────────────────────────────────────────────────────────

async def predict_realtime_risk(req: RealtimeRiskRequest) -> RealtimeRiskResponse:
    if req.bypass_weather:
        weather = WeatherSnapshot(
            condition=WeatherCondition.CLEAR,
            temperature_c=28.0,
            humidity_pct=70,
            wind_speed_kmh=10,
            visibility_m=10000,
            description='Bypassed',
        )
    else:
        weather = await get_current_weather(req.latitude, req.longitude)

    road = infer_road_condition(weather)

    base_proba = base_model_probability(
        req.latitude, req.longitude, req.vehicle_type)

    spd_mult = speed_multiplier(req.speed_kmh)
    wx_mult = WEATHER_MULTIPLIERS[weather.condition]
    road_mult = ROAD_CONDITION_MULTIPLIERS[road]
    veh_mult = VEHICLE_BASE_MULTIPLIERS[req.vehicle_type]
    hs_mult, nearest_dist = hotspot_proximity_multiplier(
        req.latitude, req.longitude)

    # Calibrate the base probability — the model was trained on
    # accident records only (no negative samples), so its baseline
    # overestimates risk. Apply a calibration factor of 0.4.
    calibrated_base = base_proba * 0.4

    combined = (calibrated_base * spd_mult * wx_mult
                * road_mult * veh_mult * hs_mult)
    risk_score = min(100, combined * 100)

    if risk_score >= 70:
        level = RiskLevel.CRITICAL
        color = '#FF3B5C'
    elif risk_score >= 50:
        level = RiskLevel.HIGH
        color = '#FF8C42'
    elif risk_score >= 25:
        level = RiskLevel.MODERATE
        color = '#FFB300'
    else:
        level = RiskLevel.LOW
        color = '#00C06A'

    total_boost = spd_mult + wx_mult + road_mult + veh_mult + hs_mult
    factors = [
        RiskFactor(
            name='Vehicle Type',
            value=req.vehicle_type,
            multiplier=veh_mult,
            contribution_pct=round((veh_mult / total_boost) * 100, 1),
        ),
        RiskFactor(
            name='Current Speed',
            value=f'{req.speed_kmh:.0f} km/h',
            multiplier=spd_mult,
            contribution_pct=round((spd_mult / total_boost) * 100, 1),
        ),
        RiskFactor(
            name='Weather',
            value=weather.description.title(),
            multiplier=wx_mult,
            contribution_pct=round((wx_mult / total_boost) * 100, 1),
        ),
        RiskFactor(
            name='Road Condition',
            value=road.value.replace('_', ' ').title(),
            multiplier=road_mult,
            contribution_pct=round((road_mult / total_boost) * 100, 1),
        ),
        RiskFactor(
            name='Hotspot Proximity',
            value=f'{int(nearest_dist)}m' if nearest_dist else 'N/A',
            multiplier=hs_mult,
            contribution_pct=round((hs_mult / total_boost) * 100, 1),
        ),
    ]
    factors.sort(key=lambda f: f.multiplier, reverse=True)

    recommendation = _generate_recommendation(level, req.speed_kmh, weather, road)

    return RealtimeRiskResponse(
        risk_score=round(risk_score, 1),
        risk_level=level,
        risk_color=color,
        base_model_probability=round(base_proba, 4),
        speed_multiplier=spd_mult,
        weather_multiplier=wx_mult,
        road_condition_multiplier=road_mult,
        hotspot_proximity_multiplier=round(hs_mult, 3),
        nearest_hotspot_distance_m=(
            round(nearest_dist, 1) if nearest_dist else None),
        weather=weather,
        road_condition=road,
        contributing_factors=factors,
        recommendation=recommendation,
        timestamp=datetime.now().isoformat(),
    )


def _generate_recommendation(level, speed, weather, road) -> str:
    if level == RiskLevel.CRITICAL:
        return ('CRITICAL risk conditions. Reduce speed immediately, '
                'increase following distance, consider stopping if unsafe.')
    if level == RiskLevel.HIGH:
        if speed > 70:
            return 'High risk. Reduce speed below 60 km/h.'
        if weather.condition in (WeatherCondition.HEAVY_RAIN,
                                  WeatherCondition.THUNDERSTORM):
            return 'High risk due to weather. Use headlights and slow down.'
        if road == RoadCondition.POOR_VISIBILITY:
            return ('Visibility is low. Use fog lights and maintain '
                    'extra following distance.')
        return 'High accident risk in this area. Drive defensively.'
    if level == RiskLevel.MODERATE:
        return 'Moderate risk. Stay alert and obey speed limits.'
    return 'Conditions are good. Drive safely.'
