import '../audio/audio_service.dart';

/// How long a whole pour takes: the source tube flying over, tipping, the
/// liquid flowing and the tube returning. Animation, sound and game logic all
/// follow it. The flowing part (about 54%) matches the original pour lengths.
enum PourSpeed {
  relaxed('Relaxed', Duration(milliseconds: 1400)),
  normal('Normal', Duration(milliseconds: 1000)),
  quick('Quick', Duration(milliseconds: 640));

  final String label;
  final Duration duration;
  const PourSpeed(this.label, this.duration);

  static PourSpeed fromName(String? name) => PourSpeed.values.firstWhere(
        (s) => s.name == name,
        orElse: () => PourSpeed.normal,
      );
}

/// All user-tunable settings: the three audio buses, haptics, accessibility
/// options (colorblind symbols, reduced motion) and pour speed.
class AppSettings {
  final AudioSettings audio;
  final bool hapticsEnabled;

  /// When true, segments also show a distinct symbol/pattern (not color alone).
  final bool colorblindMode;

  /// Keep the display awake while Decant is in the foreground.
  final bool keepScreenOn;

  /// The first-run how-to-play guide has been finished or skipped.
  final bool tutorialSeen;

  /// How fast liquid pours.
  final PourSpeed pourSpeed;

  /// Calmer visuals: no idle bubbles, tube tilt or wobble. Also applied when
  /// the system asks for fewer animations.
  final bool reduceMotion;

  /// Pure unwinding: no move counter and no stars. Levels still count as
  /// solved and unlock the next one.
  final bool zenMode;

  const AppSettings({
    this.audio = const AudioSettings(),
    this.hapticsEnabled = true,
    this.colorblindMode = false,
    this.keepScreenOn = false,
    this.tutorialSeen = false,
    this.pourSpeed = PourSpeed.normal,
    this.reduceMotion = false,
    this.zenMode = false,
  });

  AppSettings copyWith({
    AudioSettings? audio,
    bool? hapticsEnabled,
    bool? colorblindMode,
    bool? keepScreenOn,
    bool? tutorialSeen,
    PourSpeed? pourSpeed,
    bool? reduceMotion,
    bool? zenMode,
  }) =>
      AppSettings(
        audio: audio ?? this.audio,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        colorblindMode: colorblindMode ?? this.colorblindMode,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        tutorialSeen: tutorialSeen ?? this.tutorialSeen,
        pourSpeed: pourSpeed ?? this.pourSpeed,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        zenMode: zenMode ?? this.zenMode,
      );

  Map<String, dynamic> toJson() => {
        'audio': audio.toJson(),
        'haptics': hapticsEnabled,
        'colorblind': colorblindMode,
        'keepScreenOn': keepScreenOn,
        'tutorialSeen': tutorialSeen,
        'pourSpeed': pourSpeed.name,
        'reduceMotion': reduceMotion,
        'zenMode': zenMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        audio: j['audio'] is Map
            ? AudioSettings.fromJson(
                (j['audio'] as Map).cast<String, dynamic>())
            : const AudioSettings(),
        hapticsEnabled: j['haptics'] as bool? ?? true,
        colorblindMode: j['colorblind'] as bool? ?? false,
        keepScreenOn: j['keepScreenOn'] as bool? ?? false,
        tutorialSeen: j['tutorialSeen'] as bool? ?? false,
        pourSpeed: PourSpeed.fromName(j['pourSpeed'] as String?),
        reduceMotion: j['reduceMotion'] as bool? ?? false,
        zenMode: j['zenMode'] as bool? ?? false,
      );
}
