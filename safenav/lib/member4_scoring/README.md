## Owner
Member ID: IT22258076
Part: Driver safety scoring — real-time sensor fusion, event detection, score decay, trip history

## Files owned
- `services/sensor_service.dart` — Fuses accelerometer, gyroscope, and GPS streams; detects harsh events; persists trip history via SharedPreferences
- `models/driving_event.dart` — DrivingEvent value object with type, magnitude, location, and score delta
- `models/trip_session.dart` — TripSession aggregate: events list, safety score, distance, duration
- `widgets/score_gauge_widget.dart` — Animated semicircular arc gauge that transitions between score values
- `widgets/trip_event_card.dart` — Single event row card with icon, time-ago, description, and point delta
- `widgets/live_score_banner.dart` — "Trip in progress" banner with pulsing green dot shown on the map screen

## Dependencies
- `lib/core/` — shared (AppColors)
