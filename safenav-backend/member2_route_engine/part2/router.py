from fastapi import APIRouter, HTTPException
from .schemas import EnhancedRouteRequest, EnhancedRouteResponse
from .enhanced_astar_service import get_enhanced_routes
from . import route_cache

router = APIRouter(
    prefix='/v2/route',
    tags=['Member 2 Part 2 - Enhanced Route Engine']
)

STALE_NOTICE = "Showing a saved route because live data is unavailable"


@router.post('/safety', response_model=EnhancedRouteResponse)
async def enhanced_safety_routes(req: EnhancedRouteRequest):
    """
    Returns 3 enhanced routes (Safest, Balanced, Fastest) with:
      - Real geometry from Mapbox Directions API
      - Live traffic congestion per segment
      - Road type classification breakdown
      - Hotspot exposure counts
      - Safety + risk scores

    Responses are cached for 5 min; if live computation fails, a saved
    copy up to 6 h old is returned with degraded=True.
    """
    key = route_cache.make_key(
        req.origin.latitude, req.origin.longitude,
        req.destination.latitude, req.destination.longitude)

    cached = route_cache.get_fresh(key)
    if cached is not None:
        return cached.model_copy(update={'from_cache': True})

    try:
        result = await get_enhanced_routes(req)
    except Exception as e:
        print(f"[v2/route/safety] live computation failed: {e!r}")
        stale = route_cache.get_stale(key)
        if stale is not None:
            return stale.model_copy(update={
                'from_cache': True,
                'degraded': True,
                'notice': STALE_NOTICE,
            })
        raise HTTPException(
            status_code=503,
            detail='Route service temporarily unavailable')

    route_cache.put(key, result)
    return result


@router.get('/health')
async def health():
    return {'status': 'ok', 'module': 'member2_part2_enhanced_routes'}
