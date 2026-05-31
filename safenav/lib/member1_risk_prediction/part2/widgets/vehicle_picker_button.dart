import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(current.icon, color: const Color(0xFF2979FF), size: 18),
                const SizedBox(width: 6),
                Text(
                  current.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFFADB8C3), size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
