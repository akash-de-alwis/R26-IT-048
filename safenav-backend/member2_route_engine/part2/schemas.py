from pydantic import BaseModel
from typing import List, Optional
from enum import Enum


class CongestionLevel(str, Enum):
    UNKNOWN = "unknown"
    LOW = "low"
    MODERATE = "moderate"
    HEAVY = "heavy"
    SEVERE = "severe"


class RoadClass(str, Enum):
    MOTORWAY = "motorway"
    TRUNK = "trunk"
    PRIMARY = "primary"
    SECONDARY = "secondary"
    TERTIARY = "tertiary"
    RESIDENTIAL = "residential"
    SERVICE = "service"
    UNCLASSIFIED = "unclassified"


class RouteType(str, Enum):
    SAFEST = "safest"
    BALANCED = "balanced"
    FASTEST = "fastest"


class Coordinate(BaseModel):
    latitude: float
    longitude: float


class EnhancedRouteRequest(BaseModel):
    origin: Coordinate
    destination: Coordinate


class TrafficSummary(BaseModel):
    overall_level: CongestionLevel
    low_pct: float
    moderate_pct: float
    heavy_pct: float
    severe_pct: float


class RoadTypeBreakdown(BaseModel):
    road_class: RoadClass
    distance_m: float
    pct_of_route: float
    risk_multiplier: float


class RouteSegment(BaseModel):
    geometry: List[List[float]]   # [[lng, lat], ...]
    congestion: CongestionLevel
    distance_m: float
    color: str                    # hex color for UI display


class EnhancedRoute(BaseModel):
    route_type: RouteType
    geometry: List[List[float]]
    segments: List[RouteSegment]
    distance_m: float
    duration_seconds: float
    duration_in_traffic_seconds: float

    # Safety scoring breakdown
    safety_score: float           # 0-100, higher = safer
    risk_score: float             # 0-100, higher = riskier
    hotspots_on_route: int

    # Traffic info
    traffic: TrafficSummary

    # Road type info
    road_type_breakdown: List[RoadTypeBreakdown]
    primary_road_class: RoadClass

    # Display
    color: str                    # hex — route line color
    label: str                    # "Safest Route" etc
    badge: str                    # "Recommended" / "Fast" / "Avoid hotspots"
    summary: str                  # one-line description


class EnhancedRouteResponse(BaseModel):
    routes: List[EnhancedRoute]
    request_timestamp: str
