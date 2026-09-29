import 'package:flutter/material.dart';

class HighRiskBanner extends StatelessWidget {
  final int highRiskCount;
  final VoidCallback? onTap;

  const HighRiskBanner({
    super.key,
    required this.highRiskCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (highRiskCount == 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _iconBadge(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$highRiskCount high-risk zone${highRiskCount == 1 ? '' : 's'} nearby',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D1B2A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Stay alert while driving through this area',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5C6B7A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Color(0xFFADB8C3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBadge() {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB300), Color(0xFFFF8C42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
