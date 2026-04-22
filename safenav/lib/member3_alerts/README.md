## Owner
Member ID: IT22081452
Part: NLP alert system — proximity-based, context-aware safety alerts with bilingual TTS

## Files owned
- `services/alert_service.dart` — Polls /alerts/nearby every 5 s, manages TTS speech, adaptive per-trip hotspot set
- `widgets/safety_alert_card.dart` — Slide-in alert card overlay with severity colour, explanation, and auto-dismiss
- `widgets/alert_settings_widget.dart` — EN / සිං language toggle and alert enable/disable switch
- `models/alert_model.dart` — Typed AlertData class wrapping the API response dict

## Dependencies
- `lib/core/` — shared (AppColors)
- `lib/member4_scoring/` — SensorService (driver score and recent events fed into alert request)
