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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFB300).withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: Color(0xFFFFB300)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$highRiskCount high-risk zone${highRiskCount > 1 ? 's' : ''} detected in your area',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF633806),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFFFFB300)),
          ],
        ),
      ),
    );
  }
}
