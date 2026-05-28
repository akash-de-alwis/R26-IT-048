import json
import os

from shared.utils.geo_utils import find_hotspots_within_radius, route_bbox, risk_level_from_score

_HOTSPOT_FILE = os.path.join(os.path.dirname(__file__), "..", "data", "hotspot_risk_scores.json")

with open(_HOTSPOT_FILE, "r", encoding="utf-8") as _f:
    HOTSPOTS: list[dict] = json.load(_f)


def get_all_hotspots() -> list[dict]:
    return HOTSPOTS


def get_hotspot_by_id(hotspot_id: int) -> dict | None:
    for h in HOTSPOTS:
        if h["hotspot_id"] == hotspot_id:
            return h
    return None


def get_hotspots_near_point(lat: float, lon: float, radius_m: float = 300) -> list[dict]:
    return find_hotspots_within_radius(lat, lon, HOTSPOTS, radius_m)


def compute_route_risk(route_points: list[dict]) -> dict:
    """
    route_points: list of {'latitude': float, 'longitude': float}

    Pre-filters hotspots via bounding box, then checks each route point against
    a 250 m radius. Deduplicates hotspots and weights by 1/distance_m so closer
    hotspots contribute more to the composite risk score.

    Returns:
        risk_score      float  0–100 composite
        risk_level      str    HIGH / MEDIUM / LOW
        nearby_hotspots list   unique hotspot dicts each with distance_m
        hotspot_count   int
    """
    # ── 1. Coarse bbox filter ────────────────────────────────────────────────
    PADDING_DEG = 0.003  # ~330 m at equator
    min_lat, max_lat, min_lon, max_lon = route_bbox(route_points)
    candidates = [
        h for h in HOTSPOTS
        if (min_lat - PADDING_DEG) <= h["latitude"] <= (max_lat + PADDING_DEG)
        and (min_lon - PADDING_DEG) <= h["longitude"] <= (max_lon + PADDING_DEG)
    ]

    # ── 2. Fine-grained radius check per route point ─────────────────────────
    ROUTE_RADIUS_M = 250
    seen: dict[int, dict] = {}  # hotspot_id → closest hit dict

    for pt in route_points:
        for hit in find_hotspots_within_radius(
            pt["latitude"], pt["longitude"], candidates, ROUTE_RADIUS_M
        ):
            hid = hit["hotspot_id"]
            if hid not in seen or hit["distance_m"] < seen[hid]["distance_m"]:
                seen[hid] = hit

    nearby = list(seen.values())

    # ── 3. Composite risk score ──────────────────────────────────────────────
    if not nearby:
        return {
            "risk_score": 5.0,
            "risk_level": "LOW",
            "nearby_hotspots": [],
            "hotspot_count": 0,
        }

    def _w(dist_m: float) -> float:
        return 1.0 / max(dist_m, 1.0)

    weighted_sum = sum(h["risk_score"] * _w(h["distance_m"]) for h in nearby)
    weight_total = sum(_w(h["distance_m"]) for h in nearby)
    risk_score = round(weighted_sum / weight_total, 2)

    return {
        "risk_score": risk_score,
        "risk_level": risk_level_from_score(risk_score),
        "nearby_hotspots": sorted(nearby, key=lambda x: x["distance_m"]),
        "hotspot_count": len(nearby),
    }
