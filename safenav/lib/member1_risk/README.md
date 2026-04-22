## Owner
Member ID: IT22153968
Part: Hotspot risk model — loads and serves accident hotspot data with risk scoring

## Files owned
- `widgets/hotspot_marker_layer.dart` — Coloured circle markers rendered on the Mapbox map for each hotspot
- `services/hotspot_api_service.dart` — Thin wrapper exposing hotspot API calls (getHotspots, getHotspotById, getHotspotsNear)
- `widgets/hotspot_legend_widget.dart` — High / Medium / Low legend row displayed above the map

## Dependencies
- `lib/core/` — shared (AppColors, ApiService, HotspotModel)
