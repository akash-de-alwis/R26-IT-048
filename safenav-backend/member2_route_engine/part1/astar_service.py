from __future__ import annotations

import heapq
import math

from shared.utils.geo_utils import haversine_distance
from member1_risk_prediction.part1.hotspot_service import get_all_hotspots

_LABELS = ["Safest route", "Balanced", "Fastest (higher risk)"]
_RISK_WEIGHTS = [0.9, 0.5, 0.1]


def build_waypoint_graph(origin: dict, destination: dict, num_variants: int = 3) -> list:
    orig_lat = origin["latitude"]
    orig_lng = origin["longitude"]
    dest_lat = destination["latitude"]
    dest_lng = destination["longitude"]

    dlat = dest_lat - orig_lat
    dlng = dest_lng - orig_lng
    perp_lat = -dlng
    perp_lng = dlat
    length = math.sqrt(perp_lat ** 2 + perp_lng ** 2)
    if length > 0:
        perp_lat /= length
        perp_lng /= length

    offsets = [0.0, 0.003, -0.003]

    variants = []
    for v in range(num_variants):
        offset = offsets[v]
        waypoints = []
        for i in range(9):  # 9 points = 8 segments
            t = i / 8.0
            base_lat = orig_lat + t * (dest_lat - orig_lat)
            base_lng = orig_lng + t * (dest_lng - orig_lng)
            if 2 <= i <= 6:
                lat = base_lat + offset * perp_lat
                lng = base_lng + offset * perp_lng
            else:
                lat = base_lat
                lng = base_lng
            waypoints.append({"latitude": lat, "longitude": lng})
        variants.append(waypoints)

    return variants


def compute_edge_risk_cost(
    lat1: float, lng1: float,
    lat2: float, lng2: float,
    hotspots: list,
    risk_weight: float = 0.7,
) -> float:
    distance_cost = haversine_distance(lat1, lng1, lat2, lng2) / 1000

    check_points = [
        (lat1, lng1),
        ((lat1 + lat2) / 2, (lng1 + lng2) / 2),
        (lat2, lng2),
    ]

    seen_ids: set = set()
    risk_cost = 0.0
    for clat, clng in check_points:
        for h in hotspots:
            if h["hotspot_id"] in seen_ids:
                continue
            dist = haversine_distance(clat, clng, h["latitude"], h["longitude"])
            if dist <= 300:
                seen_ids.add(h["hotspot_id"])
                risk_cost += (h["risk_score"] / 100) * risk_weight

    return distance_cost + risk_cost


def heuristic(lat: float, lng: float, goal_lat: float, goal_lng: float) -> float:
    return haversine_distance(lat, lng, goal_lat, goal_lng) / 1000


def astar_safest_path(waypoints: list, hotspots: list, risk_weight: float = 0.7) -> dict:
    n = len(waypoints)
    goal = n - 1

    heap: list = [(0.0, 0, [0])]
    visited: set = set()
    g_costs: dict = {0: 0.0}

    while heap:
        f, node, path = heapq.heappop(heap)

        if node == goal:
            path_points = [waypoints[i] for i in path]

            total_distance_m = sum(
                haversine_distance(
                    path_points[i]["latitude"], path_points[i]["longitude"],
                    path_points[i + 1]["latitude"], path_points[i + 1]["longitude"],
                )
                for i in range(len(path_points) - 1)
            )
            total_distance_km = total_distance_m / 1000
            total_cost = g_costs[node]
            total_risk_cost = max(total_cost - total_distance_km, 0.0)

            seen_ids: set = set()
            hotspots_on_path: list = []
            for i in range(len(path_points) - 1):
                p0, p1 = path_points[i], path_points[i + 1]
                check_points = [
                    (p0["latitude"], p0["longitude"]),
                    ((p0["latitude"] + p1["latitude"]) / 2, (p0["longitude"] + p1["longitude"]) / 2),
                    (p1["latitude"], p1["longitude"]),
                ]
                for clat, clng in check_points:
                    for h in hotspots:
                        if h["hotspot_id"] in seen_ids:
                            continue
                        dist = haversine_distance(clat, clng, h["latitude"], h["longitude"])
                        if dist <= 300:
                            seen_ids.add(h["hotspot_id"])
                            hotspots_on_path.append(h)

            # Normalize risk cost per km to a 0-100 score
            raw = (total_risk_cost / max(total_distance_km, 0.001)) * 100
            risk_score = round(max(5.0, min(100.0, raw)), 2)

            return {
                "path": path_points,
                "total_cost": round(total_cost, 4),
                "total_distance_km": round(total_distance_km, 3),
                "total_risk_cost": round(total_risk_cost, 4),
                "hotspots_on_path": hotspots_on_path,
                "hotspot_count": len(hotspots_on_path),
                "risk_score": risk_score,
            }

        if node in visited:
            continue
        visited.add(node)

        neighbor = node + 1
        if neighbor < n:
            edge_cost = compute_edge_risk_cost(
                waypoints[node]["latitude"], waypoints[node]["longitude"],
                waypoints[neighbor]["latitude"], waypoints[neighbor]["longitude"],
                hotspots,
                risk_weight,
            )
            new_g = g_costs[node] + edge_cost
            if new_g < g_costs.get(neighbor, float("inf")):
                g_costs[neighbor] = new_g
                h_val = heuristic(
                    waypoints[neighbor]["latitude"], waypoints[neighbor]["longitude"],
                    waypoints[-1]["latitude"], waypoints[-1]["longitude"],
                )
                heapq.heappush(heap, (new_g + h_val, neighbor, path + [neighbor]))

    # Fallback — ordered graph always has a path, so this is unreachable
    return {
        "path": waypoints,
        "total_cost": 0.0,
        "total_distance_km": 0.0,
        "total_risk_cost": 0.0,
        "hotspots_on_path": [],
        "hotspot_count": 0,
        "risk_score": 5.0,
    }


def find_safest_route(origin: dict, destination: dict) -> dict:
    hotspots = get_all_hotspots()
    variants = build_waypoint_graph(origin, destination, 3)

    raw_results = []
    for i, waypoints in enumerate(variants):
        result = astar_safest_path(waypoints, hotspots, _RISK_WEIGHTS[i])
        result["risk_weight_used"] = _RISK_WEIGHTS[i]
        raw_results.append(result)

    raw_results.sort(key=lambda x: x["risk_score"])

    routes = []
    for rank, r in enumerate(raw_results, 1):
        distance_km = r["total_distance_km"]
        duration_min = int(distance_km / 0.35) if distance_km > 0 else 1

        score = r["risk_score"]
        risk_level = "HIGH" if score >= 60 else ("MEDIUM" if score >= 30 else "LOW")

        routes.append({
            "route_id": rank,
            "label": _LABELS[rank - 1],
            "risk_weight_used": r["risk_weight_used"],
            "path": r["path"],
            "total_distance_km": distance_km,
            "duration_min": duration_min,
            "risk_score": score,
            "risk_level": risk_level,
            "hotspot_count": r["hotspot_count"],
            "hotspots_on_path": r["hotspots_on_path"],
            "recommendation_badge": "Recommended" if rank == 1 else "",
            "algorithm": "A*",
        })

    return {
        "routes": routes,
        "algorithm_used": "A* (Safety-Optimized)",
        "origin": origin,
        "destination": destination,
        "analysis_note": "",
    }
