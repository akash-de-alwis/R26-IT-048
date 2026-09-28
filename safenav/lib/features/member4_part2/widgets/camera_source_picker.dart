import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/camera_source_model.dart';
import '../services/camera_source_service.dart';
import '../services/camera_source_tester.dart';
import '../services/drowsiness_detection_service.dart';
import '../services/drowsiness_preference_service.dart';

class CameraSourcePicker extends StatefulWidget {
  const CameraSourcePicker({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CameraSourcePicker(),
    );
  }

  @override
  State<CameraSourcePicker> createState() => _CameraSourcePickerState();
}

class _CameraSourcePickerState extends State<CameraSourcePicker>
    with WidgetsBindingObserver {
  static const _blue = Color(0xFF2979FF);
  static const _ink = Color(0xFF0D1B2A);
  static const _muted = Color(0xFF5C6B7A);

  List<CameraSource>? _sources;
  bool _discovering = false;
  bool _testing = false;
  CameraTestResult? _result;
  String? _inlineWarning;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _discover();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A USB camera may have been plugged in while the app was in background
    if (state == AppLifecycleState.resumed) _discover();
  }

  Future<void> _discover() async {
    if (_discovering) return;
    setState(() => _discovering = true);
    final prefs = context.read<DrowsinessPreferenceService>();
    try {
      final list = await CameraSourceService()
          .discover(networkUrl: prefs.networkCameraUrl);
      if (mounted) setState(() => _sources = list);
    } catch (e) {
      debugPrint('[camera picker] discover failed: $e');
      if (mounted) setState(() => _sources = const []);
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  bool _tripActive() {
    if (!context.read<DrowsinessDetectionService>().isRunning) return false;
    setState(() =>
        _inlineWarning = 'Change the camera before starting a trip');
    return true;
  }

  Future<void> _select(String? id) async {
    if (_tripActive()) return;
    setState(() {
      _result = null;
      _inlineWarning = null;
    });
    await context.read<DrowsinessPreferenceService>().setSelectedCamera(id);
  }

  CameraSource? _selectedSource(String? selectedId) {
    final sources = _sources;
    if (sources == null || sources.isEmpty) return null;
    if (selectedId == null) {
      return sources.where((s) => s.isFront).firstOrNull ??
          sources.where((s) => !s.isNetwork).firstOrNull;
    }
    return sources.where((s) => s.id == selectedId).firstOrNull;
  }

  Future<void> _runTest(CameraSource source) async {
    setState(() {
      _testing = true;
      _result = null;
      _inlineWarning = null;
    });
    final tester =
        CameraSourceTester(context.read<DrowsinessDetectionService>());
    final result = await tester.test(source);
    if (mounted) {
      setState(() {
        _testing = false;
        _result = result;
      });
    }
  }

  Future<void> _addWirelessCamera() async {
    if (_tripActive()) return;
    final prefs = context.read<DrowsinessPreferenceService>();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => _WirelessCameraDialog(initial: prefs.networkCameraUrl),
    );
    if (url == null || !mounted) return;
    await prefs.setNetworkCameraUrl(url);
    await _discover();
  }

  Future<void> _useSuggestedUrl(String url) async {
    if (_tripActive()) return;
    await context.read<DrowsinessPreferenceService>().setNetworkCameraUrl(url);
    if (!mounted) return;
    setState(() => _result = CameraTestResult(
        true, _result?.faceDetected ?? false, 'Saved: $url'));
    await _discover();
  }

  Future<void> _removeWirelessCamera() async {
    if (_tripActive()) return;
    final prefs = context.read<DrowsinessPreferenceService>();
    if (prefs.selectedCameraId == CameraSourceService.networkId) {
      await prefs.setSelectedCamera(null);
    }
    await prefs.setNetworkCameraUrl(null);
    await _discover();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<DrowsinessPreferenceService>();
    final selectedId = prefs.selectedCameraId;
    final selected = _selectedSource(selectedId);
    final hasNetwork = _sources?.any((s) => s.isNetwork) ?? false;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE3EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  const Icon(Icons.videocam_rounded, color: _blue, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Camera source',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _ink),
                    ),
                  ),
                  _discovering
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Refresh',
                          onPressed: _discover,
                          icon: const Icon(Icons.refresh_rounded,
                              color: _muted),
                        ),
                ],
              ),
              const Text(
                'Plug in a USB camera, then tap refresh. '
                'Not all phones expose USB cameras.',
                style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
              ),
              const SizedBox(height: 8),

              if (_inlineWarning != null)
                _strip(_inlineWarning!, const Color(0xFFFFB300),
                    Icons.info_outline_rounded),

              // Automatic
              _tile(
                icon: Icons.auto_awesome_rounded,
                title: 'Automatic (front camera)',
                subtitle: 'Default, no setup needed',
                isSelected: selectedId == null,
                onTap: () => _select(null),
              ),

              if (_sources == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                ..._sources!.map((s) => _tile(
                      icon: _iconFor(s.type),
                      title: s.label,
                      subtitle: _subtitleFor(s),
                      isSelected: selectedId == s.id,
                      onTap: () => _select(s.id),
                      extra: s.isNetwork
                          ? IconButton(
                              tooltip: 'Remove wireless camera',
                              onPressed: _removeWirelessCamera,
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 20, color: _muted),
                            )
                          : null,
                    )),

              _tile(
                icon: Icons.add_link_rounded,
                title: hasNetwork
                    ? 'Change wireless camera'
                    : 'Add wireless camera',
                subtitle: 'MJPEG stream on the same WiFi network',
                isSelected: false,
                onTap: _addWirelessCamera,
              ),

              const SizedBox(height: 6),
              const Text(
                'Changing the camera resets your eye calibration; you will '
                'recalibrate at the start of the next trip.',
                style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
              ),

              if (selected?.isNetwork == true) ...[
                const SizedBox(height: 6),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 13, color: Color(0xFF9AA5B1)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Wireless camera frames are analysed on this phone. '
                        'A single frame is briefly held in the app\'s '
                        'temporary storage while it is analysed and is '
                        'deleted when the trip ends.',
                        style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF9AA5B1),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: (_testing || selected == null)
                    ? null
                    : () => _runTest(selected),
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_circle_outline_rounded, size: 18),
                label: Text(_testing ? 'Testing camera...' : 'Test selected camera'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: _blue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_result != null) ...[
                const SizedBox(height: 10),
                _strip(
                  _result!.message,
                  _result!.faceDetected
                      ? const Color(0xFF00C06A)
                      : const Color(0xFFFFB300),
                  _result!.faceDetected
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                ),
                if (_result!.suggestedUrl != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          _useSuggestedUrl(_result!.suggestedUrl!),
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Use this address'),
                      style: TextButton.styleFrom(foregroundColor: _blue),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? extra,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: isSelected ? _blue : _muted),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
      subtitle: Text(subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: _muted)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?extra,
          if (isSelected)
            const Icon(Icons.check_circle_rounded, color: _blue, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _strip(String text, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: _ink, height: 1.4)),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(CameraSourceType t) => switch (t) {
        CameraSourceType.builtInFront => Icons.camera_front_rounded,
        CameraSourceType.builtInBack => Icons.camera_rear_rounded,
        CameraSourceType.external => Icons.usb_rounded,
        CameraSourceType.network => Icons.wifi_rounded,
      };

  String _subtitleFor(CameraSource s) => switch (s.type) {
        CameraSourceType.builtInFront ||
        CameraSourceType.builtInBack =>
          'Built-in',
        CameraSourceType.external => 'Wired (USB)',
        CameraSourceType.network => s.url ?? 'Wireless',
      };
}

class _WirelessCameraDialog extends StatefulWidget {
  final String? initial;
  const _WirelessCameraDialog({this.initial});

  @override
  State<_WirelessCameraDialog> createState() => _WirelessCameraDialogState();
}

class _WirelessCameraDialogState extends State<_WirelessCameraDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial ?? '');
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _normalized =>
      CameraSourceService.normalizeStreamUrl(_ctrl.text);

  void _save() {
    final url = _normalized;
    if (!CameraSourceService.isValidStreamUrl(url)) {
      setState(() => _error = 'Enter a valid http:// or https:// address');
      return;
    }
    Navigator.pop(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final typed = _ctrl.text.trim();
    final corrected = _normalized;
    final showCorrection = typed.isNotEmpty &&
        corrected != typed &&
        CameraSourceService.isValidStreamUrl(corrected);

    return AlertDialog(
      title: const Text('Wireless camera'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: 'http://192.168.1.50:8080/video',
              helperText: 'Use the camera\'s MJPEG stream address. The phone '
                  'and camera must be on the same network.',
              helperMaxLines: 3,
              errorText: _error,
            ),
          ),
          if (showCorrection) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_fix_high_rounded,
                    size: 14, color: Color(0xFF2979FF)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Will use: $corrected',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF2979FF)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
