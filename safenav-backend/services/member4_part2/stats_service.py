from typing import List
from .schemas import (DrowsinessEvent, TripDrowsinessStats,
                      DrowsinessLevel)
from .event_store import events_for_trip


def compute_trip_stats(trip_id: str) -> TripDrowsinessStats:
    events = events_for_trip(trip_id)

    if not events:
        return TripDrowsinessStats(
            trip_id=trip_id, total_events=0,
            max_drowsiness_score=0, avg_drowsiness_score=0,
            total_drowsy_seconds=0, critical_events=0,
            warning_events=0, caution_events=0,
            safety_deduction=0)

    scores = [e.drowsiness_score for e in events]
    critical = [e for e in events if e.drowsiness_level == DrowsinessLevel.CRITICAL]
    warning  = [e for e in events if e.drowsiness_level == DrowsinessLevel.WARNING]
    caution  = [e for e in events if e.drowsiness_level == DrowsinessLevel.CAUTION]

    drowsy_seconds = sum(
        e.duration_seconds for e in events
        if e.drowsiness_level in [DrowsinessLevel.WARNING,
                                   DrowsinessLevel.CRITICAL])

    # Safety score deduction:
    #   Each CRITICAL event = -8 points
    #   Each WARNING event  = -3 points
    #   Each CAUTION event  = -1 point
    #   Capped at -40 to leave room for other Member 4 scoring
    deduction = min(40,
        len(critical) * 8 + len(warning) * 3 + len(caution) * 1)

    return TripDrowsinessStats(
        trip_id=trip_id,
        total_events=len(events),
        max_drowsiness_score=round(max(scores), 1),
        avg_drowsiness_score=round(sum(scores) / len(scores), 1),
        total_drowsy_seconds=round(drowsy_seconds, 1),
        critical_events=len(critical),
        warning_events=len(warning),
        caution_events=len(caution),
        safety_deduction=deduction)
