import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/obstacle_report_service.dart';

class ObstacleReportSheet extends StatefulWidget {
  const ObstacleReportSheet({super.key});

  @override
  State<ObstacleReportSheet> createState() => _ObstacleReportSheetState();
}

class _ObstacleReportSheetState extends State<ObstacleReportSheet> {
  String? _selectedType;
  String _severity = 'CAUTION';
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  static const _types = [
    ('speed_bump', Icons.horizontal_rule_rounded, 'Speed Bump'),
    ('crossing', Icons.directions_walk_rounded, 'Crossing'),
    ('barrier', Icons.block_rounded, 'Barrier / Gate'),
    ('narrow_road', Icons.compress, 'Narrow Road'),
    ('intersection', Icons.share_rounded, 'Intersection'),
    ('user_reported', Icons.flag_rounded, 'Other Hazard'),
  ];

  static const _severities = [
    ('CAUTION', Color(0xFFFFB300), 'Caution'),
    ('WARNING', Color(0xFFFF8C42), 'Warning'),
    ('CRITICAL', Color(0xFFFF3B5C), 'Critical'),
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a hazard type')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (_) {}

      final ok = await ObstacleReportService.submitReport(
        latitude: pos?.latitude ?? 0,
        longitude: pos?.longitude ?? 0,
        obstacleType: _selectedType!,
        severity: _severity,
        userNote: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Hazard reported. Thank you!' : 'Report failed. Try again.',
          ),
          backgroundColor: ok ? const Color(0xFF00873E) : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3EE),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const Text(
                'Report a Hazard',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D1B2A),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Obstacle type grid
          const Text(
            'Hazard type',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5C6B7A),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _types.map((t) {
              final (id, icon, label) = t;
              final selected = _selectedType == id;
              return GestureDetector(
                onTap: () => setState(() => _selectedType = id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF2979FF)
                        : const Color(0xFFF4F6FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF2979FF)
                          : const Color(0xFFDDE3EE),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 16,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF5C6B7A)),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF0D1B2A),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Severity selector
          const Text(
            'Severity',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5C6B7A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: _severities.map((s) {
              final (id, color, label) = s;
              final selected = _severity == id;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _severity = id),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: id != 'CRITICAL' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.12)
                          : const Color(0xFFF4F6FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? color : const Color(0xFFDDE3EE),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? color : const Color(0xFFB5BFCC),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color:
                                selected ? color : const Color(0xFF5C6B7A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Optional note
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Add a note (optional)',
              hintStyle: const TextStyle(
                  fontSize: 13, color: Color(0xFFB5BFCC)),
              filled: true,
              fillColor: const Color(0xFFF4F6FB),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE3EE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE3EE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2979FF)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Report',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
