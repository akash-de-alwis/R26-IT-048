import 'package:flutter/material.dart';

import '../models/vehicle_type_model.dart';

// Bar / icon colours
const Color kFactorGreen = Color(0xFF00C06A);
const Color kFactorNeutral = Color(0xFF5C6B7A);
const Color kFactorAmber = Color(0xFFFFB300);
const Color kFactorOrange = Color(0xFFFF8C42);

// Darker text colours for the same bands (readable on white / light tints)
const Color kFactorGreenText = Color(0xFF00794A);
const Color kFactorNeutralText = Color(0xFF4A5663);
const Color kFactorAmberText = Color(0xFF8A6300);
const Color kFactorOrangeText = Color(0xFFB34E00);

/// Colour for a risk multiplier: below 1.00 lowers risk (green), up to
/// 1.14 neutral, 1.15 to 1.29 amber, 1.30 and above orange.
Color multiplierColor(double m) {
  if (m < 1.0) return kFactorGreen;
  if (m < 1.15) return kFactorNeutral;
  if (m < 1.30) return kFactorAmber;
  return kFactorOrange;
}

/// Text colour for the same bands as [multiplierColor], with enough
/// contrast for chip and percent text.
Color multiplierTextColor(double m) {
  if (m < 1.0) return kFactorGreenText;
  if (m < 1.15) return kFactorNeutralText;
  if (m < 1.30) return kFactorAmberText;
  return kFactorOrangeText;
}

/// Bar fill for the live driving-behaviour row, which has no share of
/// the percentages: multiplier 1.00 -> 0.0, 1.35 -> 1.0, clamped.
double drivingBarFraction(double multiplier) =>
    ((multiplier - 1.0) / 0.35).clamp(0.0, 1.0);

/// Icon for a factor, by the backend factor name. For the vehicle factor
/// [value] is the vehicle type id, so the app's vehicle icon is used.
IconData riskFactorIcon(String name, {String? value}) {
  switch (name) {
    case 'Hotspot Proximity':
      return Icons.place_rounded;
    case 'Weather':
      return Icons.cloud_rounded;
    case 'Road Condition':
      return Icons.water_drop_rounded;
    case 'Vehicle Type':
      return value == null
          ? Icons.directions_car_rounded
          : VehicleTypes.byId(value).icon;
    case 'Current Speed':
      return Icons.speed_rounded;
    case 'Driving behaviour':
      return Icons.traffic_rounded;
    default:
      return Icons.tune_rounded;
  }
}

/// One contributing factor: icon, name and value, multiplier chip, then
/// the contribution percent (or a LIVE chip), and a full-width bar.
///
/// Share rows pass [contributionPct]; the live driving-behaviour row sets
/// [isLive] and its bar is scaled with [drivingBarFraction].
class RiskFactorRow extends StatelessWidget {
  final String name;
  final String value;
  final double multiplier;
  final double? contributionPct;
  final bool isBiggest;
  final bool isLive;
  final IconData icon;

  const RiskFactorRow({
    super.key,
    required this.name,
    required this.value,
    required this.multiplier,
    required this.icon,
    this.contributionPct,
    this.isBiggest = false,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = multiplierColor(multiplier);
    final textColor = multiplierTextColor(multiplier);
    final chipText = multiplier < 1.0
        ? 'x${multiplier.toStringAsFixed(2)} lowers'
        : 'x${multiplier.toStringAsFixed(2)}';
    final pct = contributionPct;
    final barValue = isLive
        ? drivingBarFraction(multiplier)
        : pct == null
            ? null
            : (pct / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: textColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Name and value each on one line, never cut off
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D1B2A),
                            ),
                          ),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5C6B7A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isBiggest) ...[
                      const SizedBox(width: 6),
                      _Tag(text: 'BIGGEST', color: textColor, filled: true),
                    ],
                    const SizedBox(width: 6),
                    _Tag(text: chipText, color: textColor),
                    const SizedBox(width: 6),
                    if (isLive)
                      const Tooltip(
                        message: 'Hard brakes in the last minute',
                        child: _Tag(text: 'LIVE', color: kFactorNeutralText),
                      )
                    else if (pct != null)
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${pct.toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                  ],
                ),
                if (barValue != null) ...[
                  const SizedBox(height: 6),
                  // Fills from 0 on first display, then glides on change
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: barValue),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    builder: (_, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: isLive ? 4 : 6,
                        backgroundColor: const Color(0xFFEEF1F5),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;

  const _Tag({required this.text, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: filled ? Colors.white : color,
          height: 1.2,
        ),
      ),
    );
  }
}
