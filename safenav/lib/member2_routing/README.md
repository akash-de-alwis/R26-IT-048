## Owner
Member ID: IT22054722
Part: A* route engine — ranks route alternatives by combined safety and travel-time score

## Files owned
- `widgets/route_options_sheet.dart` — Bottom sheet showing 3 A*-ranked routes with risk bars and badges
- `widgets/route_layer_widget.dart` — Draws coloured polylines and casings on the Mapbox map for each route
- `services/route_api_service.dart` — Thin wrapper around the /route/safety API call
- `models/route_model.dart` — RouteOption and RouteResult typed data classes

## Dependencies
- `lib/core/` — shared (AppProvider, AppColors)
- `lib/member3_alerts/` — AlertService (start monitoring when navigation begins)
- `lib/member4_scoring/` — SensorService (start trip when navigation begins)
