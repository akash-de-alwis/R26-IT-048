import 'package:camera/camera.dart';
import '../models/camera_source_model.dart';

/// Discovers every camera the OS exposes plus the saved network camera.
///
/// Flutter has no "camera connected" event, so callers re-run [discover]
/// when the picker opens, on its Refresh button, and on app resume.
class CameraSourceService {
  static const networkId = 'network';

  /// Most recent [discover] result, used to label the current selection.
  static List<CameraSource>? lastDiscovered;

  Future<List<CameraSource>> discover({String? networkUrl}) async {
    final list = <CameraSource>[];
    int back = 0, ext = 0, front = 0;
    final cams = await availableCameras(); // re-queried on every call
    for (final c in cams) {
      switch (c.lensDirection) {
        case CameraLensDirection.front:
          front++;
          list.add(CameraSource(
            id: c.name,
            label: front == 1 ? 'Front camera' : 'Front camera $front',
            type: CameraSourceType.builtInFront,
            description: c,
          ));
        case CameraLensDirection.back:
          back++;
          list.add(CameraSource(
            id: c.name,
            label: back == 1 ? 'Back camera' : 'Back camera $back',
            type: CameraSourceType.builtInBack,
            description: c,
          ));
        case CameraLensDirection.external:
          ext++;
          list.add(CameraSource(
            id: c.name,
            label: ext == 1
                ? 'External camera (USB)'
                : 'External camera $ext (USB)',
            type: CameraSourceType.external,
            description: c,
          ));
      }
    }
    if (networkUrl != null && networkUrl.isNotEmpty) {
      list.add(CameraSource(
        id: networkId,
        label: 'Wireless camera',
        type: CameraSourceType.network,
        url: networkUrl,
      ));
    }
    lastDiscovered = list;
    return list;
  }

  /// Label for [id] using the last discovery; null id = automatic.
  static String labelFor(String? id) {
    if (id == null) return 'Automatic (front camera)';
    if (id == networkId) return 'Wireless camera';
    return lastDiscovered?.where((s) => s.id == id).firstOrNull?.label ??
        'Automatic (front camera)';
  }

  /// Auto-corrects a typed stream address: trims spaces, adds http:// when
  /// no scheme is given, uses http:// for private-network IPs (local cameras
  /// rarely support https), and appends /video when there is no path.
  static String normalizeStreamUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;
    if (!s.contains('://')) s = 'http://$s';
    final u = Uri.tryParse(s);
    if (u == null || u.host.isEmpty) return s;
    var out = u;
    if (out.scheme == 'https' && _isPrivateIPv4(out.host)) {
      out = out.replace(scheme: 'http');
    }
    if (out.path.isEmpty || out.path == '/') {
      out = out.replace(path: '/video');
    }
    return out.toString();
  }

  static bool _isPrivateIPv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final o = parts.map(int.tryParse).toList();
    if (o.any((v) => v == null || v < 0 || v > 255)) return false;
    final a = o[0]!, b = o[1]!;
    return a == 10 ||
        (a == 192 && b == 168) ||
        (a == 172 && b >= 16 && b <= 31);
  }

  static bool isValidStreamUrl(String s) {
    final u = Uri.tryParse(s.trim());
    return u != null &&
        (u.scheme == 'http' || u.scheme == 'https') &&
        u.host.isNotEmpty;
  }
}
