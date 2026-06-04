import random
from datetime import datetime
from typing import List
from .schemas import CongestionLevel, TrafficSummary, RouteSegment

CONGESTION_COLORS = {
    CongestionLevel.LOW:      "#00C06A",    # green — free flow
    CongestionLevel.MODERATE: "#FFB300",    # amber — slow
    CongestionLevel.HEAVY:    "#FF8C42",    # orange — congested
    CongestionLevel.SEVERE:   "#FF3B5C",    # red — jam
    CongestionLevel.UNKNOWN:  "#5C6B7A",    # gray — no data
}

# Heavy traffic increases rear-end collision risk
CONGESTION_RISK_MULTIPLIERS = {
    CongestionLevel.LOW:      1.00,
    CongestionLevel.MODERATE: 1.15,
    CongestionLevel.HEAVY:    1.30,
    CongestionLevel.SEVERE:   1.50,
    CongestionLevel.UNKNOWN:  1.10,
}


def parse_congestion(level_str: str) -> CongestionLevel:
    if not level_str:
        return CongestionLevel.UNKNOWN
    try:
        return CongestionLevel(level_str.lower())
    except ValueError:
        return CongestionLevel.UNKNOWN


def _synthetic_congestion_for_road(
    road_class: str, hour: int, is_weekend: bool
) -> CongestionLevel:
    """
    Generate realistic synthetic traffic congestion based on:
    - Road class (motorways congest less per km, residentials more)
    - Time of day (peak hours = more congestion)
    - Weekday vs weekend patterns

    Used when Mapbox returns 'unknown' for the region.
    Based on Sri Lankan urban traffic research patterns.
    """
    if is_weekend:
        # Weekend: peaks at 11am-1pm and 5pm-8pm
        if 10 <= hour <= 13:
            base_prob = 0.55
        elif 17 <= hour <= 20:
            base_prob = 0.65
        elif hour >= 22 or hour <= 5:
            base_prob = 0.10
        else:
            base_prob = 0.35
    else:
        # Weekday: morning + evening commute peaks
        if 7 <= hour <= 9:
            base_prob = 0.85
        elif 16 <= hour <= 19:
            base_prob = 0.80
        elif 12 <= hour <= 14:
            base_prob = 0.50
        elif hour >= 22 or hour <= 5:
            base_prob = 0.05
        else:
            base_prob = 0.30

    road_multipliers = {
        'motorway':     0.5,
        'trunk':        0.7,
        'primary':      1.0,    # most congested (Galle Road etc)
        'secondary':    0.85,
        'tertiary':     0.65,
        'residential':  0.45,
        'service':      0.30,
        'unclassified': 0.55,
    }
    multiplier = road_multipliers.get(road_class, 0.6)
    final_prob = min(1.0, base_prob * multiplier)

    roll = random.random()
    if roll < final_prob * 0.20:
        return CongestionLevel.SEVERE
    if roll < final_prob * 0.45:
        return CongestionLevel.HEAVY
    if roll < final_prob * 0.80:
        return CongestionLevel.MODERATE
    return CongestionLevel.LOW


def synthesize_traffic_for_route(route: dict, road_breakdown: list) -> List[RouteSegment]:
    """
    Generate synthetic per-segment traffic when Mapbox returns 'unknown'.
    Uses step-level road class information to vary congestion realistically.
    """
    geometry = route['geometry']['coordinates']
    steps = route['legs'][0].get('steps', [])

    now = datetime.now()
    hour = now.hour
    is_weekend = now.weekday() >= 5

    # Seed per route so the same route stays consistent within a session
    route_seed = int(route['distance']) + hour
    random.seed(route_seed)

    segments = []

    for step in steps:
        step_distance = step.get('distance', 0)
        step_geometry = step.get('geometry', {}).get('coordinates', [])

        if not step_geometry or len(step_geometry) < 2:
            continue

        # Determine road class for this step
        road_class = 'unclassified'
        intersections = step.get('intersections', [])
        if intersections:
            classes = intersections[0].get('classes', [])
            if classes:
                road_class = classes[0].replace('_link', '')

        congestion = _synthetic_congestion_for_road(road_class, hour, is_weekend)

        segments.append(RouteSegment(
            geometry=step_geometry,
            congestion=congestion,
            distance_m=step_distance,
            color=CONGESTION_COLORS[congestion],
        ))

    # Fallback if no steps produced segments
    if not segments:
        segments.append(RouteSegment(
            geometry=geometry,
            congestion=CongestionLevel.LOW,
            distance_m=route['distance'],
            color=CONGESTION_COLORS[CongestionLevel.LOW],
        ))

    return segments


def build_segments_from_route(route: dict) -> List[RouteSegment]:
    """
    Mapbox returns congestion as a list of strings per segment between
    consecutive geometry coordinates. Groups consecutive identical
    congestion values into single segments for UI rendering.

    Falls back to synthetic congestion when Mapbox returns no real data.
    """
    leg = route['legs'][0]
    annotations = leg.get('annotation', {})
    congestion_list = annotations.get('congestion', [])

    # If congestion data is absent or entirely unknown, use synthetic fallback
    has_real_data = any(
        c and c != 'unknown' for c in congestion_list
    )

    if not has_real_data:
        return synthesize_traffic_for_route(route, [])

    geometry = route['geometry']['coordinates']  # [[lng,lat], ...]
    distance_list = annotations.get('distance', [])

    segments = []
    current_coords = [geometry[0]]
    current_level = parse_congestion(congestion_list[0])
    current_distance = 0

    for i, level_str in enumerate(congestion_list):
        level = parse_congestion(level_str)
        seg_distance = distance_list[i] if i < len(distance_list) else 0

        if level == current_level:
            current_coords.append(geometry[i + 1])
            current_distance += seg_distance
        else:
            segments.append(RouteSegment(
                geometry=current_coords,
                congestion=current_level,
                distance_m=current_distance,
                color=CONGESTION_COLORS[current_level]))
            current_coords = [geometry[i], geometry[i + 1]]
            current_level = level
            current_distance = seg_distance

    if len(current_coords) >= 2:
        segments.append(RouteSegment(
            geometry=current_coords,
            congestion=current_level,
            distance_m=current_distance,
            color=CONGESTION_COLORS[current_level]))

    return segments


def summarize_traffic(segments: List[RouteSegment]) -> TrafficSummary:
    """
    Compute percentage of total route distance in each congestion band.
    Overall level is the worst band covering ≥20% of the route.
    """
    if not segments:
        return TrafficSummary(
            overall_level=CongestionLevel.UNKNOWN,
            low_pct=0, moderate_pct=0, heavy_pct=0, severe_pct=0)

    total = sum(s.distance_m for s in segments) or 1

    distance_by_level = {
        CongestionLevel.LOW: 0, CongestionLevel.MODERATE: 0,
        CongestionLevel.HEAVY: 0, CongestionLevel.SEVERE: 0,
        CongestionLevel.UNKNOWN: 0,
    }
    for s in segments:
        distance_by_level[s.congestion] += s.distance_m

    pcts = {k: (v / total) * 100 for k, v in distance_by_level.items()}

    overall = CongestionLevel.LOW
    if pcts[CongestionLevel.SEVERE] >= 20:
        overall = CongestionLevel.SEVERE
    elif pcts[CongestionLevel.HEAVY] >= 20:
        overall = CongestionLevel.HEAVY
    elif pcts[CongestionLevel.MODERATE] >= 25:
        overall = CongestionLevel.MODERATE

    return TrafficSummary(
        overall_level=overall,
        low_pct=round(pcts[CongestionLevel.LOW], 1),
        moderate_pct=round(pcts[CongestionLevel.MODERATE], 1),
        heavy_pct=round(pcts[CongestionLevel.HEAVY], 1),
        severe_pct=round(pcts[CongestionLevel.SEVERE], 1))


def avg_congestion_risk(segments: List[RouteSegment]) -> float:
    """Distance-weighted average congestion risk multiplier (1.0–1.5)."""
    if not segments:
        return 1.0
    total = sum(s.distance_m for s in segments) or 1
    weighted = sum(
        CONGESTION_RISK_MULTIPLIERS[s.congestion] * s.distance_m
        for s in segments)
    return weighted / total
