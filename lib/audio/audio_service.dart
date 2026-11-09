import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'ambient_track.dart';
import 'music_track.dart';
import 'sound_catalog.dart';
import 'sound_packs.dart';

// Ambient beds: the 54-bed catalog lives in `ambient_track.dart` (+ its
// generated `ambient_catalog.g.dart`); re-exported for existing importers.
export 'ambient_track.dart';
export 'music_track.dart';
export 'sound_catalog.dart';
export 'sound_packs.dart';

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

  /// Optional background music on top of the ambience. On (Warm Keys) for
  /// fresh installs; players with older saved settings keep it off.
  final bool musicEnabled;
  final MusicTrack musicTrack;

  const AudioSettings({
    this.sfxVolume = 0.9,
    this.ambientVolume = 0.5,
    this.musicVolume = 0.8,
    this.muted = false,
    this.ambientEnabled = true,
    this.ambientTrack = AmbientTrack.ocean,
    this.musicEnabled = true,
    this.musicTrack = MusicTrack.warmKeys,
  });

  AudioSettings copyWith({
    double? sfxVolume,
    double? ambientVolume,
    double? musicVolume,
    bool? muted,
    bool? ambientEnabled,
    AmbientTrack? ambientTrack,
    bool? musicEnabled,
    MusicTrack? musicTrack,
  }) =>
      AudioSettings(
        sfxVolume: sfxVolume ?? this.sfxVolume,
        ambientVolume: ambientVolume ?? this.ambientVolume,
        musicVolume: musicVolume ?? this.musicVolume,
        muted: muted ?? this.muted,
        ambientEnabled: ambientEnabled ?? this.ambientEnabled,
        ambientTrack: ambientTrack ?? this.ambientTrack,
        musicEnabled: musicEnabled ?? this.musicEnabled,
        musicTrack: musicTrack ?? this.musicTrack,
      );

  Map<String, dynamic> toJson() => {
        'sfx': sfxVolume,
        'ambient': ambientVolume,
        'music': musicVolume,
        'muted': muted,
        'ambientEnabled': ambientEnabled,
        'ambientTrack': ambientTrack.name,
        'musicEnabled': musicEnabled,
        'musicTrack': musicTrack.name,
      };

  factory AudioSettings.fromJson(Map<String, dynamic> j) {
    final ambientEnabled = j['ambientEnabled'] as bool? ?? true;
    var musicEnabled = j['musicEnabled'] as bool? ?? false;
    var musicTrack =
        MusicTrack.byName(j['musicTrack'] as String?) ?? MusicTrack.warmKeys;
    // Migration: Twilight Pad used to be an ambient bed (and the default, so a
    // missing key means it too). It is now a music track: keep those players
    // hearing it by moving them to Ocean with the pad playing as music.
    final legacyPad = j['ambientTrack'] == null || j['ambientTrack'] == 'pad';
    if (legacyPad && ambientEnabled && !musicEnabled) {
      musicEnabled = true;
      musicTrack = MusicTrack.twilightPad;
    }
    return AudioSettings(
      sfxVolume: (j['sfx'] as num?)?.toDouble() ?? 0.9,
      ambientVolume: (j['ambient'] as num?)?.toDouble() ?? 0.5,
      musicVolume: (j['music'] as num?)?.toDouble() ?? 0.8,
      muted: j['muted'] as bool? ?? false,
      ambientEnabled: ambientEnabled,
      ambientTrack:
          AmbientTrack.byName(j['ambientTrack'] as String?) ?? AmbientTrack.ocean,
      musicEnabled: musicEnabled,
      musicTrack: musicTrack,
    );
  }
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
  // Only the selected ambient bed is loaded (54 beds ship; loading them all
  // up front would slow startup). Swapped on demand in [startAmbient].
  AudioSource? _ambientSource;
  AmbientTrack? _ambientSourceTrack;
  int _ambientGen = 0; // bumps on every stop/switch to cancel stale starts
  AudioSource? _musicSource;
  MusicTrack? _musicSourceTrack;
  int _musicGen = 0;
  AudioSource? _pourSource;

  SoundHandle? _pourHandle;
  SoundHandle? _ambientHandle;
  SoundHandle? _musicHandle;

  bool _ready = false;
  // Set if something asked for ambient/music before the engine finished loading.
  bool _pendingAmbient = false;
  bool _pendingMusic = false;
  AudioSettings _settings = const AudioSettings();

  AudioSettings get settings => _settings;
  bool get isReady => _ready;

  /// Initialize the engine and preload assets. Runs in the background at
  /// startup so it never blocks the first frame. Short SFX are decoded into
  /// memory for low latency; the long ambient loops stream from disk so init
  /// stays fast and light.
  Future<void> init() async {
    _watchPacks();
    try {
      // Always (re)initialise. After the app is exited with Back the Android
      // process can be reused with a fresh Dart isolate while the native
      // engine from the previous run is still alive. Skipping init() then
      // leaves flutter_soloud's asset temp folder unset, so every loadAsset()
      // fails and the app runs silent. init() resets a live native engine
      // itself, so calling it unconditionally is safe.
      await _soloud.init();
      for (final entry in _sfxAssets.entries) {
        _sfx[entry.key] = await _soloud.loadAsset(entry.value);
      }
      _pourSource = await _soloud.loadAsset(_pourAsset);
      _ready = true;
      // If ambient/music was requested while we were still loading, start it.
      if (_pendingAmbient) {
        _pendingAmbient = false;
        await startAmbient();
      }
      if (_pendingMusic) {
        _pendingMusic = false;
        await startMusic();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AudioService init failed (continuing muted): $e');
      _ready = false;
    }
  }

  // ---- Store-delivered packs ---------------------------------------------- //

  bool _packListenersOn = false;
  // True while a bundled default stands in for a pack sound still downloading.
  bool _ambientStandIn = false;
  bool _musicStandIn = false;

  void _watchPacks() {
    if (_packListenersOn) return;
    _packListenersOn = true;
    unawaited(SoundPacks.instance.start());
    SoundPacks.instance.stateOf('ambient').addListener(() {
      if (_ambientStandIn && SoundPacks.instance.stateOf('ambient').value.ready) {
        _ambientStandIn = false;
        if (_ambientHandle != null) switchAmbient(_settings.ambientTrack);
      }
    });
    SoundPacks.instance.stateOf('music').addListener(() {
      if (_musicStandIn && SoundPacks.instance.stateOf('music').value.ready) {
        _musicStandIn = false;
        if (_musicHandle != null) switchMusic(_settings.musicTrack);
      }
    });
  }

  /// Bundled sounds load from Flutter assets; pack sounds from the file the
  /// store delivered (null while the pack is still on its way).
  Future<AudioSource?> _loadSound(SoundItem t) async {
    final pack = t.pack;
    if (pack == null) {
      return _soloud.loadAsset('assets/sounds/${t.fileName}', mode: LoadMode.disk);
    }
    final path = await SoundPacks.instance.resolve(pack, t.fileName);
    if (path == null) return null;
    return _soloud.loadFile(path, mode: LoadMode.disk);
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
      if (_musicHandle != null) {
        _soloud.setVolume(_musicHandle!, _musicBedLevel);
      }
    });
    if (_settings.muted || !_settings.ambientEnabled) {
      stopAmbient();
    }
    if (_settings.muted || !_settings.musicEnabled) {
      stopMusic();
    }
  }

  double get _sfxLevel => _settings.muted ? 0 : _settings.sfxVolume;
  double get _ambientLevel =>
      (_settings.muted || !_settings.ambientEnabled) ? 0 : _settings.ambientVolume;
  double get _musicLevel => _settings.muted ? 0 : _settings.musicVolume;

  /// The music loop sits a little under the ambience so it never dominates;
  /// the Music slider still scales it (and the win jingle) together.
  double get _musicBedLevel =>
      _settings.musicEnabled ? _musicLevel * 0.6 : 0;

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
      if (kDebugMode) debugPrint('startPour failed: $e');
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
    final gen = ++_ambientGen;
    try {
      var source = await _ambientSourceFor(_settings.ambientTrack);
      _ambientStandIn = source == null;
      if (source == null) {
        unawaited(SoundPacks.instance.fetch(_settings.ambientTrack.pack ?? 'ambient'));
        source = await _ambientSourceFor(AmbientTrack.ocean); // bundled stand-in
      }
      if (gen != _ambientGen || source == null) return; // superseded meanwhile
      final h = await _soloud.play(source, volume: _ambientLevel, looping: true);
      if (gen != _ambientGen || _ambientLevel <= 0) {
        _safe(() => _soloud.stop(h)); // stopped/switched while starting
        return;
      }
      _ambientHandle = h;
    } catch (e) {
      if (kDebugMode) debugPrint('startAmbient failed: $e');
    }
  }

  /// Load [track]'s bed (streamed from disk), releasing the previous one.
  Future<AudioSource?> _ambientSourceFor(AmbientTrack track) async {
    if (_ambientSourceTrack == track && _ambientSource != null) {
      return _ambientSource;
    }
    final old = _ambientSource;
    _ambientSource = null;
    _ambientSourceTrack = null;
    _musicSource = null;
    _musicSourceTrack = null;
    if (old != null) {
      try {
        await _soloud.disposeSource(old);
      } catch (_) {}
    }
    final src = await _loadSound(track);
    if (src == null) return null;
    _ambientSource = src;
    _ambientSourceTrack = track;
    return src;
  }

  Future<void> stopAmbient() async {
    _ambientGen++;
    final h = _ambientHandle;
    _ambientHandle = null;
    if (h == null) return;
    _safe(() => _soloud.stop(h));
  }

  /// Switch the ambient bed to [track]. If ambience is currently audible, it
  /// restarts seamlessly with the new track.
  Future<void> switchAmbient(AmbientTrack track) async {
    _settings = _settings.copyWith(ambientTrack: track);
    await stopAmbient();
    if (_ambientLevel > 0) await startAmbient();
  }

  // ---- Background music -------------------------------------------------- //

  Future<void> startMusic() async {
    if (!_ready) {
      _pendingMusic = true; // start as soon as loading finishes
      return;
    }
    if (_musicHandle != null) return;
    if (_musicBedLevel <= 0) return;
    final gen = ++_musicGen;
    try {
      var source = await _musicSourceFor(_settings.musicTrack);
      _musicStandIn = source == null;
      if (source == null) {
        unawaited(SoundPacks.instance.fetch(_settings.musicTrack.pack ?? 'music'));
        source = await _musicSourceFor(MusicTrack.warmKeys); // bundled stand-in
      }
      if (gen != _musicGen || source == null) return; // superseded meanwhile
      final h = await _soloud.play(source, volume: _musicBedLevel, looping: true);
      if (gen != _musicGen || _musicBedLevel <= 0) {
        _safe(() => _soloud.stop(h));
        return;
      }
      _musicHandle = h;
    } catch (e) {
      if (kDebugMode) debugPrint('startMusic failed: $e');
    }
  }

  /// Load [track] (streamed from disk), releasing the previous one.
  Future<AudioSource?> _musicSourceFor(MusicTrack track) async {
    if (_musicSourceTrack == track && _musicSource != null) return _musicSource;
    final old = _musicSource;
    _musicSource = null;
    _musicSourceTrack = null;
    if (old != null) {
      try {
        await _soloud.disposeSource(old);
      } catch (_) {}
    }
    final src = await _loadSound(track);
    if (src == null) return null;
    _musicSource = src;
    _musicSourceTrack = track;
    return src;
  }

  Future<void> stopMusic() async {
    _pendingMusic = false;
    _musicGen++;
    final h = _musicHandle;
    _musicHandle = null;
    if (h == null) return;
    _safe(() => _soloud.stop(h));
  }

  /// Switch the music to [track], restarting it if it is currently playing.
  Future<void> switchMusic(MusicTrack track) async {
    _settings = _settings.copyWith(musicTrack: track);
    await stopMusic();
    if (_musicBedLevel > 0) await startMusic();
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
    final mh = _musicHandle;
    if (mh != null) _safe(() => _soloud.setPause(mh, true));
    _safe(() => _soloud.setGlobalVolume(0));
    if (kDebugMode) debugPrint('Decant audio: paused & silenced (ready=$_ready)');
  }

  /// Called when the Activity is being destroyed. Tears the engine down fully
  /// so a recreated process can re-initialize from scratch (otherwise the stale
  /// native engine wedges the new isolate).
  Future<void> handleAppDetached() async {
    // Release the native engine synchronously, before any await: Android can
    // tear the Flutter engine down right after `detached`, so code after an
    // await may never run (leaving the native engine alive for the next run).
    _pourHandle = null;
    _ambientHandle = null;
    _musicHandle = null;
    _ambientGen++;
    _musicGen++;
    _safe(_soloud.deinit); // also stops and disposes every voice/source
    _ready = false;
    _ambientSource = null;
    _ambientSourceTrack = null;
    _musicSource = null;
    _musicSourceTrack = null;
    _pendingAmbient = false;
    _pendingMusic = false;
    if (kDebugMode) debugPrint('Decant audio: engine released (detached)');
  }

  /// Restore audio when the app returns from the background/history.
  Future<void> handleAppResumed() async {
    final wantAmbient = !_settings.muted && _settings.ambientEnabled;
    final wantMusic = !_settings.muted && _settings.musicEnabled;
    if (!_ready) {
      // Engine was released (e.g. after a detach) — rebuild it. The loops
      // re-start via the pending flags once loading finishes.
      if (wantAmbient) _pendingAmbient = true;
      if (wantMusic) _pendingMusic = true;
      await init();
      return;
    }
    _safe(() => _soloud.setGlobalVolume(1));
    if (wantAmbient) {
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
    if (wantMusic) {
      final h = _musicHandle;
      if (h != null && _isValidHandle(h)) {
        _safe(() => _soloud.setPause(h, false));
      } else {
        _musicHandle = null;
        await startMusic();
      }
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
    await stopMusic();
    _safe(_soloud.deinit);
    _ready = false;
    _ambientSource = null;
    _ambientSourceTrack = null;
    _musicSource = null;
    _musicSourceTrack = null;
  }

  void _safe(void Function() fn) {
    try {
      fn();
    } catch (e) {
      if (kDebugMode) debugPrint('AudioService op failed: $e');
    }
  }
}
