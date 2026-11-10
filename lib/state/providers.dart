import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../audio/audio_service.dart';
import '../audio/haptic_service.dart';
import '../logic/level_generator.dart';
import '../models/app_settings.dart';
import '../models/level.dart';
import '../services/analytics_service.dart';
import '../services/persistence_service.dart';
import 'game_controller.dart';
import 'game_session.dart';
import 'progress_controller.dart';
import 'settings_controller.dart';
import '../services/log.dart';

/// Overridden in `main()` with the loaded instance.
final persistenceProvider = Provider<PersistenceService>(
  (_) => throw UnimplementedError('persistenceProvider must be overridden'),
);

/// Overridden in `main()` with an already-initialized engine.
final audioServiceProvider = Provider<AudioService>(
  (_) => throw UnimplementedError('audioServiceProvider must be overridden'),
);

final hapticServiceProvider = Provider<HapticService>((_) => HapticService());

/// Overridden in `main()` after `Firebase.initializeApp()` completes.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (_) =>
      throw UnimplementedError('analyticsServiceProvider must be overridden'),
);

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(
    ref.watch(persistenceProvider),
    ref.watch(audioServiceProvider),
    ref.watch(hapticServiceProvider),
  );
});

final progressProvider =
    StateNotifierProvider<ProgressController, ProgressData>((ref) {
  return ProgressController(ref.watch(persistenceProvider));
});

/// Generated (cached) level for a given 1-based id.
final levelProvider = Provider.family<Level, int>(
  (ref, id) => LevelGenerator.generate(id),
);

/// The active game session for a level id. Auto-disposes when the screen leaves.
final gameControllerProvider = StateNotifierProvider.autoDispose
    .family<GameController, GameSession, int>((ref, id) {
  // Stays alive while the gameplay screen watches it; disposes on leave.
  return GameController(ref, ref.watch(levelProvider(id)));
});

/// Loads the glass fragment shader once. Null if the platform can't compile it
/// (the painter then falls back to a gradient-only glass look).
final glassShaderProvider = FutureProvider<ui.FragmentShader?>((ref) async {
  try {
    final program = await ui.FragmentProgram.fromAsset('shaders/glass.frag');
    return program.fragmentShader();
  } catch (e) {
    Log.w('Shader', 'unavailable, using fallback', e);
    return null;
  }
});
