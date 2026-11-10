import '../audio/audio_service.dart';
import 'liquid_palette.dart';

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

/// The app's language: the phone's, or one picked in Settings.
enum AppLanguage {
  system(null, 'System'),
  en('en', 'English'),
  es('es', 'Español'),
  fr('fr', 'Français'),
  de('de', 'Deutsch');

  /// Language code, or null to follow the phone.
  final String? code;

  /// The language's name in that language.
  final String nativeName;
  const AppLanguage(this.code, this.nativeName);

  static AppLanguage fromName(String? name) => AppLanguage.values
      .firstWhere((l) => l.name == name, orElse: () => AppLanguage.system);
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

  /// The colors liquids are drawn in.
  final LiquidPalette liquidPalette;

  /// The background theme.
  final UiTheme uiTheme;

  /// The app's language.
  final AppLanguage language;

  /// Remind the player when today's daily isn't solved yet.
  final bool streakReminders;

  /// Hour of the day (0–23, local time) the reminder shows.
  final int reminderHour;

  /// The one-time "Keep your streak?" offer has been shown.
  final bool reminderOffered;

  const AppSettings({
    this.audio = const AudioSettings(),
    this.hapticsEnabled = true,
    this.colorblindMode = false,
    this.keepScreenOn = false,
    this.tutorialSeen = false,
    this.pourSpeed = PourSpeed.normal,
    this.reduceMotion = false,
    this.zenMode = false,
    this.liquidPalette = LiquidPalette.standard,
    this.uiTheme = UiTheme.twilight,
    this.language = AppLanguage.system,
    this.streakReminders = false,
    this.reminderHour = 19,
    this.reminderOffered = false,
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
    LiquidPalette? liquidPalette,
    UiTheme? uiTheme,
    AppLanguage? language,
    bool? streakReminders,
    int? reminderHour,
    bool? reminderOffered,
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
        liquidPalette: liquidPalette ?? this.liquidPalette,
        uiTheme: uiTheme ?? this.uiTheme,
        language: language ?? this.language,
        streakReminders: streakReminders ?? this.streakReminders,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderOffered: reminderOffered ?? this.reminderOffered,
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
        'liquidPalette': liquidPalette.name,
        'uiTheme': uiTheme.name,
        'language': language.name,
        'streakReminders': streakReminders,
        'reminderHour': reminderHour,
        'reminderOffered': reminderOffered,
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
        liquidPalette: LiquidPalette.fromName(j['liquidPalette'] as String?),
        uiTheme: UiTheme.fromName(j['uiTheme'] as String?),
        language: AppLanguage.fromName(j['language'] as String?),
        streakReminders: j['streakReminders'] as bool? ?? false,
        reminderHour: _hour(j['reminderHour']),
        reminderOffered: j['reminderOffered'] as bool? ?? false,
      );

  /// A saved reminder hour, or the 7 pm default if it's missing or invalid.
  static int _hour(Object? v) => v is int && v >= 0 && v < 24 ? v : 19;
}
