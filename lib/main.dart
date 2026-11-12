import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/audio_service.dart';
import 'firebase_options.dart';
import 'l10n/l10n.dart';
import 'logic/streak_reminder.dart';
import 'models/app_settings.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/persistence_service.dart';
import 'services/reminder_service.dart';
import 'state/providers.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/app_theme.dart';
import 'services/log.dart';
import 'ui/theme/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final analytics = AnalyticsService();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Persistence is quick (SharedPreferences) and needed for first build.
  final persistence = await PersistenceService.create();

  // Audio loads 12 assets (engine + the long ambient loops). Loading runs on
  // the root isolate, so doing it before the first frame blocks the UI for
  // seconds. Defer it to AFTER the first frame is rendered; every audio call is
  // a no-op until ready, and the ambient bed auto-starts once loading finishes.
  final audio = AudioService();
  final reminders = ReminderService();
  final ads = AdService();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    audio.init();
  });

  runApp(
    ProviderScope(
      overrides: [
        persistenceProvider.overrideWithValue(persistence),
        audioServiceProvider.overrideWithValue(audio),
        analyticsServiceProvider.overrideWithValue(analytics),
        reminderServiceProvider.overrideWithValue(reminders),
        adServiceProvider.overrideWithValue(ads),
      ],
      child: const DecantApp(),
    ),
  );
}

class DecantApp extends ConsumerStatefulWidget {
  const DecantApp({super.key});

  @override
  ConsumerState<DecantApp> createState() => _DecantAppState();
}

class _DecantAppState extends ConsumerState<DecantApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reminders load the timezone database, so start them after the first
    // frame, then plan the next one.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(reminderServiceProvider).init();
      if (mounted) _syncReminder();
      // Asks for ad consent where it's needed, then loads a video in the
      // background for the "watch for a hint" offer.
      await ref.read(adServiceProvider).init();
    });
  }

  /// Plans the next streak reminder from the current progress and settings,
  /// or clears it when reminders are off.
  void _syncReminder() {
    final settings = ref.read(settingsProvider);
    final reminders = ref.read(reminderServiceProvider);
    if (!settings.streakReminders) {
      reminders.cancel();
      return;
    }
    final plan = planReminder(
      now: ref.read(progressProvider.notifier).now(),
      hour: settings.reminderHour,
      daily: ref.read(progressProvider).daily,
    );
    reminders.schedule(plan, _strings(settings.language));
  }

  /// Strings for notifications, which are built outside any widget.
  static AppLocalizations _strings(AppLanguage language) {
    final code = language.code ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final known =
        AppLocalizations.supportedLocales.any((l) => l.languageCode == code);
    return lookupAppLocalizations(Locale(known ? code : 'en'));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Log.d('Lifecycle', '$state');
    final audio = ref.read(audioServiceProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        audio.handleAppResumed();
        // A new day may have started while away.
        _syncReminder();
      case AppLifecycleState.detached:
        // Activity being destroyed — fully release the audio engine so that if
        // the process is reused (Android recreates the Activity), a fresh init
        // works instead of wedging on the stale native engine.
        audio.handleAppDetached();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Not in the foreground → silence everything.
        audio.handleAppPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Painters read the liquid palette directly, so set it before building.
    final settings = ref.watch(settingsProvider);
    ref.listen(settingsProvider, (_, __) => _syncReminder());
    ref.listen(progressProvider, (_, __) => _syncReminder());
    activeLiquidPalette = settings.liquidPalette;
    return UiThemeScope(
      theme: settings.uiTheme,
      builder: (_) => _buildApp(settings),
    );
  }

  Widget _buildApp(AppSettings settings) {
    return MaterialApp(
      title: 'Decant',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [ref.read(analyticsServiceProvider).observer],
      theme: buildDecantTheme(),
      locale: settings.language.code == null
          ? null
          : Locale(settings.language.code!),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // A brief splash that mirrors the native splash (same logo + background)
      // so the brand mark is reliably visible before Home.
      home: const SplashScreen(),
    );
  }
}
