import 'package:flutter/material.dart';

class LayersPopup extends StatefulWidget {
  final bool showHighRisk;
  final bool showMediumRisk;
  final bool showLowRisk;
  final int totalHotspots;
  final VoidCallback onHighToggle;
  final VoidCallback onMediumToggle;
  final VoidCallback onLowToggle;

  const LayersPopup({
    super.key,
    required this.showHighRisk,
    required this.showMediumRisk,
    required this.showLowRisk,
    required this.totalHotspots,
    required this.onHighToggle,
    required this.onMediumToggle,
    required this.onLowToggle,
  });

  static Future<void> show(
    BuildContext context, {
    required bool showHighRisk,
    required bool showMediumRisk,
    required bool showLowRisk,
    required int totalHotspots,
    required VoidCallback onHighToggle,
    required VoidCallback onMediumToggle,
    required VoidCallback onLowToggle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => LayersPopup(
        showHighRisk: showHighRisk,
        showMediumRisk: showMediumRisk,
        showLowRisk: showLowRisk,
        totalHotspots: totalHotspots,
        onHighToggle: onHighToggle,
        onMediumToggle: onMediumToggle,
        onLowToggle: onLowToggle,
      ),
    );
  }

  @override
  State<LayersPopup> createState() => _LayersPopupState();
}

class _LayersPopupState extends State<LayersPopup> {
  late bool _showHigh;
  late bool _showMedium;
  late bool _showLow;

  @override
  void initState() {
    super.initState();
    _showHigh = widget.showHighRisk;
    _showMedium = widget.showMediumRisk;
    _showLow = widget.showLowRisk;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.layers_rounded,
                      color: Color(0xFF2979FF), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Map Layers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D1B2A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Color(0xFFEEF1F5), height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hotspot severity',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5C6B7A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _riskChip('High', const Color(0xFFFF3B5C), _showHigh,
                          () {
                        setState(() => _showHigh = !_showHigh);
                        widget.onHighToggle();
                      }),
                      _riskChip('Medium', const Color(0xFFFFB300), _showMedium,
                          () {
                        setState(() => _showMedium = !_showMedium);
                        widget.onMediumToggle();
                      }),
                      _riskChip('Low', const Color(0xFF00C06A), _showLow, () {
                        setState(() => _showLow = !_showLow);
                        widget.onLowToggle();
                      }),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F8FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 16, color: Color(0xFF2979FF)),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.totalHotspots} hotspots in your area',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0D1B2A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _riskChip(
    String label,
    Color color,
    bool isOn,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isOn ? color.withValues(alpha: 0.12) : const Color(0xFFF5F8FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOn ? color : const Color(0xFFEEF1F5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isOn ? color : const Color(0xFFADB8C3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
