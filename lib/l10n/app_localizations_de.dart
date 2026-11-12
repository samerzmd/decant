// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get tagline => 'Gießen. Sortieren. Entspannen.';

  @override
  String get play => 'Spielen';

  @override
  String get levels => 'Level';

  @override
  String get challenges => 'Herausforderungen';

  @override
  String get stats => 'Statistik';

  @override
  String get settings => 'Einstellungen';

  @override
  String get dailyChallenge => 'Tagesrätsel';

  @override
  String get dailyDone => 'Tagesrätsel geschafft';

  @override
  String dailyTitle(String date) {
    return 'Täglich · $date';
  }

  @override
  String get exitTitle => 'Decant beenden?';

  @override
  String get exitMessage =>
      'Atme durch – dein Fortschritt ist gespeichert. App verlassen?';

  @override
  String get exit => 'Beenden';

  @override
  String get stay => 'Bleiben';

  @override
  String get leave => 'Verlassen';

  @override
  String get back => 'Zurück';

  @override
  String get audio => 'Audio';

  @override
  String get muteAll => 'Alles stumm';

  @override
  String get soundEffects => 'Soundeffekte';

  @override
  String get ambience => 'Ambiente';

  @override
  String get music => 'Musik';

  @override
  String get ambientLoop => 'Hintergrund-Ambiente';

  @override
  String get ambienceSound => 'Ambiente-Klang';

  @override
  String soundCount(String category, int count) {
    return '$category · $count Klänge';
  }

  @override
  String get backgroundMusic => 'Hintergrundmusik';

  @override
  String get backgroundMusicSubtitle => 'Ruhige Musik über dem Ambiente';

  @override
  String get musicTrack => 'Musikstück';

  @override
  String trackCount(String category, int count) {
    return '$category · $count Stücke';
  }

  @override
  String get feel => 'Gefühl';

  @override
  String get haptics => 'Haptisches Feedback';

  @override
  String get keepAwake => 'Bildschirm anlassen';

  @override
  String get pourSpeed => 'Gießgeschwindigkeit';

  @override
  String get pourRelaxed => 'Gemütlich';

  @override
  String get pourNormal => 'Normal';

  @override
  String get pourQuick => 'Schnell';

  @override
  String get zenMode => 'Zen-Modus';

  @override
  String get zenModeSubtitle => 'Kein Zugzähler, keine Sterne. Einfach gießen.';

  @override
  String get accessibility => 'Barrierefreiheit';

  @override
  String get theme => 'Design';

  @override
  String get themeTwilight => 'Dämmerung';

  @override
  String get themeMidnight => 'Mitternacht';

  @override
  String get themeDaylight => 'Tageslicht';

  @override
  String get highContrast => 'Hoher Kontrast';

  @override
  String get liquidColors => 'Flüssigkeitsfarben';

  @override
  String get paletteStandard => 'Standard';

  @override
  String get paletteColorblind => 'Farbenblind-sicher';

  @override
  String get colorblindSymbols => 'Farbenblind-Symbole';

  @override
  String get colorblindSubtitle => 'Zeigt auf jeder Farbe eine eigene Form';

  @override
  String get reduceMotion => 'Bewegung reduzieren';

  @override
  String get reduceMotionSubtitle => 'Keine Blasen, kein Kippen oder Wackeln';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'System';

  @override
  String get timesUp => 'Zeit ist um';

  @override
  String get outOfMoves => 'Keine Züge mehr';

  @override
  String get failMessage => 'Atme durch und versuch es noch mal.';

  @override
  String get retry => 'Nochmal';

  @override
  String get dailySolved => 'Tagesrätsel gelöst';

  @override
  String stageCleared(int stage) {
    return 'Stufe $stage geschafft';
  }

  @override
  String levelSolved(int level) {
    return 'Level $level gelöst';
  }

  @override
  String get beautifullyDone => 'Wunderschön gemacht.';

  @override
  String streakBeautifullyDone(int days) {
    return '$days-Tage-Serie. Wunderschön gemacht.';
  }

  @override
  String moveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Züge',
      one: '1 Zug',
    );
    return '$_temp0';
  }

  @override
  String perfectTarget(String moves) {
    return 'Perfekt: $moves, ohne Hilfe';
  }

  @override
  String get perfect => 'Perfekt';

  @override
  String get done => 'Fertig';

  @override
  String get nextStage => 'Nächste Stufe';

  @override
  String get nextLevel => 'Nächstes Level';

  @override
  String get replay => 'Wiederholen';

  @override
  String get leaveLevelTitle => 'Level verlassen?';

  @override
  String get leaveLevelMessage =>
      'Dein Fortschritt in diesem Level wird nicht gespeichert – du fängst nächstes Mal neu an.';

  @override
  String get keepPlaying => 'Weiterspielen';

  @override
  String get noMovesHint => 'Keine Züge mehr – rückgängig oder neu starten';

  @override
  String get noHintsLeft =>
      'Keine Tipps mehr. Löse ein Level, um einen zu verdienen.';

  @override
  String get noExtraTubes => 'Keine Extra-Röhren mehr';

  @override
  String levelHeader(int level, String chapter) {
    return 'Level $level · $chapter';
  }

  @override
  String difficulty(String dots) {
    return 'Schwierigkeit $dots';
  }

  @override
  String threeStarsIn(int moves) {
    return '★★★ in $moves';
  }

  @override
  String get undo => 'Rückgängig';

  @override
  String get hint => 'Tipp';

  @override
  String get addTube => 'Leere Röhre hinzufügen';

  @override
  String get howToPlay => 'So wird gespielt';

  @override
  String get stuckBanner =>
      'Keine Züge mehr. Rückgängig, neu starten oder eine leere Röhre hinzufügen.';

  @override
  String stageTitle(String mode, int stage) {
    return '$mode · Stufe $stage';
  }

  @override
  String get tutorialTapTitle => 'Tippe auf die leuchtende Röhre';

  @override
  String get tutorialTapBody => 'So nimmst du die oberste Farbe auf.';

  @override
  String get tutorialPourTitle => 'Tippe jetzt auf die andere leuchtende Röhre';

  @override
  String get tutorialPourBody =>
      'Farben lassen sich auf dieselbe Farbe oder in eine leere Röhre gießen.';

  @override
  String get skip => 'Überspringen';

  @override
  String get tutorialGoal => 'Sortiere jede Röhre in eine Farbe';

  @override
  String get tutorialStars =>
      'Weniger Züge bringen mehr Sterne. Wenn du feststeckst:';

  @override
  String get tutorialUndo => 'Einen Guss rückgängig machen';

  @override
  String get tutorialHint => 'Tipp zeigen (kostet einen Stern)';

  @override
  String get tutorialAddTube => 'Eine leere Röhre hinzufügen';

  @override
  String get gotIt => 'Verstanden';

  @override
  String get levelsSolved => 'Gelöste Level';

  @override
  String nextUp(int level) {
    return 'Als Nächstes: Level $level';
  }

  @override
  String get stars => 'Sterne';

  @override
  String get perfectLevels => 'Perfekte Level';

  @override
  String get perfectLevelsDetail => 'Mindestzüge, ohne Tipps';

  @override
  String get wins => 'Siege';

  @override
  String get winsDetail => 'Wiederholungen inklusive';

  @override
  String get starsPerLevel => 'Sterne pro Level';

  @override
  String get noStreak => 'Noch keine Serie';

  @override
  String streak(int days) {
    return '$days-Tage-Serie';
  }

  @override
  String get streakStart => 'Gewinne heute ein Level, um eine zu starten.';

  @override
  String get streakDone => 'Der heutige Sieg ist drin. Bis morgen.';

  @override
  String get streakKeep => 'Gewinne heute ein Level, um sie zu halten.';

  @override
  String get statsEmpty => 'Löse ein Level, um deine Sterne zu sehen.';

  @override
  String bestStage(int stage) {
    return 'Bestes: Stufe $stage';
  }

  @override
  String get notPlayed => 'Noch nicht gespielt';

  @override
  String playStage(int stage) {
    return 'Stufe $stage spielen';
  }

  @override
  String get modeMoves => 'Zuglimit';

  @override
  String get modeMovesBlurb => 'Löse innerhalb des Zuglimits. Kein Rückgängig.';

  @override
  String get modeTimed => 'Gegen die Uhr';

  @override
  String get modeTimedBlurb => 'Schlag die Uhr. Sie startet beim ersten Guss.';

  @override
  String levelShort(int level) {
    return 'Lvl $level';
  }

  @override
  String chapterTitle(int number, String name) {
    return 'Kapitel $number · $name';
  }

  @override
  String chapterSolved(int solved, int total) {
    return '$solved/$total gelöst';
  }

  @override
  String get chapterDawn => 'Morgen';

  @override
  String get chapterTide => 'Flut';

  @override
  String get chapterEmber => 'Glut';

  @override
  String get chapterGrove => 'Hain';

  @override
  String get chapterDusk => 'Abend';

  @override
  String get chapterAurora => 'Polarlicht';

  @override
  String get dailyNew => 'Jeden Tag ein neues Rätsel';

  @override
  String get streakReminders => 'Serien-Erinnerungen';

  @override
  String get streakRemindersSubtitle =>
      'Ein sanfter Hinweis, wenn das Tagesrätsel noch offen ist';

  @override
  String get reminderTime => 'Erinnerungszeit';

  @override
  String get notificationsBlocked =>
      'Benachrichtigungen für Decant sind aus. Schalte sie in den Systemeinstellungen ein.';

  @override
  String reminderStreakTitle(int days) {
    return 'Halte deine $days-Tage-Serie';
  }

  @override
  String get reminderStreakBody => 'Das heutige Tagesrätsel wartet.';

  @override
  String get reminderTitle => 'Ein neues Tagesrätsel ist da';

  @override
  String get reminderBody => 'Nimm dir eine ruhige Minute und gieß.';

  @override
  String get reminderOfferTitle => 'Serie halten?';

  @override
  String reminderOfferMessage(String time) {
    return 'Decant kann dich an Tagen ohne gelöstes Tagesrätsel um $time sanft erinnern. Das lässt sich in den Einstellungen ändern.';
  }

  @override
  String get remindMe => 'Erinnere mich';

  @override
  String get notNow => 'Nicht jetzt';
}
