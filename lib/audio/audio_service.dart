import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// The discrete one-shot sound effects shipped with Decant.
enum Sfx { droplet, clink, glug, complete, combo, win }

/// Asset paths for every bundled, CC0, procedurally-synthesized sound.
/// (See `tool/generate_sounds.py` and the README license table.)
const Map<Sfx, String> _sfxAssets = {
  Sfx.droplet: 'assets/sounds/droplet.wav',
  Sfx.clink: 'assets/sounds/glass_clink.wav',
  Sfx.glug: 'assets/sounds/glug.wav',
  Sfx.complete: 'assets/sounds/tube_complete.wav',
  Sfx.combo: 'assets/sounds/combo.wav',
  Sfx.win: 'assets/sounds/win_jingle.wav',
};

const String _pourAsset = 'assets/sounds/water_pour_loop.wav';

/// Selectable ambient background beds (all synthesized, CC0).
enum AmbientTrack { pad, rain, ocean, stream, fireplace }

/// Asset path for each ambient bed. ([AmbientTrack.pad] keeps the original
/// `ambient_loop.wav` filename for backward compatibility.)
const Map<AmbientTrack, String> kAmbientAssets = {
  AmbientTrack.pad: 'assets/sounds/ambient_loop.wav',
  AmbientTrack.rain: 'assets/sounds/ambient_rain.wav',
  AmbientTrack.ocean: 'assets/sounds/ambient_ocean.wav',
  AmbientTrack.stream: 'assets/sounds/ambient_stream.wav',
  AmbientTrack.fireplace: 'assets/sounds/ambient_fireplace.wav',
};

extension AmbientTrackLabel on AmbientTrack {
  String get label => switch (this) {
        AmbientTrack.pad => 'Twilight Pad',
        AmbientTrack.rain => 'Rain',
        AmbientTrack.ocean => 'Ocean',
        AmbientTrack.stream => 'Stream',
        AmbientTrack.fireplace => 'Fireplace',
      };
}

/// Mixer volumes (0..1) for the three independent audio buses.
@immutable
class AudioSettings {
  final double sfxVolume;
  final double ambientVolume;
  final double musicVolume;
  final bool muted;
  final bool ambientEnabled;

  /// Which ambient bed plays when ambience is enabled.
  final AmbientTrack ambientTrack;

  const AudioSettings({
    this.sfxVolume = 0.9,
    this.ambientVolume = 0.5,
    this.musicVolume = 0.8,
    this.muted = false,
    this.ambientEnabled = true,
    this.ambientTrack = AmbientTrack.pad,
  });

  AudioSettings copyWith({
    double? sfxVolume,
    double? ambientVolume,
    double? musicVolume,
    bool? muted,
    bool? ambientEnabled,
    AmbientTrack? ambientTrack,
  }) =>
      AudioSettings(
        sfxVolume: sfxVolume ?? this.sfxVolume,
        ambientVolume: ambientVolume ?? this.ambientVolume,
        musicVolume: musicVolume ?? this.musicVolume,
        muted: muted ?? this.muted,
        ambientEnabled: ambientEnabled ?? this.ambientEnabled,
        ambientTrack: ambientTrack ?? this.ambientTrack,
      );

  Map<String, dynamic> toJson() => {
        'sfx': sfxVolume,
        'ambient': ambientVolume,
        'music': musicVolume,
        'muted': muted,
        'ambientEnabled': ambientEnabled,
        'ambientTrack': ambientTrack.name,
      };

  factory AudioSettings.fromJson(Map<String, dynamic> j) => AudioSettings(
        sfxVolume: (j['sfx'] as num?)?.toDouble() ?? 0.9,
        ambientVolume: (j['ambient'] as num?)?.toDouble() ?? 0.5,
        musicVolume: (j['music'] as num?)?.toDouble() ?? 0.8,
        muted: j['muted'] as bool? ?? false,
        ambientEnabled: j['ambientEnabled'] as bool? ?? true,
        ambientTrack: AmbientTrack.values.firstWhere(
          (t) => t.name == j['ambientTrack'],
          orElse: () => AmbientTrack.pad,
        ),
      );
}

/// Low-latency audio engine wrapper around `flutter_soloud`.
///
/// Responsibilities:
///  * preload every asset once (no per-play disk hit → no lag);
///  * play one-shots on the SFX bus, music cues on the music bus;
///  * drive a *looping* pour sound whose pitch rises with the destination
///    fill level (`updatePourPitch`);
///  * manage a toggleable ambient background loop.
///
/// Everything is wrapped defensively: if the native engine is unavailable
/// (e.g. in unit tests or on an unsupported platform) the calls become no-ops
/// instead of throwing, so gameplay never breaks because of audio.
class AudioService {
  final SoLoud _soloud = SoLoud.instance;

  final Map<Sfx, AudioSource> _sfx = {};
  final Map<AmbientTrack, AudioSource> _ambient = {};
  AudioSource? _pourSource;

  SoundHandle? _pourHandle;
  SoundHandle? _ambientHandle;

  bool _ready = false;
  // Set if something asked for ambient before the engine finished loading.
  bool _pendingAmbient = false;
  AudioSettings _settings = const AudioSettings();

  AudioSettings get settings => _settings;
  bool get isReady => _ready;

  /// Initialize the engine and preload assets. Runs in the background at
  /// startup so it never blocks the first frame. Short SFX are decoded into
  /// memory for low latency; the long ambient loops stream from disk so init
  /// stays fast and light.
  Future<void> init() async {
    try {
      if (!_soloud.isInitialized) {
        await _soloud.init();
      }
      for (final entry in _sfxAssets.entries) {
        _sfx[entry.key] = await _soloud.loadAsset(entry.value);
      }
      _pourSource = await _soloud.loadAsset(_pourAsset);
      for (final entry in kAmbientAssets.entries) {
        _ambient[entry.key] =
            await _soloud.loadAsset(entry.value, mode: LoadMode.disk);
      }
      _ready = true;
      // If the ambient bed was requested while we were still loading, start it.
      if (_pendingAmbient) {
        _pendingAmbient = false;
        await startAmbient();
      }
    } catch (e) {
      debugPrint('AudioService init failed (continuing muted): $e');
      _ready = false;
    }
  }

  void applySettings(AudioSettings settings) {
    _settings = settings;
    // Live-update any currently-playing loops.
    _safe(() {
      if (_ambientHandle != null) {
        _soloud.setVolume(_ambientHandle!, _ambientLevel);
      }
      if (_pourHandle != null) {
        _soloud.setVolume(_pourHandle!, _sfxLevel * 0.6);
      }
    });
    if (_settings.muted || !_settings.ambientEnabled) {
      stopAmbient();
    }
  }

  double get _sfxLevel => _settings.muted ? 0 : _settings.sfxVolume;
  double get _ambientLevel =>
      (_settings.muted || !_settings.ambientEnabled) ? 0 : _settings.ambientVolume;
  double get _musicLevel => _settings.muted ? 0 : _settings.musicVolume;

  // ---- One-shots --------------------------------------------------------- //

  void play(Sfx sfx, {double gain = 1.0}) {
    if (!_ready) return;
    final src = _sfx[sfx];
    if (src == null) return;
    final bus = sfx == Sfx.win ? _musicLevel : _sfxLevel;
    final vol = (bus * gain).clamp(0.0, 1.0);
    if (vol <= 0) return;
    _safe(() => _soloud.play(src, volume: vol));
  }

  void tap() => play(Sfx.clink, gain: 0.9);
  void droplet() => play(Sfx.droplet);
  void glug() => play(Sfx.glug, gain: 0.85);

  /// Completion feedback: a soft chime, or the rising combo arpeggio when this
  /// is the 2nd+ tube to resolve in a single chain.
  void completion({required int chainIndex}) {
    if (chainIndex >= 1) {
      play(Sfx.combo);
    } else {
      play(Sfx.complete);
    }
  }

  void win() => play(Sfx.win);

  // ---- Looping pour ------------------------------------------------------ //

  /// Start the looping trickle. [fillFraction] (0..1) sets the initial pitch.
  Future<void> startPour({double fillFraction = 0.0}) async {
    if (!_ready || _pourSource == null) return;
    if (_pourHandle != null) return; // already pouring
    final vol = _sfxLevel * 0.6;
    if (vol <= 0) return;
    try {
      _pourHandle = await _soloud.play(_pourSource!, volume: vol, looping: true);
      updatePourPitch(fillFraction);
    } catch (e) {
      debugPrint('startPour failed: $e');
    }
  }

  /// Raise the pour pitch as the destination tube fills (tactile realism).
  /// Maps fill 0→1 onto playback speed 0.9→1.6.
  void updatePourPitch(double fillFraction) {
    if (_pourHandle == null) return;
    final f = fillFraction.clamp(0.0, 1.0);
    final speed = 0.9 + 0.7 * f;
    _safe(() => _soloud.setRelativePlaySpeed(_pourHandle!, speed));
  }

  Future<void> stopPour() async {
    final h = _pourHandle;
    _pourHandle = null;
    if (h == null) return;
    _safe(() => _soloud.stop(h));
  }

  // ---- Ambient bed ------------------------------------------------------- //

  Future<void> startAmbient() async {
    if (!_ready) {
      _pendingAmbient = true; // start as soon as loading finishes
      return;
    }
    if (_ambientHandle != null) return;
    if (_ambientLevel <= 0) return;
    final source = _ambient[_settings.ambientTrack] ?? _ambient[AmbientTrack.pad];
    if (source == null) return;
    try {
      _ambientHandle =
          await _soloud.play(source, volume: _ambientLevel, looping: true);
    } catch (e) {
      debugPrint('startAmbient failed: $e');
    }
  }

  Future<void> stopAmbient() async {
    final h = _ambientHandle;
    _ambientHandle = null;
    if (h == null) return;
    _safe(() => _soloud.stop(h));
  }

  /// Switch the ambient bed to [track]. If ambience is currently audible, it
  /// restarts seamlessly with the new track.
  Future<void> switchAmbient(AmbientTrack track) async {
    _settings = _settings.copyWith(ambientTrack: track);
    if (_ambientHandle != null) {
      await stopAmbient();
      await startAmbient();
    }
  }

  // ---- App lifecycle ----------------------------------------------------- //

  /// Silence everything when the app is backgrounded.
  ///
  /// We *pause* the ambient voice (cheap, keeps the handle valid) and mute the
  /// engine globally — rather than stopping it — so that resuming never has to
  /// call `play()` again. Re-playing a (disk-streamed) source on a freshly
  /// resumed engine is what could wedge the UI thread.
  Future<void> handleAppPaused() async {
    await stopPour();
    final h = _ambientHandle;
    if (h != null) _safe(() => _soloud.setPause(h, true));
    _safe(() => _soloud.setGlobalVolume(0));
    debugPrint('Decant audio: paused & silenced (ready=$_ready)');
  }

  /// Called when the Activity is being destroyed. Tears the engine down fully
  /// so a recreated process can re-initialize from scratch (otherwise the stale
  /// native engine wedges the new isolate).
  Future<void> handleAppDetached() async {
    await stopPour();
    await stopAmbient();
    _safe(_soloud.deinit);
    _ready = false;
    _pendingAmbient = false;
    debugPrint('Decant audio: engine released (detached)');
  }

  /// Restore audio when the app returns from the background/history.
  Future<void> handleAppResumed() async {
    if (!_ready) {
      // Engine was released (e.g. after a detach) — rebuild it. The ambient bed
      // re-starts via _pendingAmbient once loading finishes.
      if (!_settings.muted && _settings.ambientEnabled) _pendingAmbient = true;
      await init();
      return;
    }
    _safe(() => _soloud.setGlobalVolume(1));
    final wantAmbient = !_settings.muted && _settings.ambientEnabled;
    if (!wantAmbient) return;
    final h = _ambientHandle;
    if (h != null && _isValidHandle(h)) {
      // Just un-pause the still-loaded voice — no replay, no risk of a hang.
      _safe(() => _soloud.setPause(h, false));
    } else {
      // Voice was reclaimed while away → safe to (re)start it.
      _ambientHandle = null;
      await startAmbient();
    }
  }

  bool _isValidHandle(SoundHandle handle) {
    try {
      return _soloud.getIsValidVoiceHandle(handle);
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    await stopPour();
    await stopAmbient();
    _safe(_soloud.deinit);
    _ready = false;
  }

  void _safe(void Function() fn) {
    try {
      fn();
    } catch (e) {
      debugPrint('AudioService op failed: $e');
    }
  }
}
