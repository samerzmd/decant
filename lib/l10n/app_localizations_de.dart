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

  @override
  String get outOfHintsTitle => 'Keine Tipps mehr';

  @override
  String get watchForHintMessage =>
      'Sieh dir ein kurzes Video an, um jetzt einen Tipp zu bekommen, oder löse ein Level, um einen zu verdienen.';

  @override
  String get watchVideo => 'Video ansehen';

  @override
  String get noVideoReady =>
      'Gerade ist kein Video bereit. Versuch es gleich noch einmal.';

  @override
  String get videoNotFinished =>
      'Das Video wurde vorzeitig beendet, daher gibt es diesmal keinen Tipp.';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get adPrivacyChoices => 'Datenschutzoptionen für Werbung';

  @override
  String get adPrivacySubtitle => 'Ändern, wie Werbung deine Daten nutzt';

  @override
  String levelTitle(int level) {
    return 'Level $level';
  }

  @override
  String get cloudSave => 'Cloud-Speicher';

  @override
  String get cloudSaveSubtitle =>
      'Sichere deinen Fortschritt und spiel auf jedem Gerät weiter.';

  @override
  String get signInWithGoogle => 'Mit Google anmelden';

  @override
  String cloudSignedInAs(String account) {
    return 'Angemeldet als $account';
  }

  @override
  String get cloudSyncing => 'Wird synchronisiert …';

  @override
  String get cloudSynced => 'Fortschritt gesichert';

  @override
  String get cloudSyncFailed =>
      'Die Cloud ist nicht erreichbar. Es wird erneut versucht.';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get signOut => 'Abmelden';

  @override
  String get signedOutNotice =>
      'Abgemeldet. Dein Fortschritt bleibt auf diesem Handy.';

  @override
  String get signInFailed =>
      'Anmeldung fehlgeschlagen. Prüfe deine Verbindung und versuch es noch einmal.';

  @override
  String get deleteCloudSave => 'Cloud-Speicher löschen';

  @override
  String get deleteCloudSaveMessage =>
      'Dein in der Cloud gespeicherter Fortschritt und dein Decant-Konto werden gelöscht. Der Fortschritt auf diesem Handy bleibt.';

  @override
  String get delete => 'Löschen';

  @override
  String get cloudDeleted => 'Cloud-Speicher gelöscht.';

  @override
  String get cloudDeleteFailed =>
      'Löschen fehlgeschlagen. Prüfe deine Verbindung und versuch es noch einmal.';

  @override
  String get share => 'Teilen';

  @override
  String dailyShareTitle(String date) {
    return 'Decant Tagesrätsel · $date';
  }

  @override
  String dailyShareStreak(int days) {
    return '$days Tage in Folge';
  }

  @override
  String get dailyShareInvite => 'Schaffst du es besser?';

  @override
  String get achievements => 'Erfolge';

  @override
  String achievementsProgress(int done, int total) {
    return '$done von $total freigeschaltet';
  }

  @override
  String achievementUnlocked(String name) {
    return 'Erfolg freigeschaltet: $name';
  }

  @override
  String achLevels(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Löse $countString Level',
      one: 'Löse dein erstes Level',
    );
    return '$_temp0';
  }

  @override
  String achStars(int count) {
    return 'Sammle $count Sterne';
  }

  @override
  String achPerfect(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString perfekte Lösungen',
      one: 'Löse ein Level perfekt',
    );
    return '$_temp0';
  }

  @override
  String achDailies(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Löse $countString Tagesrätsel',
      one: 'Löse ein Tagesrätsel',
    );
    return '$_temp0';
  }

  @override
  String achDailyStreak(int count) {
    return 'Tagesserie von $count Tagen';
  }

  @override
  String achPlayStreak(int count) {
    return 'Spiel $count Tage in Folge';
  }

  @override
  String achChallengeStage(int count) {
    return 'Erreiche Stufe $count in einer Herausforderung';
  }

  @override
  String get create => 'Erstellen';

  @override
  String get createSubtitle => 'Rätsel bauen und teilen';

  @override
  String get levelEditor => 'Level-Editor';

  @override
  String get editorHelp =>
      'Wähle eine Farbe und tippe auf ein Röhrchen, um eine Schicht hinzuzufügen. Lange drücken entfernt die oberste Schicht.';

  @override
  String get editorColors => 'Farben';

  @override
  String get editorShuffle => 'Mischen';

  @override
  String get editorClear => 'Leeren';

  @override
  String get editorPlay => 'Spielen';

  @override
  String get editorShare => 'Code teilen';

  @override
  String get editorEnterCode => 'Code eingeben';

  @override
  String get editorCodeHint => 'Level-Code einfügen';

  @override
  String get editorOpen => 'Öffnen';

  @override
  String get editorInvalidCode => 'Das ist kein gültiger Decant-Level-Code.';

  @override
  String editorIncomplete(int count) {
    return 'Jede Farbe braucht genau $count Schichten.';
  }

  @override
  String get editorUnsolvable =>
      'Dieses Rätsel ist nicht lösbar. Verschiebe ein paar Schichten.';

  @override
  String get editorAlreadySolved =>
      'Dieses Rätsel ist schon sortiert. Misch die Schichten zuerst.';

  @override
  String get editorShareInvite =>
      'Kannst du mein Decant-Rätsel lösen? Öffne Decant, tippe auf Erstellen → Code eingeben und füge ein:';

  @override
  String get customLevel => 'Eigenes Level';

  @override
  String get myLevels => 'Meine Level';

  @override
  String get leaderboard => 'Bestenliste';

  @override
  String get leaderboardToday => 'Heutiges Tagesrätsel';

  @override
  String get leaderboardSignIn =>
      'Melde dich unter Einstellungen → Cloud-Speicher mit Google an, um bei der heutigen Bestenliste mitzumachen.';

  @override
  String get leaderboardEmpty =>
      'Heute noch keine Ergebnisse. Sei die erste Person!';

  @override
  String get leaderboardFailed =>
      'Die Bestenliste konnte nicht geladen werden. Prüfe deine Verbindung.';

  @override
  String leaderboardYouAs(String name) {
    return 'Du erscheinst als $name';
  }

  @override
  String get you => 'Du';

  @override
  String get editorQrHelp =>
      'Freunde können ihn in Decant scannen: Erstellen → Code eingeben → QR-Code scannen.';

  @override
  String get editorSendText => 'Als Text senden';

  @override
  String get editorScanQr => 'QR-Code scannen';

  @override
  String get scanHelp =>
      'Richte die Kamera auf den QR-Code eines Decant-Levels.';

  @override
  String get scanWrongCode => 'Dieser QR-Code ist kein Decant-Level.';

  @override
  String get scanNoPermission =>
      'Decant kann die Kamera nicht nutzen. Erlaube es in den Einstellungen deines Handys oder füge den Code ein.';

  @override
  String get scanUnavailable =>
      'Die Kamera ist nicht verfügbar. Füge den Code ein.';
}
