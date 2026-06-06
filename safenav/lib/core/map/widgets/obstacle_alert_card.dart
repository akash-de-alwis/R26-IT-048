import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../member3_alert_system/part2/services/obstacle_alert_orchestrator.dart';
import '../../../member3_alert_system/part2/services/obstacle_preference_service.dart';
import '../../../member3_alert_system/part2/widgets/obstacle_report_sheet.dart';

class ObstacleAlertCard extends StatelessWidget {
  const ObstacleAlertCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ObstacleAlertOrchestrator>(
      builder: (ctx, orchestrator, _) {
        final prefs = ctx.watch<ObstaclePreferenceService>();
        if (!prefs.detectionEnabled) return const SizedBox.shrink();

        final obs = orchestrator.currentAlertObstacle;
        if (obs == null) return const SizedBox.shrink();

        final lang = prefs.voiceLanguage;
        final text = lang == 'si' ? obs.alert.shortSi : obs.alert.shortEn;

        return _ObstacleCardContent(
          key: ValueKey(obs.id),
          color: obs.severityColor,
          icon: obs.materialIcon,
          severity: obs.severity,
          alertText: text,
        );
      },
    );
  }
}

class _ObstacleCardContent extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String severity;
  final String alertText;

  const _ObstacleCardContent({
    super.key,
    required this.color,
    required this.icon,
    required this.severity,
    required this.alertText,
  });

  @override
  State<_ObstacleCardContent> createState() => _ObstacleCardContentState();
}

class _ObstacleCardContentState extends State<_ObstacleCardContent>
    with TickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final AnimationController _progressCtrl;

  static const _autoDismissSeconds = 6;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _autoDismissSeconds),
    )..forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  void _openReportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ObstacleReportSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return SlideTransition(
      position: _slideAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: c, width: 3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  // Icon circle
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, size: 18, color: c),
                  ),
                  const SizedBox(width: 10),
                  // Severity + alert text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.severity,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: c,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.alertText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D1B2A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Report button — compact, blue, on-brand
                  GestureDetector(
                    onTap: () => _openReportSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.report_outlined,
                              size: 14, color: Color(0xFF2979FF)),
                          SizedBox(width: 4),
                          Text(
                            'Report',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2979FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Auto-dismiss countdown bar
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: AnimatedBuilder(
                animation: _progressCtrl,
                builder: (_, _) => LinearProgressIndicator(
                  value: 1.0 - _progressCtrl.value,
                  minHeight: 2,
                  backgroundColor: Colors.grey.shade100,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(c.withValues(alpha: 0.40)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
