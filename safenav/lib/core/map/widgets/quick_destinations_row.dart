import 'package:flutter/material.dart';

class QuickDestinationsRow extends StatelessWidget {
  final void Function(String destinationName) onTap;

  const QuickDestinationsRow({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(Icons.home_rounded, 'Home', () => onTap('Home')),
          const SizedBox(width: 8),
          _chip(Icons.work_rounded, 'Work', () => onTap('Work')),
          const SizedBox(width: 8),
          _chip(Icons.history_rounded, 'Recent', () => onTap('Recent')),
          const SizedBox(width: 8),
          _chip(
              Icons.local_hospital_rounded, 'Hospital', () => onTap('Hospital')),
          const SizedBox(width: 8),
          _chip(Icons.local_gas_station_rounded, 'Fuel', () => onTap('Fuel')),
          const SizedBox(width: 8),
          _chip(Icons.add_rounded, 'Add', () => onTap('Add'), primary: true),
        ],
      ),
    );
  }

  Widget _chip(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool primary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: primary
              ? const Color(0xFF2979FF).withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primary
                ? const Color(0xFF2979FF).withValues(alpha: 0.30)
                : const Color(0xFFEEF1F5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: primary
                  ? const Color(0xFF2979FF)
                  : const Color(0xFF5C6B7A),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: primary
                    ? const Color(0xFF2979FF)
                    : const Color(0xFF0D1B2A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
