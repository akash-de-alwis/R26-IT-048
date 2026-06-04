from fastapi import APIRouter, HTTPException
from .schemas import EnhancedRouteRequest, EnhancedRouteResponse
from .enhanced_astar_service import get_enhanced_routes

router = APIRouter(
    prefix='/v2/route',
    tags=['Member 2 Part 2 - Enhanced Route Engine']
)


@router.post('/safety', response_model=EnhancedRouteResponse)
async def enhanced_safety_routes(req: EnhancedRouteRequest):
    """
    Returns 3 enhanced routes (Safest, Balanced, Fastest) with:
      - Real geometry from Mapbox Directions API
      - Live traffic congestion per segment
      - Road type classification breakdown
      - Hotspot exposure counts
      - Safety + risk scores
    """
    try:
        return await get_enhanced_routes(req)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f'Enhanced route fetch failed: {str(e)}')


@router.get('/health')
async def health():
    return {'status': 'ok', 'module': 'member2_part2_enhanced_routes'}
