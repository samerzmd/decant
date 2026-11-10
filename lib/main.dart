import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/audio_service.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'services/persistence_service.dart';
import 'state/providers.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/app_theme.dart';
import 'services/log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final analytics = AnalyticsService();

  // Portrait-only for a calm, focused layout.
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );
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
  WidgetsBinding.instance.addPostFrameCallback((_) {
    audio.init();
  });

  runApp(
    ProviderScope(
      overrides: [
        persistenceProvider.overrideWithValue(persistence),
        audioServiceProvider.overrideWithValue(audio),
        analyticsServiceProvider.overrideWithValue(analytics),
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
    return MaterialApp(
      title: 'Decant',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [ref.read(analyticsServiceProvider).observer],
      theme: buildDecantTheme(),
      // A brief splash that mirrors the native splash (same logo + background)
      // so the brand mark is reliably visible before Home.
      home: const SplashScreen(),
    );
  }
}
