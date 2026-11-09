import '../audio/audio_service.dart';

/// All user-tunable settings: the three audio buses plus haptics and the
/// colorblind-friendly rendering option.
class AppSettings {
  final AudioSettings audio;
  final bool hapticsEnabled;

  /// When true, segments also show a distinct symbol/pattern (not color alone).
  final bool colorblindMode;

  /// Keep the display awake while Decant is in the foreground.
  final bool keepScreenOn;

  /// The first-run how-to-play guide has been finished or skipped.
  final bool tutorialSeen;

  const AppSettings({
    this.audio = const AudioSettings(),
    this.hapticsEnabled = true,
    this.colorblindMode = false,
    this.keepScreenOn = false,
    this.tutorialSeen = false,
  });

  AppSettings copyWith({
    AudioSettings? audio,
    bool? hapticsEnabled,
    bool? colorblindMode,
    bool? keepScreenOn,
    bool? tutorialSeen,
  }) =>
      AppSettings(
        audio: audio ?? this.audio,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        colorblindMode: colorblindMode ?? this.colorblindMode,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        tutorialSeen: tutorialSeen ?? this.tutorialSeen,
      );

  Map<String, dynamic> toJson() => {
        'audio': audio.toJson(),
        'haptics': hapticsEnabled,
        'colorblind': colorblindMode,
        'keepScreenOn': keepScreenOn,
        'tutorialSeen': tutorialSeen,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        audio: j['audio'] is Map
            ? AudioSettings.fromJson((j['audio'] as Map).cast<String, dynamic>())
            : const AudioSettings(),
        hapticsEnabled: j['haptics'] as bool? ?? true,
        colorblindMode: j['colorblind'] as bool? ?? false,
        keepScreenOn: j['keepScreenOn'] as bool? ?? false,
        tutorialSeen: j['tutorialSeen'] as bool? ?? false,
      );
}
