import 'package:flutter/material.dart';

/// How close a sensed object is, from nothing to act on up to critical.
enum ProximityTier { none, far, closer, veryClose, critical }

extension ProximityTierX on ProximityTier {
  Color get color => switch (this) {
        ProximityTier.none => Colors.transparent,
        ProximityTier.far => const Color(0xFF00C06A),
        ProximityTier.closer => const Color(0xFFFFB300),
        ProximityTier.veryClose => const Color(0xFFFF8C42),
        ProximityTier.critical => const Color(0xFFFF3B5C),
      };

  String get label => switch (this) {
        ProximityTier.none => '',
        ProximityTier.far => 'Far',
        ProximityTier.closer => 'Getting closer',
        ProximityTier.veryClose => 'Very close',
        ProximityTier.critical => 'Critical',
      };

  /// Severity string in the backend's vocabulary; '' for none.
  String get backendSeverity => switch (this) {
        ProximityTier.none => '',
        ProximityTier.far => 'SAFE',
        ProximityTier.closer => 'CAUTION',
        ProximityTier.veryClose => 'WARNING',
        ProximityTier.critical => 'CRITICAL',
      };
}
