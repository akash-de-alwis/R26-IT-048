import 'package:flutter/material.dart';

/// Compact light "island" pill (Live Activity style) for in-trip status:
/// accent-tinted leading icon, one-line title/subtitle, optional big
/// trailing value. [child] adds an expandable area below the main row.
class IslandPill extends StatefulWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color accent;
  final bool pulsing;
  final VoidCallback? onTap;
  final Widget? child;

  /// Drawn along the bottom edge inside the pill (e.g. a progress line).
  final Widget? bottom;

  const IslandPill({
    super.key,
    required this.leading,
    required this.title,
    required this.accent,
    this.subtitle,
    this.trailing,
    this.pulsing = false,
    this.onTap,
    this.child,
    this.bottom,
  });

  static const double height = 52;
  static const Color textDark = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF5C6B7A);

  @override
  State<IslandPill> createState() => _IslandPillState();
}

class _IslandPillState extends State<IslandPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(IslandPill old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.pulsing && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final radius = BorderRadius.circular(IslandPill.height / 2);

    final row = SizedBox(
      height: IslandPill.height,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, right: 16),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(color: accent, size: 20),
                  child: widget.leading,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: IslandPill.textDark,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: IslandPill.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 8),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, content) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(
            color: widget.pulsing ? accent : accent.withValues(alpha: 0.18),
            width: widget.pulsing ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            if (widget.pulsing)
              BoxShadow(
                color: accent.withValues(alpha: 0.45),
                blurRadius: 16 * _pulse.value,
              ),
          ],
        ),
        child: content,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    row,
                    if (widget.child != null) widget.child!,
                  ],
                ),
                if (widget.bottom != null)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 0,
                    child: widget.bottom!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Trailing value for an [IslandPill]: large tabular number plus a small
/// unit suffix, both in the accent colour.
class IslandPillValue extends StatelessWidget {
  final String value;
  final String? unit;
  final Color accent;

  const IslandPillValue({
    super.key,
    required this.value,
    required this.accent,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (unit != null)
            TextSpan(
              text: ' $unit',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}
