import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr')
  ];

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Pour. Sort. Unwind.'**
  String get tagline;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @levels.
  ///
  /// In en, this message translates to:
  /// **'Levels'**
  String get levels;

  /// No description provided for @challenges.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get challenges;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @dailyChallenge.
  ///
  /// In en, this message translates to:
  /// **'Daily challenge'**
  String get dailyChallenge;

  /// No description provided for @dailyDone.
  ///
  /// In en, this message translates to:
  /// **'Daily done'**
  String get dailyDone;

  /// No description provided for @dailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily · {date}'**
  String dailyTitle(String date);

  /// No description provided for @exitTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit Decant?'**
  String get exitTitle;

  /// No description provided for @exitMessage.
  ///
  /// In en, this message translates to:
  /// **'Take a breath — your progress is saved. Leave the app?'**
  String get exitMessage;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @muteAll.
  ///
  /// In en, this message translates to:
  /// **'Mute all'**
  String get muteAll;

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get soundEffects;

  /// No description provided for @ambience.
  ///
  /// In en, this message translates to:
  /// **'Ambience'**
  String get ambience;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @ambientLoop.
  ///
  /// In en, this message translates to:
  /// **'Ambient background loop'**
  String get ambientLoop;

  /// No description provided for @ambienceSound.
  ///
  /// In en, this message translates to:
  /// **'Ambience sound'**
  String get ambienceSound;

  /// No description provided for @soundCount.
  ///
  /// In en, this message translates to:
  /// **'{category} · {count} sounds'**
  String soundCount(String category, int count);

  /// No description provided for @backgroundMusic.
  ///
  /// In en, this message translates to:
  /// **'Background music'**
  String get backgroundMusic;

  /// No description provided for @backgroundMusicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Calm music on top of the ambience'**
  String get backgroundMusicSubtitle;

  /// No description provided for @musicTrack.
  ///
  /// In en, this message translates to:
  /// **'Music track'**
  String get musicTrack;

  /// No description provided for @trackCount.
  ///
  /// In en, this message translates to:
  /// **'{category} · {count} tracks'**
  String trackCount(String category, int count);

  /// No description provided for @feel.
  ///
  /// In en, this message translates to:
  /// **'Feel'**
  String get feel;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get haptics;

  /// No description provided for @keepAwake.
  ///
  /// In en, this message translates to:
  /// **'Keep screen awake'**
  String get keepAwake;

  /// No description provided for @pourSpeed.
  ///
  /// In en, this message translates to:
  /// **'Pour speed'**
  String get pourSpeed;

  /// No description provided for @pourRelaxed.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get pourRelaxed;

  /// No description provided for @pourNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get pourNormal;

  /// No description provided for @pourQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get pourQuick;

  /// No description provided for @zenMode.
  ///
  /// In en, this message translates to:
  /// **'Zen mode'**
  String get zenMode;

  /// No description provided for @zenModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No move counter or stars. Just pour.'**
  String get zenModeSubtitle;

  /// No description provided for @accessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibility;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeTwilight.
  ///
  /// In en, this message translates to:
  /// **'Twilight'**
  String get themeTwilight;

  /// No description provided for @themeMidnight.
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get themeMidnight;

  /// No description provided for @themeDaylight.
  ///
  /// In en, this message translates to:
  /// **'Daylight'**
  String get themeDaylight;

  /// No description provided for @highContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get highContrast;

  /// No description provided for @liquidColors.
  ///
  /// In en, this message translates to:
  /// **'Liquid colors'**
  String get liquidColors;

  /// No description provided for @paletteStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get paletteStandard;

  /// No description provided for @paletteColorblind.
  ///
  /// In en, this message translates to:
  /// **'Colorblind-safe'**
  String get paletteColorblind;

  /// No description provided for @colorblindSymbols.
  ///
  /// In en, this message translates to:
  /// **'Colorblind symbols'**
  String get colorblindSymbols;

  /// No description provided for @colorblindSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show a distinct shape on each liquid color'**
  String get colorblindSubtitle;

  /// No description provided for @reduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get reduceMotion;

  /// No description provided for @reduceMotionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No bubbles, tilting or wobbling'**
  String get reduceMotionSubtitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @timesUp.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up'**
  String get timesUp;

  /// No description provided for @outOfMoves.
  ///
  /// In en, this message translates to:
  /// **'Out of moves'**
  String get outOfMoves;

  /// No description provided for @failMessage.
  ///
  /// In en, this message translates to:
  /// **'Take a breath and try again.'**
  String get failMessage;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @dailySolved.
  ///
  /// In en, this message translates to:
  /// **'Daily challenge solved'**
  String get dailySolved;

  /// No description provided for @stageCleared.
  ///
  /// In en, this message translates to:
  /// **'Stage {stage} cleared'**
  String stageCleared(int stage);

  /// No description provided for @levelSolved.
  ///
  /// In en, this message translates to:
  /// **'Level {level} solved'**
  String levelSolved(int level);

  /// No description provided for @beautifullyDone.
  ///
  /// In en, this message translates to:
  /// **'Beautifully done.'**
  String get beautifullyDone;

  /// No description provided for @streakBeautifullyDone.
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak. Beautifully done.'**
  String streakBeautifullyDone(int days);

  /// No description provided for @moveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 move} other{{count} moves}}'**
  String moveCount(int count);

  /// No description provided for @perfectTarget.
  ///
  /// In en, this message translates to:
  /// **'Perfect: {moves}, no help'**
  String perfectTarget(String moves);

  /// No description provided for @perfect.
  ///
  /// In en, this message translates to:
  /// **'Perfect'**
  String get perfect;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @nextStage.
  ///
  /// In en, this message translates to:
  /// **'Next stage'**
  String get nextStage;

  /// No description provided for @nextLevel.
  ///
  /// In en, this message translates to:
  /// **'Next level'**
  String get nextLevel;

  /// No description provided for @replay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replay;

  /// No description provided for @leaveLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this level?'**
  String get leaveLevelTitle;

  /// No description provided for @leaveLevelMessage.
  ///
  /// In en, this message translates to:
  /// **'Your progress on this level isn\'t saved — you\'ll start it over next time.'**
  String get leaveLevelMessage;

  /// No description provided for @keepPlaying.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get keepPlaying;

  /// No description provided for @noMovesHint.
  ///
  /// In en, this message translates to:
  /// **'No moves left — try undo or restart'**
  String get noMovesHint;

  /// No description provided for @noHintsLeft.
  ///
  /// In en, this message translates to:
  /// **'No hints left. Solve a level to earn one.'**
  String get noHintsLeft;

  /// No description provided for @noExtraTubes.
  ///
  /// In en, this message translates to:
  /// **'No extra tubes left'**
  String get noExtraTubes;

  /// No description provided for @levelHeader.
  ///
  /// In en, this message translates to:
  /// **'Level {level} · {chapter}'**
  String levelHeader(int level, String chapter);

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty {dots}'**
  String difficulty(String dots);

  /// No description provided for @threeStarsIn.
  ///
  /// In en, this message translates to:
  /// **'★★★ in {moves}'**
  String threeStarsIn(int moves);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @hint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get hint;

  /// No description provided for @addTube.
  ///
  /// In en, this message translates to:
  /// **'Add empty tube'**
  String get addTube;

  /// No description provided for @howToPlay.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get howToPlay;

  /// No description provided for @stuckBanner.
  ///
  /// In en, this message translates to:
  /// **'No moves left. Undo, restart, or add an empty tube.'**
  String get stuckBanner;

  /// No description provided for @stageTitle.
  ///
  /// In en, this message translates to:
  /// **'{mode} · Stage {stage}'**
  String stageTitle(String mode, int stage);

  /// No description provided for @tutorialTapTitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the glowing tube'**
  String get tutorialTapTitle;

  /// No description provided for @tutorialTapBody.
  ///
  /// In en, this message translates to:
  /// **'That picks up the color on top.'**
  String get tutorialTapBody;

  /// No description provided for @tutorialPourTitle.
  ///
  /// In en, this message translates to:
  /// **'Now tap the other glowing tube'**
  String get tutorialPourTitle;

  /// No description provided for @tutorialPourBody.
  ///
  /// In en, this message translates to:
  /// **'Colors pour onto the same color or into an empty tube.'**
  String get tutorialPourBody;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @tutorialGoal.
  ///
  /// In en, this message translates to:
  /// **'Sort every tube into one color'**
  String get tutorialGoal;

  /// No description provided for @tutorialStars.
  ///
  /// In en, this message translates to:
  /// **'Fewer moves earn more stars. If you\'re stuck:'**
  String get tutorialStars;

  /// No description provided for @tutorialUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo a pour'**
  String get tutorialUndo;

  /// No description provided for @tutorialHint.
  ///
  /// In en, this message translates to:
  /// **'Show a hint (costs a star)'**
  String get tutorialHint;

  /// No description provided for @tutorialAddTube.
  ///
  /// In en, this message translates to:
  /// **'Add an empty tube'**
  String get tutorialAddTube;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @levelsSolved.
  ///
  /// In en, this message translates to:
  /// **'Levels solved'**
  String get levelsSolved;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up: level {level}'**
  String nextUp(int level);

  /// No description provided for @stars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get stars;

  /// No description provided for @perfectLevels.
  ///
  /// In en, this message translates to:
  /// **'Perfect levels'**
  String get perfectLevels;

  /// No description provided for @perfectLevelsDetail.
  ///
  /// In en, this message translates to:
  /// **'Par moves, no hints'**
  String get perfectLevelsDetail;

  /// No description provided for @wins.
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get wins;

  /// No description provided for @winsDetail.
  ///
  /// In en, this message translates to:
  /// **'Replays included'**
  String get winsDetail;

  /// No description provided for @starsPerLevel.
  ///
  /// In en, this message translates to:
  /// **'Stars per level'**
  String get starsPerLevel;

  /// No description provided for @noStreak.
  ///
  /// In en, this message translates to:
  /// **'No streak yet'**
  String get noStreak;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak'**
  String streak(int days);

  /// No description provided for @streakStart.
  ///
  /// In en, this message translates to:
  /// **'Win a level today to start one.'**
  String get streakStart;

  /// No description provided for @streakDone.
  ///
  /// In en, this message translates to:
  /// **'Today\'s win is in. See you tomorrow.'**
  String get streakDone;

  /// No description provided for @streakKeep.
  ///
  /// In en, this message translates to:
  /// **'Win a level today to keep it going.'**
  String get streakKeep;

  /// No description provided for @statsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Solve a level to see how your stars stack up.'**
  String get statsEmpty;

  /// No description provided for @bestStage.
  ///
  /// In en, this message translates to:
  /// **'Best: stage {stage}'**
  String bestStage(int stage);

  /// No description provided for @notPlayed.
  ///
  /// In en, this message translates to:
  /// **'Not played yet'**
  String get notPlayed;

  /// No description provided for @playStage.
  ///
  /// In en, this message translates to:
  /// **'Play stage {stage}'**
  String playStage(int stage);

  /// No description provided for @modeMoves.
  ///
  /// In en, this message translates to:
  /// **'Move limit'**
  String get modeMoves;

  /// No description provided for @modeMovesBlurb.
  ///
  /// In en, this message translates to:
  /// **'Solve within the move limit. No undo.'**
  String get modeMovesBlurb;

  /// No description provided for @modeTimed.
  ///
  /// In en, this message translates to:
  /// **'Against the clock'**
  String get modeTimed;

  /// No description provided for @modeTimedBlurb.
  ///
  /// In en, this message translates to:
  /// **'Beat the timer. It starts on your first pour.'**
  String get modeTimedBlurb;

  /// No description provided for @levelShort.
  ///
  /// In en, this message translates to:
  /// **'Lvl {level}'**
  String levelShort(int level);

  /// No description provided for @chapterTitle.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number} · {name}'**
  String chapterTitle(int number, String name);

  /// No description provided for @chapterSolved.
  ///
  /// In en, this message translates to:
  /// **'{solved}/{total} solved'**
  String chapterSolved(int solved, int total);

  /// No description provided for @chapterDawn.
  ///
  /// In en, this message translates to:
  /// **'Dawn'**
  String get chapterDawn;

  /// No description provided for @chapterTide.
  ///
  /// In en, this message translates to:
  /// **'Tide'**
  String get chapterTide;

  /// No description provided for @chapterEmber.
  ///
  /// In en, this message translates to:
  /// **'Ember'**
  String get chapterEmber;

  /// No description provided for @chapterGrove.
  ///
  /// In en, this message translates to:
  /// **'Grove'**
  String get chapterGrove;

  /// No description provided for @chapterDusk.
  ///
  /// In en, this message translates to:
  /// **'Dusk'**
  String get chapterDusk;

  /// No description provided for @chapterAurora.
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get chapterAurora;

  /// No description provided for @dailyNew.
  ///
  /// In en, this message translates to:
  /// **'A new puzzle every day'**
  String get dailyNew;

  /// No description provided for @streakReminders.
  ///
  /// In en, this message translates to:
  /// **'Streak reminders'**
  String get streakReminders;

  /// No description provided for @streakRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A gentle nudge when today\'s daily isn\'t done'**
  String get streakRemindersSubtitle;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTime;

  /// No description provided for @notificationsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for Decant. Turn them on in system settings.'**
  String get notificationsBlocked;

  /// No description provided for @reminderStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your {days}-day streak going'**
  String reminderStreakTitle(int days);

  /// No description provided for @reminderStreakBody.
  ///
  /// In en, this message translates to:
  /// **'Today\'s daily puzzle is waiting.'**
  String get reminderStreakBody;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'A new daily puzzle is ready'**
  String get reminderTitle;

  /// No description provided for @reminderBody.
  ///
  /// In en, this message translates to:
  /// **'Take a calm minute and pour.'**
  String get reminderBody;

  /// No description provided for @reminderOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your streak?'**
  String get reminderOfferTitle;

  /// No description provided for @reminderOfferMessage.
  ///
  /// In en, this message translates to:
  /// **'Decant can send one gentle reminder at {time} on days you haven\'t solved the daily. You can change this in Settings.'**
  String reminderOfferMessage(String time);

  /// No description provided for @remindMe.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get remindMe;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @outOfHintsTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of hints'**
  String get outOfHintsTitle;

  /// No description provided for @watchForHintMessage.
  ///
  /// In en, this message translates to:
  /// **'Watch a short video for a hint now, or solve a level to earn one back.'**
  String get watchForHintMessage;

  /// No description provided for @watchVideo.
  ///
  /// In en, this message translates to:
  /// **'Watch video'**
  String get watchVideo;

  /// No description provided for @noVideoReady.
  ///
  /// In en, this message translates to:
  /// **'No video is ready right now. Try again in a moment.'**
  String get noVideoReady;

  /// No description provided for @videoNotFinished.
  ///
  /// In en, this message translates to:
  /// **'The video ended early, so no hint this time.'**
  String get videoNotFinished;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @adPrivacyChoices.
  ///
  /// In en, this message translates to:
  /// **'Ad privacy choices'**
  String get adPrivacyChoices;

  /// No description provided for @adPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change how ads use your data'**
  String get adPrivacySubtitle;

  /// No description provided for @levelTitle.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelTitle(int level);

  /// No description provided for @cloudSave.
  ///
  /// In en, this message translates to:
  /// **'Cloud save'**
  String get cloudSave;

  /// No description provided for @cloudSaveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your progress and pick it up on any device.'**
  String get cloudSaveSubtitle;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @cloudSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {account}'**
  String cloudSignedInAs(String account);

  /// No description provided for @cloudSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get cloudSyncing;

  /// No description provided for @cloudSynced.
  ///
  /// In en, this message translates to:
  /// **'Progress backed up'**
  String get cloudSynced;

  /// No description provided for @cloudSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the cloud. It\'ll try again.'**
  String get cloudSyncFailed;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signedOutNotice.
  ///
  /// In en, this message translates to:
  /// **'Signed out. Your progress stays on this phone.'**
  String get signedOutNotice;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in. Check your connection and try again.'**
  String get signInFailed;

  /// No description provided for @deleteCloudSave.
  ///
  /// In en, this message translates to:
  /// **'Delete cloud save'**
  String get deleteCloudSave;

  /// No description provided for @deleteCloudSaveMessage.
  ///
  /// In en, this message translates to:
  /// **'This deletes your saved progress from the cloud and your Decant account. Progress on this phone stays.'**
  String get deleteCloudSaveMessage;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cloudDeleted.
  ///
  /// In en, this message translates to:
  /// **'Cloud save deleted.'**
  String get cloudDeleted;

  /// No description provided for @cloudDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete it. Check your connection and try again.'**
  String get cloudDeleteFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
