import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../logic/challenge.dart';
import '../logic/daily_challenge.dart';
import '../models/app_settings.dart';
import '../models/chapter.dart';
import '../models/liquid_palette.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

final AppLocalizations _english = lookupAppLocalizations(const Locale('en'));

extension L10nContext on BuildContext {
  /// The app's strings in the current language. Falls back to English where
  /// no localizations are installed (e.g. a bare MaterialApp in tests).
  AppLocalizations get l10n => AppLocalizations.of(this) ?? _english;
}

/// Display names for values whose labels live in the models.
extension L10nLabels on AppLocalizations {
  String pourSpeedLabel(PourSpeed s) => switch (s) {
        PourSpeed.relaxed => pourRelaxed,
        PourSpeed.normal => pourNormal,
        PourSpeed.quick => pourQuick,
      };

  String uiThemeLabel(UiTheme t) => switch (t) {
        UiTheme.twilight => themeTwilight,
        UiTheme.midnight => themeMidnight,
        UiTheme.highContrast => highContrast,
      };

  String liquidPaletteLabel(LiquidPalette p) => switch (p) {
        LiquidPalette.standard => paletteStandard,
        LiquidPalette.colorblindSafe => paletteColorblind,
        LiquidPalette.highContrast => highContrast,
      };

  /// Language names are always shown in their own language.
  String appLanguageLabel(AppLanguage l) =>
      l == AppLanguage.system ? languageSystem : l.nativeName;

  String challengeMode(ChallengeMode m) => switch (m) {
        ChallengeMode.moves => modeMoves,
        ChallengeMode.timed => modeTimed,
      };

  String challengeBlurb(ChallengeMode m) => switch (m) {
        ChallengeMode.moves => modeMovesBlurb,
        ChallengeMode.timed => modeTimedBlurb,
      };

  /// E.g. "Move limit · Stage 3".
  String challengeTitle(int levelId) => stageTitle(
      challengeMode(Challenge.modeOf(levelId)), Challenge.stageOf(levelId));

  /// E.g. "Daily · Nov 10", with the month in the current language.
  String dailyChallengeTitle(int levelId) {
    final date = DailyChallenge.dateOf(levelId);
    try {
      return dailyTitle(DateFormat.MMMd(localeName).format(date));
    } on Exception {
      // Date names load with the Material localizations; without them
      // (e.g. in widget tests) fall back to the English title.
      return DailyChallenge.title(levelId);
    }
  }

  String chapterName(Chapter c) => [
        chapterDawn,
        chapterTide,
        chapterEmber,
        chapterGrove,
        chapterDusk,
        chapterAurora,
      ][(c.number - 1) % Chapter.names.length];

  /// E.g. "Chapter 2 · Tide".
  String chapter(Chapter c) => chapterTitle(c.number, chapterName(c));
}
