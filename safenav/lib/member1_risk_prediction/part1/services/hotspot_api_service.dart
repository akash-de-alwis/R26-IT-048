import '../models/hotspot_model.dart';
import '../../../shared/services/api_service.dart';

/// Hotspot API calls owned by Member 1 (IT22153968).
class HotspotApiService {
  HotspotApiService._();
  static final HotspotApiService instance = HotspotApiService._();

  Future<List<HotspotModel>> getHotspots() async {
    final raw = await ApiService.instance.getHotspots();
    return raw.map(HotspotModel.fromJson).toList();
  }

  Future<HotspotModel?> getHotspotById(int id) async {
    final all = await getHotspots();
    for (final h in all) {
      if (h.hotspotId == id) return h;
    }
    return null;
  }

  Future<List<HotspotModel>> getHotspotsNear(
      double lat, double lng, double radiusM) async {
    final all = await getHotspots();
    return all
        .where((h) => _approxDistM(lat, lng, h.latitude, h.longitude) <= radiusM)
        .toList();
  }

  double _approxDistM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * 3.14159265 / 180;
    final dLng = (lng2 - lng1) * 3.14159265 / 180;
    return r * (dLat * dLat + dLng * dLng);
  }
}
