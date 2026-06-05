import httpx
from math import atan2, cos, sin, radians
from typing import List, Dict, Any, Optional
from .config import MAPBOX_ACCESS_TOKEN, MAPBOX_DIRECTIONS_BASE
from .schemas import Coordinate


async def fetch_route_alternatives(
    origin: Coordinate,
    destination: Coordinate
) -> List[Dict[str, Any]]:
    """
    Call Mapbox Directions API with driving-traffic profile.
    Requests up to 3 alternative routes with full annotations.

    Returns the raw route dicts from Mapbox.
    """
    coords = (f"{origin.longitude},{origin.latitude};"
              f"{destination.longitude},{destination.latitude}")

    url = f"{MAPBOX_DIRECTIONS_BASE}/driving-traffic/{coords}"

    params = {
        'access_token': MAPBOX_ACCESS_TOKEN,
        'alternatives': 'true',
        'annotations': 'duration,distance,congestion,maxspeed,speed',
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'true',
        'language': 'en',
    }

    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.get(url, params=params)
        response.raise_for_status()
        data = response.json()

    if data.get('code') != 'Ok' or not data.get('routes'):
        raise ValueError(f"Mapbox Directions failed: {data.get('code')}")

    return data['routes']


async def fetch_route_via_waypoint(
    origin: Coordinate,
    waypoint: Coordinate,
    destination: Coordinate,
) -> Optional[Dict]:
    """
    Request a single route from Mapbox that passes through an
    intermediate waypoint. Used to force route diversity when only
    1-2 natural alternatives exist.
    """
    coords = (f"{origin.longitude},{origin.latitude};"
              f"{waypoint.longitude},{waypoint.latitude};"
              f"{destination.longitude},{destination.latitude}")

    url = f"{MAPBOX_DIRECTIONS_BASE}/driving-traffic/{coords}"
    params = {
        'access_token': MAPBOX_ACCESS_TOKEN,
        'annotations': 'duration,distance,congestion,maxspeed,speed',
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'true',
        'language': 'en',
    }

    try:
        async with httpx.AsyncClient(timeout=12.0) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
        if data.get('code') == 'Ok' and data.get('routes'):
            return data['routes'][0]
    except Exception as e:
        print(f"[fetch_route_via_waypoint] failed: {e}")
    return None


def compute_perpendicular_waypoints(
    origin: Coordinate,
    destination: Coordinate,
    offset_km: float = 0.5,
) -> List[Coordinate]:
    """
    Calculate two perpendicular waypoints near the midpoint of the
    direct line — one offset left, one right. Returns [left, right].
    """
    mid_lat = (origin.latitude + destination.latitude) / 2
    mid_lon = (origin.longitude + destination.longitude) / 2

    lat1 = radians(origin.latitude)
    lat2 = radians(destination.latitude)
    dlon = radians(destination.longitude - origin.longitude)

    x = sin(dlon) * cos(lat2)
    y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dlon)
    bearing = atan2(x, y)

    perp_left  = bearing - (3.14159265 / 2)
    perp_right = bearing + (3.14159265 / 2)

    offset_deg = offset_km / 111.0  # 1 deg ≈ 111 km
    cos_lat = cos(radians(mid_lat))

    left_lat  = mid_lat + offset_deg * cos(perp_left)
    left_lon  = mid_lon + offset_deg * sin(perp_left)  / cos_lat
    right_lat = mid_lat + offset_deg * cos(perp_right)
    right_lon = mid_lon + offset_deg * sin(perp_right) / cos_lat

    return [
        Coordinate(latitude=left_lat,  longitude=left_lon),
        Coordinate(latitude=right_lat, longitude=right_lon),
    ]
