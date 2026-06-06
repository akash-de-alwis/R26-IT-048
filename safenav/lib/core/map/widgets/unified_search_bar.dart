import 'package:flutter/material.dart';

class UnifiedSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  final Widget? vehiclePill;

  const UnifiedSearchBar({
    super.key,
    required this.onTap,
    this.vehiclePill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(left: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F0FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Color(0xFF2979FF),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Where to?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFADB8C3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          if (vehiclePill != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: vehiclePill!,
            ),
        ],
      ),
    );
  }
}
