import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vehicle_type_model.dart';
import '../services/vehicle_preference_service.dart';
import '../services/realtime_risk_service.dart';
import 'vehicle_card.dart';

class VehicleSelectionSheet extends StatefulWidget {
  /// If true, shows the "Set as default" toggle (used when opening from Map).
  final bool showSetDefaultOption;

  /// If true, _confirm() always calls setDefault regardless of the toggle.
  /// Used when opening from Profile settings so any confirmed selection
  /// becomes the new default.
  final bool forceSetDefault;

  const VehicleSelectionSheet({
    super.key,
    this.showSetDefaultOption = true,
    this.forceSetDefault = false,
  });

  static Future<void> show(
    BuildContext context, {
    bool showSetDefaultOption = true,
    bool forceSetDefault = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => VehicleSelectionSheet(
        showSetDefaultOption: showSetDefaultOption,
        forceSetDefault: forceSetDefault,
      ),
    );
  }

  @override
  State<VehicleSelectionSheet> createState() => _VehicleSelectionSheetState();
}

class _VehicleSelectionSheetState extends State<VehicleSelectionSheet> {
  late String _selectedId;
  bool _setAsDefault = false;

  @override
  void initState() {
    super.initState();
    _selectedId = context.read<VehiclePreferenceService>().currentVehicle;
  }

  void _confirm() async {
    final pref = context.read<VehiclePreferenceService>();
    final riskService = context.read<RealtimeRiskService>();

    await pref.setCurrent(_selectedId);
    if (_setAsDefault || widget.forceSetDefault) {
      await pref.setDefault(_selectedId);
    }
    pref.markSessionSelected();

    // Sync to risk service so backend uses the new vehicle type
    riskService.vehicleType = _selectedId;

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pref = context.watch<VehiclePreferenceService>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2979FF).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_car_rounded,
                        color: Color(0xFF2979FF), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Select Your Vehicle',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D1B2A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Risk predictions adjust based on vehicle type',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF5C6B7A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFFADB8C3)),
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            const Divider(height: 16, color: Color(0xFFEEF1F5)),

            // Scrollable vehicle list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: VehicleTypes.all.length,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final v = VehicleTypes.all[i];
                  return VehicleCard(
                    vehicle: v,
                    isSelected: _selectedId == v.id,
                    isDefault: pref.defaultVehicle == v.id,
                    onTap: () => setState(() => _selectedId = v.id),
                  );
                },
              ),
            ),

            // Set as default toggle
            if (widget.showSetDefaultOption)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Set as default vehicle',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0D1B2A),
                      ),
                    ),
                    subtitle: const Text(
                      'Skip this prompt next time',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5C6B7A),
                      ),
                    ),
                    value: _setAsDefault,
                    activeThumbColor: const Color(0xFF2979FF),
                    onChanged: (v) => setState(() => _setAsDefault = v),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Confirm button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
