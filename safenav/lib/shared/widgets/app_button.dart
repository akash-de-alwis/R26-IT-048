import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isPrimary;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.isPrimary = true,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(label);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
    );

    final button = isPrimary
        ? ElevatedButton(
            onPressed: isLoading ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primaryLight,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              minimumSize: const Size(double.infinity, 52),
              shape: shape,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: isLoading ? null : onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              minimumSize: const Size(double.infinity, 52),
              shape: shape,
              elevation: 0,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            child: child,
          );

    if (width == double.infinity) return button;
    return SizedBox(width: width, child: button);
  }
}
