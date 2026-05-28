from fastapi import APIRouter, HTTPException

from .schemas import RealtimeRiskRequest, RealtimeRiskResponse
from .realtime_risk_service import predict_realtime_risk

router = APIRouter(
    prefix='/v2/risk',
    tags=['Member 1 Part 2 - Real-time Risk'],
)


@router.post('/realtime', response_model=RealtimeRiskResponse)
async def realtime_risk(req: RealtimeRiskRequest):
    """
    Real-time accident risk prediction using:
      - Trained ML model (base probability)
      - Current weather (OpenWeatherMap)
      - Inferred road conditions
      - Live vehicle speed
      - Vehicle type
      - Proximity to known hotspots
    """
    try:
        return await predict_realtime_risk(req)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f'Real-time risk prediction failed: {str(e)}',
        )


@router.get('/health')
async def health():
    return {'status': 'ok', 'module': 'member1_part2_realtime_risk'}
