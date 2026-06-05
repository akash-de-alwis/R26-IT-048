import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/obstacle_preference_service.dart';

class ObstacleSettingsCard extends StatelessWidget {
  const ObstacleSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ObstaclePreferenceService>(
      builder: (ctx, prefs, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: const Color(0xFFEEF1F5), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section label
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8C42).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFFFF8C42),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Obstacle Alerts',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D1B2A),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEEF1F5)),

              // Voice alerts toggle
              _ObstacleSettingRow(
                icon: Icons.record_voice_over_rounded,
                label: 'Voice Alerts',
                trailing: Switch(
                  value: prefs.voiceEnabled,
                  onChanged: prefs.setVoiceEnabled,
                  activeThumbColor: const Color(0xFF2979FF),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEEF1F5)),

              // Language selector
              _ObstacleSettingRow(
                icon: Icons.translate_rounded,
                label: 'Alert Language',
                trailing: GestureDetector(
                  onTap: () => prefs.setLanguage(
                      prefs.voiceLanguage == 'en' ? 'si' : 'en'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2979FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      prefs.voiceLanguage == 'en' ? 'EN' : 'සිං',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEEF1F5)),

              // Alert threshold
              _ObstacleSettingRow(
                icon: Icons.tune_rounded,
                label: 'Alert Threshold',
                trailing: _ThresholdSelector(
                  value: prefs.alertThreshold,
                  onChanged: prefs.setThreshold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ObstacleSettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;

  const _ObstacleSettingRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF5C6B7A)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0D1B2A),
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ThresholdSelector extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;

  const _ThresholdSelector({required this.value, required this.onChanged});

  static const _options = [
    ('CAUTION', 'All'),
    ('WARNING', 'Warn+'),
    ('CRITICAL', 'Critical'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _options.map((opt) {
        final (id, label) = opt;
        final selected = value == id;
        return GestureDetector(
          onTap: () => onChanged(id),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF2979FF)
                  : const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? const Color(0xFF2979FF)
                    : const Color(0xFFDDE3EE),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : const Color(0xFF5C6B7A),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
