import 'package:flutter/material.dart';

class VehicleTypeInfo {
  final String id;
  final String displayName;
  final IconData icon;
  final String description;
  final Color accentColor;
  final double riskMultiplier;

  const VehicleTypeInfo({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.description,
    required this.accentColor,
    required this.riskMultiplier,
  });
}

// All available vehicle types — these MUST match the backend VehicleType enum
// in services/member1_part2/schemas.py
class VehicleTypes {
  static const List<VehicleTypeInfo> all = [
    VehicleTypeInfo(
      id: 'Car',
      displayName: 'Car',
      icon: Icons.directions_car_rounded,
      description: 'Standard passenger car',
      accentColor: Color(0xFF2979FF),
      riskMultiplier: 1.00,
    ),
    VehicleTypeInfo(
      id: 'Motorcycle',
      displayName: 'Motorcycle',
      icon: Icons.two_wheeler_rounded,
      description: 'Highest accident vulnerability',
      accentColor: Color(0xFFFF3B5C),
      riskMultiplier: 1.40,
    ),
    VehicleTypeInfo(
      id: 'Three Wheeler',
      displayName: 'Three Wheeler',
      icon: Icons.electric_rickshaw_rounded,
      description: 'Tuk-tuk, auto rickshaw',
      accentColor: Color(0xFFFF8C42),
      riskMultiplier: 1.25,
    ),
    VehicleTypeInfo(
      id: 'Van',
      displayName: 'Van',
      icon: Icons.airport_shuttle_rounded,
      description: 'Passenger or cargo van',
      accentColor: Color(0xFF2979FF),
      riskMultiplier: 1.05,
    ),
    VehicleTypeInfo(
      id: 'Bus',
      displayName: 'Bus',
      icon: Icons.directions_bus_rounded,
      description: 'Public or private bus',
      accentColor: Color(0xFFFFB300),
      riskMultiplier: 1.15,
    ),
    VehicleTypeInfo(
      id: 'Lorry',
      displayName: 'Lorry',
      icon: Icons.local_shipping_rounded,
      description: 'Heavy goods truck',
      accentColor: Color(0xFFFFB300),
      riskMultiplier: 1.20,
    ),
    VehicleTypeInfo(
      id: 'Jeep',
      displayName: 'Jeep',
      icon: Icons.directions_car_filled_rounded,
      description: 'SUV or 4WD',
      accentColor: Color(0xFF2979FF),
      riskMultiplier: 1.05,
    ),
  ];

  static VehicleTypeInfo byId(String id) {
    return all.firstWhere(
      (v) => v.id == id,
      orElse: () => all.first,
    );
  }
}
