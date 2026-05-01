import 'package:flutter/material.dart';

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
    final bp = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: 92 + bp,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 12 + bp,
            left: 20,
            right: 20,
            height: 64,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Dark pill background ─────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B2A),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
                // ── Items ───────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavPillItem(
                      index: 0,
                      currentIndex: currentIndex,
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      onTap: onTap,
                    ),
                    _MapNavItem(
                      isSelected: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                    _NavPillItem(
                      index: 2,
                      currentIndex: currentIndex,
                      icon: Icons.shield_outlined,
                      activeIcon: Icons.shield,
                      label: 'Score',
                      onTap: onTap,
                    ),
                    _NavPillItem(
                      index: 3,
                      currentIndex: currentIndex,
                      icon: Icons.account_circle_outlined,
                      activeIcon: Icons.account_circle,
                      label: 'Profile',
                      onTap: onTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map nav item — raised circle with same label+dot pattern as siblings ──────
class _MapNavItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _MapNavItem({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 64,
        width: 60,
        child: Column(
          // Pack from the bottom so the circle naturally floats above the pill
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF2979FF), Color(0xFF1A56CC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2979FF).withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.navigation,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Map',
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
                fontWeight:
                    isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 5 : 0,
              height: isSelected ? 5 : 0,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ── Standard pill nav item ────────────────────────────────────────────────────
class _NavPillItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  const _NavPillItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  bool get _selected => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selected ? activeIcon : icon,
            size: 22,
            color: _selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: _selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
              fontWeight: _selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _selected ? 5 : 0,
            height: _selected ? 5 : 0,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
