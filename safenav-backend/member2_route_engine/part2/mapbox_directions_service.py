import httpx
from typing import List, Dict, Any
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
