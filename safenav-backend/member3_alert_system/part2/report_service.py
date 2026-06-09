"""
In-memory store for user-submitted obstacle reports.
Reports auto-expire after 2 hours.
"""
import uuid
from datetime import datetime, timedelta
from typing import List
from .schemas import (UserReport, ObstacleReportRequest)
from .bend_detector import haversine_m

_reports: List[UserReport] = []
REPORT_TTL_HOURS = 2

def _cleanup_expired():
    now = datetime.now()
    global _reports
    _reports = [r for r in _reports
                if datetime.fromisoformat(r.expires_at) > now]

def submit_report(req: ObstacleReportRequest) -> UserReport:
    _cleanup_expired()
    now = datetime.now()
    expires = now + timedelta(hours=REPORT_TTL_HOURS)

    report = UserReport(
        id=str(uuid.uuid4())[:12],
        latitude=req.latitude,
        longitude=req.longitude,
        obstacle_type=req.obstacle_type,
        severity=req.severity,
        user_note=req.user_note,
        reported_at=now.isoformat(),
        expires_at=expires.isoformat())
    _reports.append(report)
    return report

def reports_near(lat: float, lon: float, radius_m: float = 500) -> List[UserReport]:
    _cleanup_expired()
    nearby = []
    for r in _reports:
        d = haversine_m(lat, lon, r.latitude, r.longitude)
        if d <= radius_m:
            nearby.append(r)
    return nearby

def reports_on_route(geometry: List[List[float]], threshold_m: float = 100) -> List[UserReport]:
    _cleanup_expired()
    near_route = []
    seen_ids = set()
    sample_step = max(1, len(geometry) // 40)
    for lng, lat in geometry[::sample_step]:
        for r in _reports:
            if r.id in seen_ids:
                continue
            d = haversine_m(lat, lng, r.latitude, r.longitude)
            if d <= threshold_m:
                near_route.append(r)
                seen_ids.add(r.id)
    return near_route
