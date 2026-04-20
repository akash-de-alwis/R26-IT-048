import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBg,
        border: Border(
          top: BorderSide(color: Color(0xFFE8EDF2), width: 0.5),
        ),
      ),
      child: SizedBox(
        height: 70 + bottomPadding,
        child: Row(
          children: [
            _NavItem(
              index: 0,
              currentIndex: currentIndex,
              icon: Icons.location_on_outlined,
              activeIcon: Icons.location_on,
              label: 'Map',
              bottomPadding: bottomPadding,
              onTap: onTap,
            ),
            _NavItem(
              index: 1,
              currentIndex: currentIndex,
              icon: Icons.shield_outlined,
              activeIcon: Icons.shield,
              label: 'My Score',
              bottomPadding: bottomPadding,
              onTap: onTap,
            ),
            _NavItem(
              index: 2,
              currentIndex: currentIndex,
              icon: Icons.account_circle_outlined,
              activeIcon: Icons.account_circle,
              label: 'Profile',
              bottomPadding: bottomPadding,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final double bottomPadding;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.bottomPadding,
    required this.onTap,
  });

  bool get _isSelected => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: _isSelected ? 24 : 0,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                _isSelected ? activeIcon : icon,
                size: 26,
                color: _isSelected ? AppColors.primary : AppColors.textHint,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: _isSelected ? AppColors.primary : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
