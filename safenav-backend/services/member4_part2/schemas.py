from pydantic import BaseModel, Field
from typing import List, Optional
from enum import Enum


class DrowsinessLevel(str, Enum):
    ALERT = "ALERT"
    CAUTION = "CAUTION"
    WARNING = "WARNING"
    CRITICAL = "CRITICAL"


class DrowsinessEventRequest(BaseModel):
    trip_id: str
    timestamp: str
    drowsiness_score: float = Field(..., ge=0, le=100)
    drowsiness_level: DrowsinessLevel
    perclos_pct: float            # % eyes closed over 60s window
    yawn_count_60s: int
    head_nods_60s: int
    avg_ear: float                # eye aspect ratio
    duration_seconds: float       # how long this state lasted


class DrowsinessEvent(BaseModel):
    id: str
    trip_id: str
    timestamp: str
    drowsiness_score: float
    drowsiness_level: DrowsinessLevel
    perclos_pct: float
    yawn_count_60s: int
    head_nods_60s: int
    avg_ear: float
    duration_seconds: float


class TripDrowsinessStats(BaseModel):
    trip_id: str
    total_events: int
    max_drowsiness_score: float
    avg_drowsiness_score: float
    total_drowsy_seconds: float    # time in WARNING+CRITICAL
    critical_events: int
    warning_events: int
    caution_events: int
    safety_deduction: float        # points to subtract from trip safety
