import httpx
import asyncio
from typing import List, Dict
from .config import OVERPASS_API_URLS

REQUEST_HEADERS = {
    'User-Agent': 'SafeNav-Research/1.0 (Sri Lanka road safety research)',
    'Accept': 'application/json',
}

async def fetch_obstacles_in_bbox(
    south: float, west: float, north: float, east: float
) -> List[Dict]:
    """
    Query OSM Overpass for static obstacles within bbox.
    Tries multiple mirrors with fallback.
    """
    bbox = f"{south},{west},{north},{east}"
    query = f"""
[out:json][timeout:12];
(
  node[traffic_calming]({bbox});
  node[barrier]({bbox});
  node[highway=crossing]({bbox});
  way[highway=pedestrian]({bbox});
  way[access=no]({bbox});
);
out body;
>;
out skel qt;
"""

    last_error = None

    for url in OVERPASS_API_URLS:
        try:
            async with httpx.AsyncClient(
                timeout=14.0, headers=REQUEST_HEADERS
            ) as client:
                response = await client.post(
                    url,
                    data={'data': query},
                    headers={
                        **REQUEST_HEADERS,
                        'Content-Type': 'application/x-www-form-urlencoded',
                    })
                response.raise_for_status()
                data = response.json()
                elements = data.get('elements', [])
                print(f"[overpass] {url} OK — {len(elements)} elements")
                return elements
        except Exception as e:
            last_error = e
            print(f"[overpass] {url} failed: {e}")
            await asyncio.sleep(0.5)
            continue

    print(f"[overpass] all mirrors failed. last error: {last_error}")
    return []

def get_bbox_from_route(geometry: List[List[float]], pad: float = 0.005):
    """Return (south, west, north, east) bounding box for route."""
    if not geometry:
        return (0, 0, 0, 0)
    lons = [p[0] for p in geometry]
    lats = [p[1] for p in geometry]
    return (
        min(lats) - pad, min(lons) - pad,
        max(lats) + pad, max(lons) + pad,
    )
