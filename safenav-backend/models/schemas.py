from __future__ import annotations

from pydantic import BaseModel


# ── Shared ───────────────────────────────────────────────────────────────────

class GpsPoint(BaseModel):
    latitude: float
    longitude: float


# ── Hotspot response ─────────────────────────────────────────────────────────

class HotspotResponse(BaseModel):
    hotspot_id: int
    latitude: float
    longitude: float
    risk_score: float
    risk_level: str
    accident_count: int
    avg_severity: float
    high_sev_pct: int
    night_pct: int
    weekend_pct: int
    top_causes: list[str]
    peak_period: str
    road_name: str


# ── Route safety request & response ──────────────────────────────────────────

class RouteSafetyRequest(BaseModel):
    route_points: list[GpsPoint]
    destination_name: str = ""


class NearbyHotspot(BaseModel):
    hotspot_id: int
    distance_m: float
    risk_score: float
    risk_level: str
    road_name: str
    top_causes: list[str]


class RouteOption(BaseModel):
    route_id: int
    label: str
    distance_km: float
    duration_min: int
    risk_score: float
    risk_level: str
    nearby_hotspots: list[NearbyHotspot]
    hotspot_count: int
    recommendation_badge: str


class RouteSafetyResponse(BaseModel):
    routes: list[RouteOption]
    destination: str
    analysis_note: str


# ── Real-time risk prediction request & response ──────────────────────────────

class RealTimeRiskRequest(BaseModel):
    latitude: float
    longitude: float
    hour: int
    day_of_week: int
    month: int
    is_night: int
    is_weekend: int
    vehicle_type: str
    speed_kmh: float = 0.0


class RealTimeRiskResponse(BaseModel):
    risk_probability: float
    risk_score: float
    risk_level: str
    nearest_hotspot_id: int | None
    nearest_hotspot_distance_m: float | None
    alert_message: str
    alert_message_si: str
    should_alert: bool


# ── Health check ──────────────────────────────────────────────────────────────

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    hotspots_loaded: int
    version: str = "1.0.0"
