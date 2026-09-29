import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../member3_alert_system/part2/widgets/obstacle_report_sheet.dart';
import '../models/awareness_alert_model.dart';
import '../models/proximity_tier.dart';
import '../services/awareness_orchestrator.dart';

/// The single road-awareness banner (camera proximity or route hazard).
/// Same look as the obstacle alert card; hidden when there is no alert.
class AwarenessBanner extends StatelessWidget {
  const AwarenessBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AwarenessOrchestrator>(
      builder: (ctx, orch, _) {
        final alert = orch.activeAlert;
        if (alert == null) {
          final notice = orch.notice;
          return notice == null
              ? const SizedBox.shrink()
              : _NoticeStrip(text: notice);
        }
        // Keyed by the object so it only slides in when the alert changes
        return _BannerContent(key: ValueKey(alert.key), alert: alert);
      },
    );
  }
}

class _BannerContent extends StatefulWidget {
  final AwarenessAlert alert;
  const _BannerContent({super.key, required this.alert});

  @override
  State<_BannerContent> createState() => _BannerContentState();
}

class _BannerContentState extends State<_BannerContent>
    with TickerProviderStateMixin {
  static const _routeDismissSeconds = 6;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final AnimationController _progressCtrl;

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
      duration: const Duration(seconds: _routeDismissSeconds),
    );
    if (widget.alert.source == AlertSource.route) _progressCtrl.forward();
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
    final a = widget.alert;
    final c = a.tier.color;
    final isRoute = a.source == AlertSource.route;

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
                  // Round icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(a.icon, size: 18, color: c),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tier / severity chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            a.chipLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: c,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0D1B2A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (a.subtitle != null)
                          Text(
                            a.subtitle!,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF5C6B7A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (isRoute) ...[
                    const SizedBox(width: 8),
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
                ],
              ),
            ),
            // Route alerts auto-dismiss: show the countdown bar
            if (isRoute)
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                        c.withValues(alpha: 0.40)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoticeStrip extends StatelessWidget {
  final String text;
  const _NoticeStrip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 14, color: Color(0xFFFFB300)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: Color(0xFF633806)),
            ),
          ),
        ],
      ),
    );
  }
}
