import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../services/alert_service.dart';

/// Alert enable/disable switch and EN/සිං language toggle — Member 3 (IT22081452).
/// Drop this widget into any settings screen that has AlertService in its provider tree.
class AlertSettingsWidget extends StatelessWidget {
  const AlertSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final alertService = context.watch<AlertService>();
    return Column(
      children: [
        _AlertToggleRow(alertService: alertService),
        _LanguageToggleRow(alertService: alertService),
      ],
    );
  }
}

class _AlertToggleRow extends StatelessWidget {
  final AlertService alertService;
  const _AlertToggleRow({required this.alertService});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEF1F5), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined,
              size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Safety alerts',
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          Switch(
            value: alertService.isEnabled,
            onChanged: (_) => alertService.toggleAlerts(),
            activeThumbColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _LanguageToggleRow extends StatelessWidget {
  final AlertService alertService;
  const _LanguageToggleRow({required this.alertService});

  @override
  Widget build(BuildContext context) {
    final isEn = alertService.currentLanguage == 'en';
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEF1F5), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.translate_outlined,
              size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Alert language',
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: () => alertService.toggleLanguage(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isEn ? 'EN' : 'සිං',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
