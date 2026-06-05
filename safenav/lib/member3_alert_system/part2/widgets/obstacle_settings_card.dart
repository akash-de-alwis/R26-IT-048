import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/obstacle_preference_service.dart';

class ObstacleSettingsCard extends StatelessWidget {
  const ObstacleSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ObstaclePreferenceService>(
      builder: (ctx, prefs, _) {
        final enabled = prefs.detectionEnabled;
        final titleColor =
            enabled ? const Color(0xFF0D1B2A) : const Color(0xFFADB8C3);
        final subColor =
            enabled ? const Color(0xFF5C6B7A) : const Color(0xFFCBD2DB);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEF1F5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Master toggle header ─────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: enabled
                          ? const Color(0xFF2979FF).withValues(alpha: 0.10)
                          : const Color(0xFFEEF1F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: enabled
                          ? const Color(0xFF2979FF)
                          : const Color(0xFFADB8C3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Obstacle Detection',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          enabled ? 'Active during trips' : 'Disabled',
                          style: TextStyle(fontSize: 11, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    activeThumbColor: const Color(0xFF2979FF),
                    onChanged: prefs.setDetectionEnabled,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),

              // ── Sub-settings (only shown when master is ON) ──────────────
              if (enabled) ...[
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFEEF1F5), height: 1),
                const SizedBox(height: 16),

                // Voice alerts toggle
                Row(
                  children: [
                    const Icon(Icons.volume_up_rounded,
                        size: 18, color: Color(0xFF5C6B7A)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Voice alerts',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF0D1B2A)),
                      ),
                    ),
                    Switch(
                      value: prefs.voiceEnabled,
                      activeThumbColor: const Color(0xFF2979FF),
                      onChanged: prefs.setVoiceEnabled,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),

                // Language chips (only when voice is on)
                if (prefs.voiceEnabled) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Voice language',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF5C6B7A)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _langChip(ctx, 'English', 'en',
                                prefs.voiceLanguage == 'en'),
                            const SizedBox(width: 8),
                            _langChip(ctx, 'සිංහල', 'si',
                                prefs.voiceLanguage == 'si'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Alert threshold
                const Text(
                  'Alert me for',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5C6B7A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    _threshChip(ctx, 'All obstacles', 'CAUTION',
                        prefs.alertThreshold),
                    _threshChip(
                        ctx, 'Warnings+', 'WARNING', prefs.alertThreshold),
                    _threshChip(ctx, 'Critical only', 'CRITICAL',
                        prefs.alertThreshold),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _langChip(
      BuildContext ctx, String label, String value, bool isActive) {
    return GestureDetector(
      onTap: () => ctx.read<ObstaclePreferenceService>().setLanguage(value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2979FF)
              : const Color(0xFFF5F8FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF2979FF)
                : const Color(0xFFEEF1F5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                isActive ? Colors.white : const Color(0xFF5C6B7A),
          ),
        ),
      ),
    );
  }

  Widget _threshChip(BuildContext ctx, String label, String value,
      String currentThreshold) {
    final isActive = currentThreshold == value;
    return GestureDetector(
      onTap: () =>
          ctx.read<ObstaclePreferenceService>().setThreshold(value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2979FF)
              : const Color(0xFFF5F8FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFF2979FF)
                : const Color(0xFFEEF1F5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color:
                isActive ? Colors.white : const Color(0xFF5C6B7A),
          ),
        ),
      ),
    );
  }
}
