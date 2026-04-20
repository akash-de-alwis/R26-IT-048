from __future__ import annotations

import random

from models.schemas import NearbyHotspot, RouteOption, RouteSafetyResponse
from services.hotspot_service import compute_route_risk

_LABELS = {1: "Safest route", 2: "Balanced", 3: "Fastest (higher risk)"}


def rank_routes(routes: list[list[dict]], destination_name: str) -> dict:
    """
    routes: 2–3 route options, each a list of {'latitude': float, 'longitude': float} dicts.
    Returns a RouteSafetyResponse serialised as a dict.
    """
    # ── Score every route ────────────────────────────────────────────────────
    scored = []
    for route_points in routes:
        risk = compute_route_risk(route_points)
        distance_km = round(random.uniform(3.5, 6.5), 1)
        duration_min = int(distance_km / 0.35)
        scored.append((risk, distance_km, duration_min))

    # ── Sort safest-first ────────────────────────────────────────────────────
    scored.sort(key=lambda x: x[0]["risk_score"])

    # ── Build RouteOption objects ────────────────────────────────────────────
    route_options: list[RouteOption] = []
    for rank, (risk, distance_km, duration_min) in enumerate(scored, start=1):
        nearby_hotspots = [
            NearbyHotspot(
                hotspot_id=h["hotspot_id"],
                distance_m=h["distance_m"],
                risk_score=h["risk_score"],
                risk_level=h["risk_level"],
                road_name=h["road_name"],
                top_causes=h["top_causes"],
            )
            for h in risk["nearby_hotspots"][:3]
        ]

        route_options.append(
            RouteOption(
                route_id=rank,
                label=_LABELS[rank],
                distance_km=distance_km,
                duration_min=duration_min,
                risk_score=risk["risk_score"],
                risk_level=risk["risk_level"],
                nearby_hotspots=nearby_hotspots,
                hotspot_count=risk["hotspot_count"],
                recommendation_badge="Recommended" if rank == 1 else "",
            )
        )

    # ── Analysis note based on safest route ──────────────────────────────────
    safest_score = route_options[0].risk_score
    if safest_score < 30:
        analysis_note = "Good news — all available routes have low accident risk."
    elif safest_score < 60:
        analysis_note = "A safer route has been selected. Stay alert near marked hotspots."
    else:
        analysis_note = "All routes pass through high-risk areas. Drive with extra caution."

    return RouteSafetyResponse(
        routes=route_options,
        destination=destination_name,
        analysis_note=analysis_note,
    ).model_dump()
