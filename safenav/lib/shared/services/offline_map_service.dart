import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../constants/app_constants.dart';

class OfflineMapService extends ChangeNotifier {
  static const String regionId = 'panadura_offline';
  static const double _south = 6.65;
  static const double _west = 79.85;
  static const double _north = 6.77;
  static const double _east = 80.00;
  static const int _minZoom = 10;
  static const int _maxZoom = 16;

  double downloadProgress = 0.0;
  bool isDownloading = false;
  bool isDownloaded = false;
  String statusMessage = '';

  Future<void> checkIfAlreadyDownloaded() async {
    try {
      final tileStore = await TileStore.createDefault();
      final regions = await tileStore.allTileRegions();
      isDownloaded = regions.any((r) => r.id == regionId);
      notifyListeners();
    } catch (e) {
      debugPrint('OfflineMapService.checkIfAlreadyDownloaded: $e');
    }
  }

  Future<void> downloadPanaduraMap(void Function(double) onProgress) async {
    if (isDownloading) return;
    try {
      isDownloading = true;
      downloadProgress = 0.0;
      statusMessage = '';
      notifyListeners();

      final Map<String, Object?> geometry = {
        'type': 'Polygon',
        'coordinates': [
          [
            [_west, _south],
            [_east, _south],
            [_east, _north],
            [_west, _north],
            [_west, _south],
          ]
        ]
      };

      final tileStore = await TileStore.createDefault();
      await tileStore.loadTileRegion(
        regionId,
        TileRegionLoadOptions(
          geometry: geometry,
          descriptorsOptions: [
            TilesetDescriptorOptions(
              styleURI: AppConstants.mapboxStyle,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
            ),
          ],
          acceptExpired: true,
          networkRestriction: NetworkRestriction.NONE,
        ),
        (progress) {
          final required = progress.requiredResourceCount;
          if (required > 0) {
            downloadProgress = progress.completedResourceCount / required;
            onProgress(downloadProgress);
            notifyListeners();
          }
        },
      );

      isDownloaded = true;
      isDownloading = false;
      downloadProgress = 1.0;
      statusMessage = '';
      notifyListeners();
    } catch (e) {
      isDownloading = false;
      statusMessage = 'Download failed. Check your connection and try again.';
      debugPrint('OfflineMapService.downloadPanaduraMap: $e');
      notifyListeners();
    }
  }

  Future<void> deleteOfflineMap() async {
    try {
      final tileStore = await TileStore.createDefault();
      await tileStore.removeRegion(regionId);
      isDownloaded = false;
      downloadProgress = 0.0;
      statusMessage = '';
      notifyListeners();
    } catch (e) {
      debugPrint('OfflineMapService.deleteOfflineMap: $e');
    }
  }
}
