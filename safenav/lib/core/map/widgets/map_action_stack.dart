import 'package:flutter/material.dart';

class MapActionStack extends StatelessWidget {
  final VoidCallback onLayers;
  final VoidCallback onLegend;
  final VoidCallback onRecenter;
  final int? layersBadgeCount;

  const MapActionStack({
    super.key,
    required this.onLayers,
    required this.onLegend,
    required this.onRecenter,
    this.layersBadgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionButton(
          icon: Icons.layers_rounded,
          onTap: onLayers,
          badgeCount: layersBadgeCount,
        ),
        const SizedBox(height: 8),
        _actionButton(
          icon: Icons.info_outline_rounded,
          onTap: onLegend,
        ),
        const SizedBox(height: 8),
        _actionButton(
          icon: Icons.my_location_rounded,
          onTap: onRecenter,
          primary: true,
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool primary = false,
    int? badgeCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Icon(
                icon,
                size: 20,
                color: primary
                    ? const Color(0xFF2979FF)
                    : const Color(0xFF0D1B2A),
              ),
            ),
          ),
        ),
        if (badgeCount != null && badgeCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
