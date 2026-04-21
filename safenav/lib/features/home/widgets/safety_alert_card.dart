import 'dart:async';
import 'package:flutter/material.dart';

class SafetyAlertCard extends StatefulWidget {
  final Map<String, dynamic> alertData;
  final VoidCallback onDismiss;
  final VoidCallback onDismissAll;
  final String language;

  const SafetyAlertCard({
    super.key,
    required this.alertData,
    required this.onDismiss,
    required this.onDismissAll,
    required this.language,
  });

  @override
  State<SafetyAlertCard> createState() => _SafetyAlertCardState();
}

class _SafetyAlertCardState extends State<SafetyAlertCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _slideController.forward();
    _autoDismissTimer = Timer(
      const Duration(seconds: 15),
      widget.onDismiss,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final sanitized = hex.replaceFirst('#', '');
    final value = int.tryParse('FF$sanitized', radix: 16) ?? 0xFFFFB300;
    return Color(value);
  }

  @override
  Widget build(BuildContext context) {
    final severity = widget.alertData['severity'] as String? ?? 'CAUTION';
    final alertColor = _parseColor(
        widget.alertData['alert_color'] as String? ?? '#2979FF');
    final message = widget.language == 'si'
        ? (widget.alertData['message_si'] as String? ?? '')
        : (widget.alertData['message_en'] as String? ?? '');
    final explanation = widget.alertData['explanation'] as String? ?? '';
    final roadName = widget.alertData['road_name'] as String? ?? '';
    final distanceM =
        (widget.alertData['distance_m'] as num?)?.toStringAsFixed(0) ?? '?';

    final IconData severityIcon;
    switch (severity) {
      case 'CRITICAL':
        severityIcon = Icons.warning_rounded;
        break;
      case 'WARNING':
        severityIcon = Icons.info_rounded;
        break;
      default:
        severityIcon = Icons.info_outline_rounded;
    }

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: alertColor, width: 5),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row ──────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: alertColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(severityIcon, color: alertColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          severity == 'CRITICAL' ? 'CRITICAL ALERT' : severity,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: alertColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A2233),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF8896A8),
                    ),
                  ),
                ],
              ),

              // ── Explanation ───────────────────────────────────────────────
              if (explanation.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFEEF1F5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Why this alert?',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF2979FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        explanation,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7A8D),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],

              // ── Bottom row ───────────────────────────────────────────────
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.location_pin,
                    size: 12,
                    color: Color(0xFF8896A8),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      roadName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8896A8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${distanceM}m away',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7A8D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
