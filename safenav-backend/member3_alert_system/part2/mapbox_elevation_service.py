import httpx
from typing import List, Tuple
from .config import MAPBOX_ACCESS_TOKEN, MAPBOX_TILEQUERY_URL

_elevation_cache = {}

async def get_elevation(lat: float, lon: float) -> float:
    """
    Fetch elevation in meters from Mapbox terrain tilequery.
    Cached by 0.0005 degree grid (~55m) to minimize API calls.
    """
    cache_key = (round(lat, 4), round(lon, 4))
    if cache_key in _elevation_cache:
        return _elevation_cache[cache_key]

    url = f"{MAPBOX_TILEQUERY_URL}/{lon},{lat}.json"
    params = {
        'layers': 'contour',
        'limit': 50,
        'access_token': MAPBOX_ACCESS_TOKEN,
    }
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            data = response.json()

        features = data.get('features', [])
        if not features:
            elevation = 0.0
        else:
            elevations = [f['properties'].get('ele', 0) for f in features]
            elevation = float(max(elevations)) if elevations else 0.0
    except Exception as e:
        print(f"[elevation] failed: {e}")
        elevation = 0.0

    _elevation_cache[cache_key] = elevation
    return elevation

async def get_elevations_for_route(
    geometry: List[List[float]], sample_step: int = 8
) -> List[Tuple[int, float, float, float]]:
    """
    Sample elevation along the route. Returns list of
    (index, lng, lat, elevation_m).
    """
    samples = []
    for i in range(0, len(geometry), sample_step):
        lng, lat = geometry[i][0], geometry[i][1]
        elev = await get_elevation(lat, lng)
        samples.append((i, lng, lat, elev))
    return samples
