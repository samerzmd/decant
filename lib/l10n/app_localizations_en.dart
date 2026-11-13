// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tagline => 'Pour. Sort. Unwind.';

  @override
  String get play => 'Play';

  @override
  String get levels => 'Levels';

  @override
  String get challenges => 'Challenges';

  @override
  String get stats => 'Stats';

  @override
  String get settings => 'Settings';

  @override
  String get dailyChallenge => 'Daily challenge';

  @override
  String get dailyDone => 'Daily done';

  @override
  String dailyTitle(String date) {
    return 'Daily · $date';
  }

  @override
  String get exitTitle => 'Exit Decant?';

  @override
  String get exitMessage =>
      'Take a breath — your progress is saved. Leave the app?';

  @override
  String get exit => 'Exit';

  @override
  String get stay => 'Stay';

  @override
  String get leave => 'Leave';

  @override
  String get back => 'Back';

  @override
  String get audio => 'Audio';

  @override
  String get muteAll => 'Mute all';

  @override
  String get soundEffects => 'Sound effects';

  @override
  String get ambience => 'Ambience';

  @override
  String get music => 'Music';

  @override
  String get ambientLoop => 'Ambient background loop';

  @override
  String get ambienceSound => 'Ambience sound';

  @override
  String soundCount(String category, int count) {
    return '$category · $count sounds';
  }

  @override
  String get backgroundMusic => 'Background music';

  @override
  String get backgroundMusicSubtitle => 'Calm music on top of the ambience';

  @override
  String get musicTrack => 'Music track';

  @override
  String trackCount(String category, int count) {
    return '$category · $count tracks';
  }

  @override
  String get feel => 'Feel';

  @override
  String get haptics => 'Haptic feedback';

  @override
  String get keepAwake => 'Keep screen awake';

  @override
  String get pourSpeed => 'Pour speed';

  @override
  String get pourRelaxed => 'Relaxed';

  @override
  String get pourNormal => 'Normal';

  @override
  String get pourQuick => 'Quick';

  @override
  String get zenMode => 'Zen mode';

  @override
  String get zenModeSubtitle => 'No move counter or stars. Just pour.';

  @override
  String get accessibility => 'Accessibility';

  @override
  String get theme => 'Theme';

  @override
  String get themeTwilight => 'Twilight';

  @override
  String get themeMidnight => 'Midnight';

  @override
  String get themeDaylight => 'Daylight';

  @override
  String get highContrast => 'High contrast';

  @override
  String get liquidColors => 'Liquid colors';

  @override
  String get paletteStandard => 'Standard';

  @override
  String get paletteColorblind => 'Colorblind-safe';

  @override
  String get colorblindSymbols => 'Colorblind symbols';

  @override
  String get colorblindSubtitle => 'Show a distinct shape on each liquid color';

  @override
  String get reduceMotion => 'Reduce motion';

  @override
  String get reduceMotionSubtitle => 'No bubbles, tilting or wobbling';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get timesUp => 'Time\'s up';

  @override
  String get outOfMoves => 'Out of moves';

  @override
  String get failMessage => 'Take a breath and try again.';

  @override
  String get retry => 'Retry';

  @override
  String get dailySolved => 'Daily challenge solved';

  @override
  String stageCleared(int stage) {
    return 'Stage $stage cleared';
  }

  @override
  String levelSolved(int level) {
    return 'Level $level solved';
  }

  @override
  String get beautifullyDone => 'Beautifully done.';

  @override
  String streakBeautifullyDone(int days) {
    return '$days-day streak. Beautifully done.';
  }

  @override
  String moveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count moves',
      one: '1 move',
    );
    return '$_temp0';
  }

  @override
  String perfectTarget(String moves) {
    return 'Perfect: $moves, no help';
  }

  @override
  String get perfect => 'Perfect';

  @override
  String get done => 'Done';

  @override
  String get nextStage => 'Next stage';

  @override
  String get nextLevel => 'Next level';

  @override
  String get replay => 'Replay';

  @override
  String get leaveLevelTitle => 'Leave this level?';

  @override
  String get leaveLevelMessage =>
      'Your progress on this level isn\'t saved — you\'ll start it over next time.';

  @override
  String get keepPlaying => 'Keep playing';

  @override
  String get noMovesHint => 'No moves left — try undo or restart';

  @override
  String get noHintsLeft => 'No hints left. Solve a level to earn one.';

  @override
  String get noExtraTubes => 'No extra tubes left';

  @override
  String levelHeader(int level, String chapter) {
    return 'Level $level · $chapter';
  }

  @override
  String difficulty(String dots) {
    return 'Difficulty $dots';
  }

  @override
  String threeStarsIn(int moves) {
    return '★★★ in $moves';
  }

  @override
  String get undo => 'Undo';

  @override
  String get hint => 'Hint';

  @override
  String get addTube => 'Add empty tube';

  @override
  String get howToPlay => 'How to play';

  @override
  String get stuckBanner =>
      'No moves left. Undo, restart, or add an empty tube.';

  @override
  String stageTitle(String mode, int stage) {
    return '$mode · Stage $stage';
  }

  @override
  String get tutorialTapTitle => 'Tap the glowing tube';

  @override
  String get tutorialTapBody => 'That picks up the color on top.';

  @override
  String get tutorialPourTitle => 'Now tap the other glowing tube';

  @override
  String get tutorialPourBody =>
      'Colors pour onto the same color or into an empty tube.';

  @override
  String get skip => 'Skip';

  @override
  String get tutorialGoal => 'Sort every tube into one color';

  @override
  String get tutorialStars => 'Fewer moves earn more stars. If you\'re stuck:';

  @override
  String get tutorialUndo => 'Undo a pour';

  @override
  String get tutorialHint => 'Show a hint (costs a star)';

  @override
  String get tutorialAddTube => 'Add an empty tube';

  @override
  String get gotIt => 'Got it';

  @override
  String get levelsSolved => 'Levels solved';

  @override
  String nextUp(int level) {
    return 'Next up: level $level';
  }

  @override
  String get stars => 'Stars';

  @override
  String get perfectLevels => 'Perfect levels';

  @override
  String get perfectLevelsDetail => 'Par moves, no hints';

  @override
  String get wins => 'Wins';

  @override
  String get winsDetail => 'Replays included';

  @override
  String get starsPerLevel => 'Stars per level';

  @override
  String get noStreak => 'No streak yet';

  @override
  String streak(int days) {
    return '$days-day streak';
  }

  @override
  String get streakStart => 'Win a level today to start one.';

  @override
  String get streakDone => 'Today\'s win is in. See you tomorrow.';

  @override
  String get streakKeep => 'Win a level today to keep it going.';

  @override
  String get statsEmpty => 'Solve a level to see how your stars stack up.';

  @override
  String bestStage(int stage) {
    return 'Best: stage $stage';
  }

  @override
  String get notPlayed => 'Not played yet';

  @override
  String playStage(int stage) {
    return 'Play stage $stage';
  }

  @override
  String get modeMoves => 'Move limit';

  @override
  String get modeMovesBlurb => 'Solve within the move limit. No undo.';

  @override
  String get modeTimed => 'Against the clock';

  @override
  String get modeTimedBlurb => 'Beat the timer. It starts on your first pour.';

  @override
  String levelShort(int level) {
    return 'Lvl $level';
  }

  @override
  String chapterTitle(int number, String name) {
    return 'Chapter $number · $name';
  }

  @override
  String chapterSolved(int solved, int total) {
    return '$solved/$total solved';
  }

  @override
  String get chapterDawn => 'Dawn';

  @override
  String get chapterTide => 'Tide';

  @override
  String get chapterEmber => 'Ember';

  @override
  String get chapterGrove => 'Grove';

  @override
  String get chapterDusk => 'Dusk';

  @override
  String get chapterAurora => 'Aurora';

  @override
  String get dailyNew => 'A new puzzle every day';

  @override
  String get streakReminders => 'Streak reminders';

  @override
  String get streakRemindersSubtitle =>
      'A gentle nudge when today\'s daily isn\'t done';

  @override
  String get reminderTime => 'Reminder time';

  @override
  String get notificationsBlocked =>
      'Notifications are off for Decant. Turn them on in system settings.';

  @override
  String reminderStreakTitle(int days) {
    return 'Keep your $days-day streak going';
  }

  @override
  String get reminderStreakBody => 'Today\'s daily puzzle is waiting.';

  @override
  String get reminderTitle => 'A new daily puzzle is ready';

  @override
  String get reminderBody => 'Take a calm minute and pour.';

  @override
  String get reminderOfferTitle => 'Keep your streak?';

  @override
  String reminderOfferMessage(String time) {
    return 'Decant can send one gentle reminder at $time on days you haven\'t solved the daily. You can change this in Settings.';
  }

  @override
  String get remindMe => 'Remind me';

  @override
  String get notNow => 'Not now';

  @override
  String get outOfHintsTitle => 'Out of hints';

  @override
  String get watchForHintMessage =>
      'Watch a short video for a hint now, or solve a level to earn one back.';

  @override
  String get watchVideo => 'Watch video';

  @override
  String get noVideoReady =>
      'No video is ready right now. Try again in a moment.';

  @override
  String get videoNotFinished => 'The video ended early, so no hint this time.';

  @override
  String get privacy => 'Privacy';

  @override
  String get adPrivacyChoices => 'Ad privacy choices';

  @override
  String get adPrivacySubtitle => 'Change how ads use your data';

  @override
  String levelTitle(int level) {
    return 'Level $level';
  }

  @override
  String get cloudSave => 'Cloud save';

  @override
  String get cloudSaveSubtitle =>
      'Back up your progress and pick it up on any device.';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String cloudSignedInAs(String account) {
    return 'Signed in as $account';
  }

  @override
  String get cloudSyncing => 'Syncing…';

  @override
  String get cloudSynced => 'Progress backed up';

  @override
  String get cloudSyncFailed => 'Couldn\'t reach the cloud. It\'ll try again.';

  @override
  String get syncNow => 'Sync now';

  @override
  String get signOut => 'Sign out';

  @override
  String get signedOutNotice =>
      'Signed out. Your progress stays on this phone.';

  @override
  String get signInFailed =>
      'Couldn\'t sign in. Check your connection and try again.';

  @override
  String get deleteCloudSave => 'Delete cloud save';

  @override
  String get deleteCloudSaveMessage =>
      'This deletes your saved progress from the cloud and your Decant account. Progress on this phone stays.';

  @override
  String get delete => 'Delete';

  @override
  String get cloudDeleted => 'Cloud save deleted.';

  @override
  String get cloudDeleteFailed =>
      'Couldn\'t delete it. Check your connection and try again.';
}
