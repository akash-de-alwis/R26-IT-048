import 'package:flutter/material.dart';

class LegendPopup extends StatelessWidget {
  const LegendPopup({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const LegendPopup(),
    );
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
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFF2979FF), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Map Legend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D1B2A),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Route Types'),
                  const SizedBox(height: 10),
                  _legendRow(const Color(0xFF00C06A), 'Safest Route',
                      'Avoids hotspots, prioritizes safety'),
                  _legendRow(const Color(0xFF2979FF), 'Balanced Route',
                      'Mix of speed and safety'),
                  _legendRow(const Color(0xFFFF8C42), 'Fastest Route',
                      'Quickest path to destination'),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFEEF1F5)),
                  const SizedBox(height: 20),
                  _sectionTitle('Traffic Conditions'),
                  const SizedBox(height: 10),
                  _legendRow(
                      const Color(0xFF00C06A), 'Clear', 'Free-flowing traffic'),
                  _legendRow(
                      const Color(0xFFFFB300), 'Slow', 'Moderate congestion'),
                  _legendRow(const Color(0xFFFF8C42), 'Heavy',
                      'Significant slowdown'),
                  _legendRow(
                      const Color(0xFFFF3B5C), 'Severe', 'Major traffic jam'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5C6B7A),
          letterSpacing: 0.5,
        ),
      );

  Widget _legendRow(Color color, String name, String desc) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D1B2A),
                    ),
                  ),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF5C6B7A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
