import 'package:flutter/material.dart';

/// Small amber line shown by the drowsiness chip / preview when the
/// detection service switched cameras. The service clears it after 8 s.
class CameraFallbackNotice extends StatelessWidget {
  final String message;
  const CameraFallbackNotice({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFFFB300).withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 12, color: Color(0xFFFFB300)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF633806), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
