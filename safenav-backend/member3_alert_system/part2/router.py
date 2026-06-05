from fastapi import APIRouter, HTTPException
from .schemas import (
    ObstacleScanRequest, ObstacleScanResponse,
    ObstacleReportRequest, UserReport,
    NearbyObstacleRequest)
from .obstacle_scanner import scan_route_for_obstacles
from .report_service import submit_report, reports_near

router = APIRouter(
    prefix='/v2/obstacles',
    tags=['Member 3 Part 2 - Obstacle Detection'])

@router.post('/scan', response_model=ObstacleScanResponse)
async def scan_route(req: ObstacleScanRequest):
    """Scan an entire route for static obstacles and bilingual alerts."""
    try:
        return await scan_route_for_obstacles(req)
    except Exception as e:
        raise HTTPException(500, f"Scan failed: {str(e)}")

@router.post('/report', response_model=UserReport)
async def submit_obstacle_report(req: ObstacleReportRequest):
    """Submit a user-reported obstacle (auto-expires in 2 hours)."""
    return submit_report(req)

@router.post('/reports/nearby')
async def get_nearby_reports(req: NearbyObstacleRequest):
    """Get user-reported obstacles within radius of given location."""
    reports = reports_near(req.latitude, req.longitude, req.radius_m)
    return {'reports': reports, 'count': len(reports)}

@router.get('/health')
async def health():
    return {'status': 'ok', 'module': 'member3_part2_obstacles'}
