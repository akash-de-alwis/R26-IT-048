import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/proximity_tier.dart';

// ── Tunable pattern constants (all durations in milliseconds) ──────────────

const int kSampleRate = 22050;
const int kToneFadeMs = 8; // fade in/out removes clicks

// far: one beep on entry, then one every kFarRepeatMs while still far
const double kFarHz = 1000;
const int kFarToneMs = 90;
const double kFarVolume = 0.35;
const int kFarRepeatMs = 6000;

// closer: three beeps with kCloserGapMs gaps, then kCloserPauseMs, repeat
const double kCloserHz = 1000;
const int kCloserToneMs = 110;
const double kCloserVolume = 0.60;
const int kCloserBeeps = 3;
const int kCloserGapMs = 450;
const int kCloserPauseMs = 1200;

// veryClose: three beeps with kVeryCloseGapMs gaps, then kVeryClosePauseMs
const double kVeryCloseHz = 1200;
const int kVeryCloseToneMs = 110;
const double kVeryCloseVolume = 0.80;
const int kVeryCloseBeeps = 3;
const int kVeryCloseGapMs = 110;
const int kVeryClosePauseMs = 500;

// critical: four short beeps, a low warning tone, then a short pause
const double kCriticalHz = 1400;
const int kCriticalToneMs = 80;
const double kCriticalVolume = 1.00;
const int kCriticalBeeps = 4;
const int kCriticalGapMs = 60;
const double kCriticalLowHz = 300;
const int kCriticalLowToneMs = 350;
const double kCriticalLowVolume = 1.00;
const int kCriticalPauseMs = 150;

// De-escalation needs this many consecutive lower frames (stops flicker)
const int kDeEscalateFrames = 3;
const int kPlayerPoolSize = 4;

/// Builds a mono 16-bit PCM WAV sine tone of [hz] lasting [ms].
Uint8List buildToneWav(double hz, int ms) {
  const sr = kSampleRate;
  final n = sr * ms ~/ 1000;
  final bd = ByteData(44 + n * 2);
  void tag(int o, String t) {
    for (var i = 0; i < 4; i++) {
      bd.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  bd.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  bd.setUint32(16, 16, Endian.little); // fmt chunk size
  bd.setUint16(20, 1, Endian.little); // PCM
  bd.setUint16(22, 1, Endian.little); // mono
  bd.setUint32(24, sr, Endian.little);
  bd.setUint32(28, sr * 2, Endian.little); // byte rate
  bd.setUint16(32, 2, Endian.little); // block align
  bd.setUint16(34, 16, Endian.little); // bits per sample
  tag(36, 'data');
  bd.setUint32(40, n * 2, Endian.little);
  final fade = (sr * kToneFadeMs / 1000).round();
  for (var i = 0; i < n; i++) {
    final env = math.min(1.0, math.min(i / fade, (n - i) / fade));
    final v = (math.sin(2 * math.pi * hz * i / sr) * env * 32767).round();
    bd.setInt16(44 + i * 2, v, Endian.little);
  }
  return bd.buffer.asUint8List();
}

class _Tone {
  final double hz;
  final int ms;
  const _Tone(this.hz, this.ms);
}

/// One sound in a pattern: [tone] at [volume], then silence for [gapAfterMs]
/// (measured from the end of the tone).
class _Step {
  final _Tone tone;
  final double volume;
  final int gapAfterMs;
  const _Step(this.tone, this.volume, this.gapAfterMs);
}

List<_Step> _repeat(_Tone tone, double volume, int count, int gapMs,
    {required int pauseMs}) {
  return [
    for (var i = 0; i < count; i++)
      _Step(tone, volume, i == count - 1 ? pauseMs : gapMs),
  ];
}

const _farTone = _Tone(kFarHz, kFarToneMs);
const _closerTone = _Tone(kCloserHz, kCloserToneMs);
const _veryCloseTone = _Tone(kVeryCloseHz, kVeryCloseToneMs);
const _criticalTone = _Tone(kCriticalHz, kCriticalToneMs);
const _criticalLowTone = _Tone(kCriticalLowHz, kCriticalLowToneMs);

final Map<ProximityTier, List<_Step>> _patterns = {
  ProximityTier.far: [const _Step(_farTone, kFarVolume, kFarRepeatMs)],
  ProximityTier.closer: _repeat(
      _closerTone, kCloserVolume, kCloserBeeps, kCloserGapMs,
      pauseMs: kCloserPauseMs),
  ProximityTier.veryClose: _repeat(
      _veryCloseTone, kVeryCloseVolume, kVeryCloseBeeps, kVeryCloseGapMs,
      pauseMs: kVeryClosePauseMs),
  ProximityTier.critical: [
    ..._repeat(_criticalTone, kCriticalVolume, kCriticalBeeps, kCriticalGapMs,
        pauseMs: kCriticalGapMs),
    const _Step(_criticalLowTone, kCriticalLowVolume, kCriticalPauseMs),
  ],
};

/// Proximity beeps from synthesised tones (no audio asset files).
///
/// Call [submitTier] on every analysed frame. Escalation is immediate;
/// de-escalation waits for [kDeEscalateFrames] consecutive lower frames.
///
/// Note: playback uses audioplayers in mediaPlayer mode, because the
/// low-latency mode (SoundPool on Android) rejects BytesSource. If rapid
/// beeps (critical pattern) sound uneven on a device, flutter_soloud is the
/// fallback library for sample-accurate timing.
class BeepEngine {
  final List<AudioPlayer> _players = [];
  final List<BytesSource?> _loaded = List.filled(kPlayerPoolSize, null);
  final Map<_Tone, BytesSource> _sources = {};
  int _nextPlayer = 0;
  bool _initialized = false;
  Future<void>? _initFuture;

  bool _enabled = true;
  double _masterVolume = 1.0;

  ProximityTier _current = ProximityTier.none;
  int _lowerFrames = 0;
  ProximityTier _lowerMax = ProximityTier.none;
  int _generation = 0; // cancel token for the running pattern loop

  ProximityTier get currentTier => _current;
  bool get isEnabled => _enabled;

  /// Pre-builds the WAVs and creates the player pool. Safe to call more
  /// than once; every caller waits on the same setup.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    if (_initialized) return;
    for (final tone in {
      _farTone,
      _closerTone,
      _veryCloseTone,
      _criticalTone,
      _criticalLowTone,
    }) {
      _sources[tone] =
          BytesSource(buildToneWav(tone.hz, tone.ms), mimeType: 'audio/wav');
    }

    // Mix with other audio (no focus steal) and follow the navigation
    // guidance volume on Android.
    final ctx = AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.assistanceNavigationGuidance,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
    );

    for (var i = 0; i < kPlayerPoolSize; i++) {
      final p = AudioPlayer(playerId: 'awareness_beep_$i');
      try {
        await p.setPlayerMode(PlayerMode.mediaPlayer);
        await p.setAudioContext(ctx);
        await p.setReleaseMode(ReleaseMode.stop);
      } catch (e) {
        debugPrint('[BeepEngine] player $i setup failed: $e');
      }
      _players.add(p);
    }
    _initialized = true;
  }

  /// Call on EVERY analysed frame with that frame's highest tier.
  void submitTier(ProximityTier tier) {
    if (!_enabled) return;

    if (tier.index > _current.index) {
      // Escalation: immediate
      _resetLowerStreak();
      _switchTo(tier);
      return;
    }
    if (tier == _current) {
      _resetLowerStreak();
      return;
    }

    // De-escalation: wait for consecutive lower frames, then drop to the
    // highest tier seen during that streak
    _lowerFrames++;
    if (tier.index > _lowerMax.index) _lowerMax = tier;
    if (_lowerFrames >= kDeEscalateFrames) {
      final target = _lowerMax;
      _resetLowerStreak();
      _switchTo(target);
    }
  }

  /// Plays one cycle of [tier]'s pattern (for tests and one-off cues).
  /// Ignores [setEnabled]; callers decide whether a cue should sound.
  Future<void> playPatternOnce(ProximityTier tier) async {
    final steps = _patterns[tier];
    if (steps == null) return;
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      unawaited(_fire(s.tone, s.volume));
      final isLast = i == steps.length - 1;
      await Future.delayed(
          Duration(milliseconds: s.tone.ms + (isLast ? 0 : s.gapAfterMs)));
    }
  }

  void setEnabled(bool v) {
    if (_enabled == v) return;
    _enabled = v;
    if (!v) stop();
  }

  void setMasterVolume(double v) => _masterVolume = v.clamp(0.0, 1.0);

  /// Stops any pattern and silences all players.
  void stop() {
    _generation++;
    _current = ProximityTier.none;
    _resetLowerStreak();
    for (final p in _players) {
      p.stop().catchError((_) {});
    }
  }

  void dispose() {
    stop();
    for (final p in _players) {
      p.dispose().catchError((_) {});
    }
    _players.clear();
    _initialized = false;
    _initFuture = null;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  void _resetLowerStreak() {
    _lowerFrames = 0;
    _lowerMax = ProximityTier.none;
  }

  void _switchTo(ProximityTier tier) {
    _current = tier;
    final gen = ++_generation;
    if (tier == ProximityTier.none) {
      for (final p in _players) {
        p.stop().catchError((_) {});
      }
      return;
    }
    unawaited(_runLoop(tier, gen));
  }

  /// Repeats [tier]'s pattern until the generation changes. The token is
  /// checked before every beep, so a tier change stops the old pattern
  /// within one beep.
  Future<void> _runLoop(ProximityTier tier, int gen) async {
    final steps = _patterns[tier]!;
    while (gen == _generation && _enabled) {
      for (final s in steps) {
        if (gen != _generation || !_enabled) return;
        unawaited(_fire(s.tone, s.volume));
        await Future.delayed(Duration(milliseconds: s.tone.ms + s.gapAfterMs));
      }
    }
  }

  Future<void> _fire(_Tone tone, double tierVolume) async {
    // The engine is created lazily and init() is not awaited by its
    // provider, so the first cue may arrive before setup has finished.
    if (!_initialized) await init();
    if (_players.isEmpty) return;
    final src = _sources[tone];
    if (src == null) return;
    final i = _nextPlayer;
    _nextPlayer = (_nextPlayer + 1) % _players.length;
    final p = _players[i];
    try {
      await p.setVolume((tierVolume * _masterVolume).clamp(0.0, 1.0));
      if (!identical(_loaded[i], src)) {
        await p.setSource(src);
        _loaded[i] = src;
      } else {
        await p.stop(); // rewind the already-loaded tone
      }
      await p.resume();
    } catch (e) {
      debugPrint('[BeepEngine] play failed: $e');
    }
  }
}
