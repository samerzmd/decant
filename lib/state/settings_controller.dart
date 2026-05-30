import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_service.dart';
import '../audio/haptic_service.dart';
import '../models/app_settings.dart';
import '../services/persistence_service.dart';

/// Owns [AppSettings], persists changes, and pushes them into the audio and
/// haptic services so the rest of the app just reads/sets values.
class SettingsController extends StateNotifier<AppSettings> {
  final PersistenceService _persistence;
  final AudioService _audio;
  final HapticService _haptic;

  SettingsController(this._persistence, this._audio, this._haptic)
      : super(_persistence.loadSettings()) {
    // Apply the loaded settings immediately.
    _audio.applySettings(state.audio);
    _haptic.enabled = state.hapticsEnabled;
  }

  void _commit(AppSettings next) {
    state = next;
    _audio.applySettings(next.audio);
    _haptic.enabled = next.hapticsEnabled;
    _persistence.saveSettings(next);
  }

  void setSfxVolume(double v) =>
      _commit(state.copyWith(audio: state.audio.copyWith(sfxVolume: v)));

  void setAmbientVolume(double v) =>
      _commit(state.copyWith(audio: state.audio.copyWith(ambientVolume: v)));

  void setMusicVolume(double v) =>
      _commit(state.copyWith(audio: state.audio.copyWith(musicVolume: v)));

  void toggleMute() => _commit(
      state.copyWith(audio: state.audio.copyWith(muted: !state.audio.muted)));

  void toggleAmbient() {
    final next = state.copyWith(
        audio: state.audio.copyWith(ambientEnabled: !state.audio.ambientEnabled));
    _commit(next);
    if (next.audio.ambientEnabled && !next.audio.muted) {
      _audio.startAmbient();
    } else {
      _audio.stopAmbient();
    }
  }

  void setAmbientTrack(AmbientTrack track) {
    _commit(state.copyWith(audio: state.audio.copyWith(ambientTrack: track)));
    // If ambience is currently audible, swap the bed immediately.
    if (!state.audio.muted && state.audio.ambientEnabled) {
      _audio.switchAmbient(track);
    }
  }

  void toggleHaptics() =>
      _commit(state.copyWith(hapticsEnabled: !state.hapticsEnabled));

  void toggleColorblind() =>
      _commit(state.copyWith(colorblindMode: !state.colorblindMode));
}
