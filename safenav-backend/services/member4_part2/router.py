from fastapi import APIRouter, HTTPException
from typing import List
from .schemas import (DrowsinessEventRequest, DrowsinessEvent,
                      TripDrowsinessStats)
from .event_store import log_event, events_for_trip
from .stats_service import compute_trip_stats

router = APIRouter(
    prefix='/v2/drowsiness',
    tags=['Member 4 Part 2 - Drowsiness Detection'])


@router.post('/event', response_model=DrowsinessEvent)
async def log_drowsiness_event(req: DrowsinessEventRequest):
    """Log a drowsiness event from the device."""
    try:
        return log_event(req)
    except Exception as e:
        raise HTTPException(500, f"Event log failed: {str(e)}")


@router.get('/trip/{trip_id}/events', response_model=List[DrowsinessEvent])
async def get_trip_events(trip_id: str):
    return events_for_trip(trip_id)


@router.get('/trip/{trip_id}/stats', response_model=TripDrowsinessStats)
async def get_trip_stats(trip_id: str):
    return compute_trip_stats(trip_id)


@router.get('/health')
async def health():
    return {'status': 'ok', 'module': 'member4_part2_drowsiness'}
