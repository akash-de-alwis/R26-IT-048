import math

EARTH_RADIUS_M = 6_371_000


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return the great-circle distance in metres between two GPS coordinates."""
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * EARTH_RADIUS_M * math.asin(math.sqrt(a))


def find_hotspots_within_radius(
    lat: float, lon: float, hotspots: list, radius_m: float = 300
) -> list:
    """Return hotspot dicts within radius_m metres, each augmented with 'distance_m', sorted ascending."""
    results = []
    for h in hotspots:
        dist = haversine_distance(lat, lon, h["latitude"], h["longitude"])
        if dist <= radius_m:
            results.append({**h, "distance_m": round(dist, 1)})
    results.sort(key=lambda x: x["distance_m"])
    return results


def route_bbox(route_points: list) -> tuple:
    """Return (min_lat, max_lat, min_lon, max_lon) bounding box for a list of GpsPoint-like dicts."""
    lats = [p["latitude"] for p in route_points]
    lons = [p["longitude"] for p in route_points]
    return min(lats), max(lats), min(lons), max(lons)


def risk_level_from_score(score: float) -> str:
    """Map a 0–100 risk score to HIGH / MEDIUM / LOW."""
    if score >= 60:
        return "HIGH"
    if score >= 30:
        return "MEDIUM"
    return "LOW"
