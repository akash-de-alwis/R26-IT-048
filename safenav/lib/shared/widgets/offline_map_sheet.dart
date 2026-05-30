import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_map_service.dart';
import '../theme/app_colors.dart';

class OfflineMapSheet extends StatelessWidget {
  const OfflineMapSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Consumer<OfflineMapService>(
      builder: (context, service, _) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE3EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Offline Map',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Download Panadura area for offline use',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // Coverage info row
              Row(
                children: const [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.textHint),
                  SizedBox(width: 4),
                  Text(
                    'Covers ~15 km radius around Panadura',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (service.isDownloading) ...[
                _DownloadingState(service: service),
              ] else if (service.isDownloaded) ...[
                _DownloadedState(service: service),
              ] else ...[
                _NotDownloadedState(service: service),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Not downloaded ────────────────────────────────────────────────────────────

class _NotDownloadedState extends StatelessWidget {
  final OfflineMapService service;
  const _NotDownloadedState({required this.service});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF4FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _InfoLine(
                  icon: Icons.map_outlined, label: 'Area: Panadura & surroundings'),
              SizedBox(height: 8),
              _InfoLine(
                  icon: Icons.zoom_in, label: 'Zoom levels: 10 – 16'),
              SizedBox(height: 8),
              _InfoLine(
                  icon: Icons.storage_outlined,
                  label: 'Estimated size: ~45 MB'),
              SizedBox(height: 8),
              _InfoLine(
                  icon: Icons.wifi_off_outlined,
                  label: 'Works without internet once downloaded'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (service.statusMessage.isNotEmpty) ...[
          Text(
            service.statusMessage,
            style: const TextStyle(fontSize: 12, color: AppColors.danger),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          onPressed: () => service.downloadPanaduraMap((_) {}),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const StadiumBorder(),
            minimumSize: const Size(double.infinity, 52),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Download Offline Map'),
        ),
      ],
    );
  }
}

// ── Downloading ───────────────────────────────────────────────────────────────

class _DownloadingState extends StatelessWidget {
  final OfflineMapService service;
  const _DownloadingState({required this.service});

  @override
  Widget build(BuildContext context) {
    final pct = (service.downloadProgress * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: service.downloadProgress,
            minHeight: 6,
            backgroundColor: const Color(0xFFE8EDF2),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Downloading... $pct%',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Do not close the app',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFFB45309),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => service.deleteOfflineMap(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
            shape: const StadiumBorder(),
            minimumSize: const Size(double.infinity, 44),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// ── Downloaded ────────────────────────────────────────────────────────────────

class _DownloadedState extends StatelessWidget {
  final OfflineMapService service;
  const _DownloadedState({required this.service});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Panadura map is ready offline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Last updated: today',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => service.deleteOfflineMap(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
            shape: const StadiumBorder(),
            minimumSize: const Size(double.infinity, 52),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Delete Offline Map'),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
