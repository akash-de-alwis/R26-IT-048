from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum


class VehicleType(str, Enum):
    CAR = "Car"
    MOTORCYCLE = "Motorcycle"
    THREE_WHEELER = "Three Wheeler"
    VAN = "Van"
    BUS = "Bus"
    LORRY = "Lorry"
    JEEP = "Jeep"


class WeatherCondition(str, Enum):
    CLEAR = "clear"
    CLOUDS = "clouds"
    RAIN = "rain"
    HEAVY_RAIN = "heavy_rain"
    THUNDERSTORM = "thunderstorm"
    FOG = "fog"
    MIST = "mist"


class RoadCondition(str, Enum):
    DRY = "dry"
    WET = "wet"
    SLIPPERY = "slippery"
    POOR_VISIBILITY = "poor_visibility"


class RiskLevel(str, Enum):
    LOW = "LOW"
    MODERATE = "MODERATE"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class RealtimeRiskRequest(BaseModel):
    latitude: float
    longitude: float
    speed_kmh: float = Field(0.0, ge=0, le=300)
    vehicle_type: VehicleType = VehicleType.CAR
    bypass_weather: bool = False


class WeatherSnapshot(BaseModel):
    condition: WeatherCondition
    temperature_c: float
    humidity_pct: int
    wind_speed_kmh: float
    visibility_m: int
    description: str


class RiskFactor(BaseModel):
    name: str
    value: str
    multiplier: float
    contribution_pct: float


class RealtimeRiskResponse(BaseModel):
    risk_score: float
    risk_level: RiskLevel
    risk_color: str
    base_model_probability: float
    speed_multiplier: float
    weather_multiplier: float
    road_condition_multiplier: float
    hotspot_proximity_multiplier: float
    nearest_hotspot_distance_m: Optional[float]
    weather: WeatherSnapshot
    road_condition: RoadCondition
    contributing_factors: List[RiskFactor]
    recommendation: str
    timestamp: str
