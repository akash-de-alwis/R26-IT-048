import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class _RiskFactor {
  final String label;
  final IconData icon;
  final Color color;
  const _RiskFactor(this.label, this.icon, this.color);
}

class _RouteModel {
  final String label;
  final Color barColor;
  final String distance;
  final String duration;
  final int riskScore;
  final bool isRecommended;
  final List<_RiskFactor> factors;
  const _RouteModel({
    required this.label,
    required this.barColor,
    required this.distance,
    required this.duration,
    required this.riskScore,
    required this.isRecommended,
    required this.factors,
  });
}

const _routes = [
  _RouteModel(
    label: 'Safest route',
    barColor: AppColors.success,
    distance: '4.2 km',
    duration: '12 min',
    riskScore: 18,
    isRecommended: true,
    factors: [
      _RiskFactor('2 hotspots', Icons.circle, AppColors.hotspotLow),
      _RiskFactor('Low traffic', Icons.check_circle_outline, AppColors.success),
    ],
  ),
  _RouteModel(
    label: 'Balanced',
    barColor: AppColors.primary,
    distance: '3.8 km',
    duration: '10 min',
    riskScore: 45,
    isRecommended: false,
    factors: [
      _RiskFactor('4 hotspots', Icons.circle, AppColors.hotspotMed),
      _RiskFactor('Night risk', Icons.nightlight_outlined, AppColors.textSecondary),
    ],
  ),
  _RouteModel(
    label: 'Fastest',
    barColor: AppColors.warning,
    distance: '3.1 km',
    duration: '8 min',
    riskScore: 72,
    isRecommended: false,
    factors: [
      _RiskFactor('6 hotspots', Icons.circle, AppColors.hotspotHigh),
      _RiskFactor('Night risk', Icons.nightlight_outlined, AppColors.textSecondary),
      _RiskFactor('Sharp bends', Icons.warning_amber_outlined, AppColors.warning),
    ],
  ),
];

// ── Sheet widget ──────────────────────────────────────────────────────────────

class RouteOptionsSheet extends StatefulWidget {
  final String destination;

  const RouteOptionsSheet({super.key, required this.destination});

  @override
  State<RouteOptionsSheet> createState() => _RouteOptionsSheetState();
}

class _RouteOptionsSheetState extends State<RouteOptionsSheet> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDragHandle(),
            _buildHeader(context),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (int i = 0; i < _routes.length; i++) ...[
                    _RouteCard(
                      route: _routes[i],
                      isSelected: _selectedIndex == i,
                      onTap: () => setState(() => _selectedIndex = i),
                    ),
                    if (i < _routes.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildBottomActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFDDE3EA),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final dest = widget.destination.trim().isEmpty
        ? 'Your destination'
        : widget.destination.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your route',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tap a route to preview it on the map',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  dest,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Start Navigation'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// ── Route card ────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final _RouteModel route;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteCard({
    required this.route,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.45)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE8EDF2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored left bar
                Container(width: 6, color: route.barColor),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleRow(),
                        const SizedBox(height: 5),
                        _buildMetaRow(),
                        const SizedBox(height: 7),
                        _buildRiskBar(),
                        const SizedBox(height: 6),
                        _buildFactorsRow(),
                      ],
                    ),
                  ),
                ),
                // Radio selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(child: _RadioCircle(selected: isSelected)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        Text(
          route.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (route.isRecommended) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Recommended',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaRow() {
    return Row(
      children: [
        const Icon(Icons.straighten_outlined,
            size: 12, color: AppColors.textHint),
        const SizedBox(width: 3),
        Text(
          route.distance,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.access_time_outlined,
            size: 12, color: AppColors.textHint),
        const SizedBox(width: 3),
        Text(
          route.duration,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildRiskBar() {
    return Row(
      children: [
        const Text(
          'Risk',
          style: TextStyle(fontSize: 10, color: AppColors.textHint),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: route.riskScore / 100,
                backgroundColor: const Color(0xFFE8EDF2),
                valueColor: AlwaysStoppedAnimation<Color>(route.barColor),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${route.riskScore}/100',
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFactorsRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: route.factors
          .map(
            (f) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(f.icon, size: 9, color: f.color),
                const SizedBox(width: 3),
                Text(
                  f.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _RadioCircle extends StatelessWidget {
  final bool selected;
  const _RadioCircle({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFFCDD5DE),
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 12)
          : null,
    );
  }
}
