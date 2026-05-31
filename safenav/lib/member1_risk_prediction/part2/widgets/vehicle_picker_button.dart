import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../models/vehicle_type_model.dart';
import '../services/vehicle_preference_service.dart';
import 'vehicle_selection_sheet.dart';

class VehiclePickerButton extends StatelessWidget {
  const VehiclePickerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VehiclePreferenceService>(
      builder: (ctx, pref, _) {
        final current = VehicleTypes.byId(pref.currentVehicle);

        return GestureDetector(
          onTap: () => VehicleSelectionSheet.show(
            context,
            showSetDefaultOption: false,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: AppColors.shadow, blurRadius: 8),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(current.icon, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  current.displayName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 12, color: AppColors.textHint),
              ],
            ),
          ),
        );
      },
    );
  }
}
