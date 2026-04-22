from __future__ import annotations

from .astar_service import find_safest_route


def rank_routes(origin: dict, destination: dict, destination_name: str) -> dict:
    result = find_safest_route(origin, destination)
    result["destination"] = destination_name

    safest_score = result["routes"][0]["risk_score"]
    if safest_score < 30:
        result["analysis_note"] = "Good news — the safest route has low accident risk."
    elif safest_score < 60:
        result["analysis_note"] = "A safer route selected. Stay alert near marked hotspots."
    else:
        result["analysis_note"] = "All routes pass through risk areas. Drive with extra caution."

    return result
