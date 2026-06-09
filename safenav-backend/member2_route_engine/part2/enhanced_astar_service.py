import json
import os
from datetime import datetime
from math import radians, sin, cos, asin, sqrt
from typing import List

from .schemas import (EnhancedRouteRequest, EnhancedRouteResponse,
                      EnhancedRoute, RouteType)
from .mapbox_directions_service import (
    fetch_route_alternatives,
    fetch_route_via_waypoint,
    compute_perpendicular_waypoints,
)
from .traffic_service import (build_segments_from_route,
                               summarize_traffic, avg_congestion_risk)
from .road_type_service import (extract_road_types, avg_road_type_risk,
                                 primary_class, ROAD_CLASS_LABELS)

HOTSPOTS_PATH = os.path.normpath(os.path.join(
    os.path.dirname(__file__), '..', '..',
    'member1_risk_prediction', 'data', 'hotspot_risk_scores.json'))

_hotspots = None


def _load_hotspots():
    global _hotspots
    if _hotspots is None:
        with open(HOTSPOTS_PATH) as f:
            _hotspots = json.load(f)
    return _hotspots


def haversine_m(lat1, lon1, lat2, lon2):
    R = 6371000
    dLat = radians(lat2 - lat1)
    dLon = radians(lon2 - lon1)
    a = (sin(dLat / 2) ** 2 +
         cos(radians(lat1)) * cos(radians(lat2)) * sin(dLon / 2) ** 2)
    return 2 * R * asin(sqrt(a))


def count_hotspots_on_route(geometry, threshold_m: float = 150) -> int:
    """Count unique hotspots within 150 m of the route geometry."""
    hotspots = _load_hotspots()
    nearby = set()

    sample_step = max(1, len(geometry) // 50)
    sampled = geometry[::sample_step]

    for lng, lat in sampled:
        for h in hotspots:
            d = haversine_m(lat, lng, h['latitude'], h['longitude'])
            if d < threshold_m:
                nearby.add(h['hotspot_id'])
    return len(nearby)


def total_hotspot_risk_on_route(geometry, threshold_m: float = 150) -> float:
    """Sum of risk scores of all hotspots near the route."""
    hotspots = _load_hotspots()
    near_hotspots = {}

    sample_step = max(1, len(geometry) // 50)
    sampled = geometry[::sample_step]

    for lng, lat in sampled:
        for h in hotspots:
            if h['hotspot_id'] in near_hotspots:
                continue
            d = haversine_m(lat, lng, h['latitude'], h['longitude'])
            if d < threshold_m:
                near_hotspots[h['hotspot_id']] = h['risk_score']

    return sum(near_hotspots.values())


# ── Scoring weight profiles ────────────────────────────────────────────────
ROUTE_WEIGHT_PROFILES = {
    RouteType.SAFEST: {
        'distance':  0.10,
        'time':      0.15,
        'hotspot':   0.45,
        'traffic':   0.15,
        'road_type': 0.15,
    },
    RouteType.BALANCED: {
        'distance':  0.20,
        'time':      0.30,
        'hotspot':   0.20,
        'traffic':   0.15,
        'road_type': 0.15,
    },
    RouteType.FASTEST: {
        'distance':  0.15,
        'time':      0.55,
        'hotspot':   0.10,
        'traffic':   0.15,
        'road_type': 0.05,
    },
}


def score_route(route: dict, profile: RouteType) -> float:
    """Returns normalized cost — lower is better for the given profile."""
    weights = ROUTE_WEIGHT_PROFILES[profile]

    distance_norm = route['distance'] / 1000
    time_norm = route['duration'] / 60
    hotspot_risk = total_hotspot_risk_on_route(
        route['geometry']['coordinates']) / 100

    segments = build_segments_from_route(route)
    congestion_risk = avg_congestion_risk(segments)

    road_types = extract_road_types(route)
    road_risk = avg_road_type_risk(road_types)

    return (
        weights['distance']  * distance_norm +
        weights['time']      * time_norm +
        weights['hotspot']   * hotspot_risk +
        weights['traffic']   * (congestion_risk - 1.0) * 10 +
        weights['road_type'] * (road_risk - 1.0) * 10
    )


ROUTE_COLORS = {
    RouteType.SAFEST:   '#00C06A',
    RouteType.BALANCED: '#2979FF',
    RouteType.FASTEST:  '#FF8C42',
}

ROUTE_BADGES = {
    RouteType.SAFEST:   'Recommended',
    RouteType.BALANCED: 'Balanced',
    RouteType.FASTEST:  'Fastest',
}

ROUTE_LABELS = {
    RouteType.SAFEST:   'Safest Route',
    RouteType.BALANCED: 'Balanced Route',
    RouteType.FASTEST:  'Fastest Route',
}


def build_enhanced_route(route: dict, profile: RouteType) -> EnhancedRoute:
    geometry = route['geometry']['coordinates']
    segments = build_segments_from_route(route)
    traffic = summarize_traffic(segments)
    road_types = extract_road_types(route)
    primary = primary_class(road_types)

    distance_m = route['distance']
    duration = route['duration']
    duration_typical = route.get('duration_typical', duration)

    hotspot_count = count_hotspots_on_route(geometry)
    hotspot_risk = total_hotspot_risk_on_route(geometry)
    congestion_mult = avg_congestion_risk(segments)
    road_mult = avg_road_type_risk(road_types)

    # Risk score on 0-100 scale — wider weighting for visible differentiation
    hotspot_component = min(hotspot_risk / 3.5, 55)
    traffic_component = (congestion_mult - 1.0) * 90
    road_component = (road_mult - 1.0) * 70

    risk_components = hotspot_component + traffic_component + road_component

    # Profile adjustment: safest routes earn a bonus, fastest a penalty
    if profile == RouteType.SAFEST:
        risk_components *= 0.85
    elif profile == RouteType.FASTEST:
        risk_components *= 1.12

    risk_score = min(100, max(5, risk_components))
    safety_score = 100 - risk_score

    summary = _build_summary(profile, hotspot_count, traffic, primary)

    return EnhancedRoute(
        route_type=profile,
        geometry=geometry,
        segments=segments,
        distance_m=distance_m,
        duration_seconds=duration_typical,
        duration_in_traffic_seconds=duration,
        safety_score=round(safety_score, 1),
        risk_score=round(risk_score, 1),
        hotspots_on_route=hotspot_count,
        traffic=traffic,
        road_type_breakdown=road_types,
        primary_road_class=primary,
        color=ROUTE_COLORS[profile],
        label=ROUTE_LABELS[profile],
        badge=ROUTE_BADGES[profile],
        summary=summary)


def _build_summary(profile, hotspot_count, traffic, primary_road) -> str:
    parts = []

    if traffic.overall_level.value in ['heavy', 'severe']:
        parts.append(f"{traffic.overall_level.value.title()} traffic")
    elif traffic.overall_level.value == 'low':
        parts.append("Clear traffic")

    if hotspot_count == 0:
        parts.append("no hotspots")
    elif hotspot_count == 1:
        parts.append("1 hotspot")
    else:
        parts.append(f"{hotspot_count} hotspots")

    parts.append(f"mostly {ROAD_CLASS_LABELS[primary_road].lower()}")

    return ", ".join(parts).capitalize()


def _routes_are_similar(route_a: dict, route_b: dict) -> bool:
    """
    True if two routes are essentially the same path — distance within
    5% AND midpoints within ~110 m (0.001 deg).
    """
    da = route_a['distance']
    db = route_b['distance']
    if abs(da - db) / max(da, db, 1) >= 0.05:
        return False
    ga = route_a['geometry']['coordinates']
    gb = route_b['geometry']['coordinates']
    if not ga or not gb:
        return True
    ma = ga[len(ga) // 2]
    mb = gb[len(gb) // 2]
    return abs(ma[1] - mb[1]) < 0.001 and abs(ma[0] - mb[0]) < 0.001


async def _fill_with_detours(
    unique_routes: list,
    req: 'EnhancedRouteRequest',
    offset_km: float,
) -> None:
    """Attempt to add detour routes (in-place) until we have 3."""
    waypoints = compute_perpendicular_waypoints(
        req.origin, req.destination, offset_km=offset_km)
    for wp in waypoints:
        if len(unique_routes) >= 3:
            return
        route = await fetch_route_via_waypoint(req.origin, wp, req.destination)
        if route and not any(_routes_are_similar(route, u) for u in unique_routes):
            unique_routes.append(route)


async def get_enhanced_routes(
    req: EnhancedRouteRequest,
) -> EnhancedRouteResponse:
    """
    Fetch up to 3 genuinely different routes. When Mapbox returns fewer
    than 3 alternatives, perpendicular-waypoint detours are used to
    force additional diversified paths.
    """
    # Step 1 — natural alternatives
    raw_routes = await fetch_route_alternatives(req.origin, req.destination)
    if not raw_routes:
        raise ValueError("No routes returned by Mapbox")

    # Step 2 — deduplicate
    unique_routes: list = [raw_routes[0]]
    for r in raw_routes[1:]:
        if not any(_routes_are_similar(r, u) for u in unique_routes):
            unique_routes.append(r)

    # Step 3 — fill gaps with narrow detours (0.5 km offset)
    if len(unique_routes) < 3:
        await _fill_with_detours(unique_routes, req, offset_km=0.5)

    # Step 4 — still short? try wider detours (1.2 km offset)
    if len(unique_routes) < 3:
        await _fill_with_detours(unique_routes, req, offset_km=1.2)

    # Step 5 — assign routes to profiles
    routes = []

    if len(unique_routes) >= 3:
        candidates = unique_routes[:5]
        assignments: dict = {}
        used: set = set()
        for profile in [RouteType.SAFEST, RouteType.FASTEST, RouteType.BALANCED]:
            scores = [
                (i, score_route(candidates[i], profile))
                for i in range(len(candidates))
                if i not in used
            ]
            if scores:
                best_idx = min(scores, key=lambda x: x[1])[0]
                used.add(best_idx)
                assignments[profile] = candidates[best_idx]

        routes.append(build_enhanced_route(assignments[RouteType.SAFEST],   RouteType.SAFEST))
        routes.append(build_enhanced_route(assignments[RouteType.BALANCED], RouteType.BALANCED))
        routes.append(build_enhanced_route(assignments[RouteType.FASTEST],  RouteType.FASTEST))

    elif len(unique_routes) == 2:
        safest_idx = min(
            range(2),
            key=lambda i: score_route(unique_routes[i], RouteType.SAFEST))
        other_idx = 1 - safest_idx
        routes.append(build_enhanced_route(unique_routes[safest_idx], RouteType.SAFEST))
        routes.append(build_enhanced_route(unique_routes[other_idx],  RouteType.BALANCED))
        routes.append(build_enhanced_route(unique_routes[other_idx],  RouteType.FASTEST))

    else:
        only_route = build_enhanced_route(unique_routes[0], RouteType.BALANCED)
        only_route.badge = "Only Route Available"
        only_route.label = "Recommended Route"
        only_route.summary = (
            "This is the only viable route for this trip. " + only_route.summary
        )
        routes.append(only_route)

    return EnhancedRouteResponse(
        routes=routes,
        request_timestamp=datetime.now().isoformat())
