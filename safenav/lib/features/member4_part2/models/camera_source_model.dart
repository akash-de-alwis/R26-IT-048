import 'package:camera/camera.dart';

enum CameraSourceType { builtInFront, builtInBack, external, network }

class CameraSource {
  final String id; // CameraDescription.name, or 'network'
  final String label; // shown to the user
  final CameraSourceType type;
  final CameraDescription? description; // null for network
  final String? url; // only for network

  const CameraSource({
    required this.id,
    required this.label,
    required this.type,
    this.description,
    this.url,
  });

  bool get isNetwork => type == CameraSourceType.network;
  bool get isFront => type == CameraSourceType.builtInFront;
}
