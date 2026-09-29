import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Google-Maps-style vertical zoom pill (+ / -). Zoom limits come from the
/// map's own camera bounds, so it respects whatever min/max the map uses.
class MapZoomControl extends StatefulWidget {
  final MapboxMap mapboxMap;

  const MapZoomControl({super.key, required this.mapboxMap});

  @override
  State<MapZoomControl> createState() => _MapZoomControlState();
}

class _MapZoomControlState extends State<MapZoomControl> {
  static const _animMs = 250;
  static const _iconColor = Color(0xFF0D1B2A);
  static const _disabledColor = Color(0xFFADB8C3);

  double _minZoom = 0;
  double _maxZoom = 22;
  double? _zoom;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(MapZoomControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.mapboxMap, widget.mapboxMap)) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final bounds = await widget.mapboxMap.getBounds();
      final camera = await widget.mapboxMap.getCameraState();
      if (!mounted) return;
      setState(() {
        _minZoom = bounds.minZoom;
        _maxZoom = bounds.maxZoom;
        _zoom = camera.zoom;
      });
    } catch (_) {
      // Map not ready yet; buttons stay enabled and re-check on tap.
    }
  }

  bool get _canZoomIn => _zoom == null || _zoom! < _maxZoom - 0.01;
  bool get _canZoomOut => _zoom == null || _zoom! > _minZoom + 0.01;

  Future<void> _zoomBy(double delta) async {
    if (_busy) return;
    _busy = true;
    try {
      final camera = await widget.mapboxMap.getCameraState();
      final target = (camera.zoom + delta).clamp(_minZoom, _maxZoom);
      await widget.mapboxMap.easeTo(
        CameraOptions(zoom: target),
        MapAnimationOptions(duration: _animMs),
      );
      // easeTo returns once the animation is started, so wait it out
      // before re-reading the camera for the enabled state.
      await Future<void>.delayed(const Duration(milliseconds: _animMs + 30));
    } catch (_) {
      // Ignore; the refresh below resyncs the button state.
    } finally {
      _busy = false;
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _button(
              icon: Icons.add_rounded,
              enabled: _canZoomIn,
              onTap: () => _zoomBy(1),
            ),
            Container(
              width: 22,
              height: 1,
              color: const Color(0xFFE6EAEF),
            ),
            _button(
              icon: Icons.remove_rounded,
              enabled: _canZoomOut,
              onTap: () => _zoomBy(-1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.6,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 18,
              color: enabled ? _iconColor : _disabledColor,
            ),
          ),
        ),
      ),
    );
  }
}
