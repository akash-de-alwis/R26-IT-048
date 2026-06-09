"""
In-memory store of drowsiness events. Auto-clears events older
than 7 days. For production this would persist to a DB.
"""
import uuid
from datetime import datetime, timedelta
from typing import List
from .schemas import DrowsinessEvent, DrowsinessEventRequest

_events: List[DrowsinessEvent] = []
EVENT_TTL_DAYS = 7


def _cleanup_expired():
    global _events
    cutoff = datetime.now() - timedelta(days=EVENT_TTL_DAYS)
    _events = [e for e in _events
               if datetime.fromisoformat(e.timestamp) > cutoff]


def log_event(req: DrowsinessEventRequest) -> DrowsinessEvent:
    _cleanup_expired()
    event = DrowsinessEvent(
        id=str(uuid.uuid4())[:12],
        trip_id=req.trip_id,
        timestamp=req.timestamp,
        drowsiness_score=req.drowsiness_score,
        drowsiness_level=req.drowsiness_level,
        perclos_pct=req.perclos_pct,
        yawn_count_60s=req.yawn_count_60s,
        head_nods_60s=req.head_nods_60s,
        avg_ear=req.avg_ear,
        duration_seconds=req.duration_seconds)
    _events.append(event)
    return event


def events_for_trip(trip_id: str) -> List[DrowsinessEvent]:
    _cleanup_expired()
    return [e for e in _events if e.trip_id == trip_id]
