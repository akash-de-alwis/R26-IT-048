from pydantic import BaseModel
from typing import List, Optional
from enum import Enum

class ObstacleType(str, Enum):
    SHARP_BEND = "sharp_bend"
    STEEP_SLOPE = "steep_slope"
    NARROW_ROAD = "narrow_road"
    INTERSECTION = "intersection"
    SPEED_BUMP = "speed_bump"
    BARRIER = "barrier"
    CROSSING = "crossing"
    USER_REPORTED = "user_reported"

class ObstacleSeverity(str, Enum):
    CRITICAL = "CRITICAL"
    WARNING = "WARNING"
    CAUTION = "CAUTION"

class Coordinate(BaseModel):
    latitude: float
    longitude: float

class ObstacleAlertText(BaseModel):
    short_en: str
    short_si: str
    voice_en: str
    voice_si: str

class Obstacle(BaseModel):
    id: str
    obstacle_type: ObstacleType
    severity: ObstacleSeverity
    latitude: float
    longitude: float
    distance_from_route_m: float
    icon_name: str
    color: str
    metric_value: Optional[float] = None
    metric_unit: Optional[str] = None
    description_en: str
    description_si: str
    alert: ObstacleAlertText

class ObstacleScanRequest(BaseModel):
    route_geometry: List[List[float]]  # [[lng,lat],...]

class ObstacleScanResponse(BaseModel):
    obstacles: List[Obstacle]
    total_count: int
    counts_by_type: dict
    counts_by_severity: dict
    scan_timestamp: str

class NearbyObstacleRequest(BaseModel):
    latitude: float
    longitude: float
    heading_degrees: float = 0
    radius_m: float = 200

class ObstacleReportRequest(BaseModel):
    latitude: float
    longitude: float
    obstacle_type: ObstacleType
    severity: ObstacleSeverity
    user_note: Optional[str] = None

class UserReport(BaseModel):
    id: str
    latitude: float
    longitude: float
    obstacle_type: ObstacleType
    severity: ObstacleSeverity
    user_note: Optional[str] = None
    reported_at: str
    expires_at: str
