import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/drowsiness_detection_service.dart';

class DrowsinessStatusChip extends StatefulWidget {
  const DrowsinessStatusChip({super.key});

  @override
  State<DrowsinessStatusChip> createState() => _DrowsinessStatusChipState();
}

class _DrowsinessStatusChipState extends State<DrowsinessStatusChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detection = context.watch<DrowsinessDetectionService>();
    final metrics = detection.currentMetrics;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.remove_red_eye_rounded,
                    size: 14, color: Color(0xFF0D1B2A)),
                const SizedBox(width: 4),
                const Text(
                  'Monitoring',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, child) => Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        const Color(0xFF00C06A),
                        const Color(0xFF00E080),
                        _pulseCtrl.value,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_expanded && metrics != null) ...[
              const SizedBox(height: 6),
              const Divider(height: 1, color: Color(0xFFEEF1F5)),
              const SizedBox(height: 6),
              Text(
                'PERCLOS: ${metrics.perclosPct.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 10, color: Color(0xFF5C6B7A)),
              ),
              Text(
                'Yawns (60s): ${metrics.yawnCount60s}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF5C6B7A)),
              ),
              Text(
                'Score: ${metrics.drowsinessScore.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: metrics.levelColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
