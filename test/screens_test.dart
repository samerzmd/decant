// Widget tests for the screens players move between: settings, level select,
// the leave-level confirmation, the win overlay and the sound browser.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/logic/solver.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/services/analytics_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/game_session.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/game_screen.dart';
import 'package:decant/ui/screens/level_select_screen.dart';
import 'package:decant/ui/screens/settings_screen.dart';
import 'package:decant/ui/screens/sound_browser_screen.dart';
import 'package:decant/ui/widgets/tube_widget.dart';
import 'package:decant/ui/widgets/win_overlay.dart';

class _QuietAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A phone-sized app showing [home], with fresh storage prepared by [seed].
Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget home, {
  Future<void> Function(PersistenceService p)? seed,
}) async {
  tester.view.physicalSize = const Size(1440, 3088);
  tester.view.devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final persistence = await PersistenceService.create();
  await persistence.saveSettings(const AppSettings(tutorialSeen: true));
  if (seed != null) await seed(persistence);
  final container = ProviderContainer(
    overrides: [
      persistenceProvider.overrideWithValue(persistence),
      audioServiceProvider.overrideWithValue(AudioService()),
      analyticsServiceProvider.overrideWithValue(_QuietAnalytics()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pump();
  return container;
}

/// The switch on the settings row labelled [label].
Finder _switchFor(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );

/// Scrolls the settings list until [text] has been built and is on screen.
Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  // Fully on screen, not just at the edge, so taps land.
  await tester.ensureVisible(find.text(text));
  await tester.pump();
}

/// Lets a route transition finish (the board animates forever, so
/// pumpAndSettle would never return).
Future<void> _settleRoute(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Plays [levelId]'s solver solution until it's won.
Future<void> _solve(
  WidgetTester tester,
  ProviderContainer container,
  int levelId,
) async {
  for (var guard = 0; guard < 200; guard++) {
    final session = container.read(gameControllerProvider(levelId));
    if (session.status == GameStatus.won) return;
    final move = Solver.nextMove(session.state)!;
    final tubes = find.byType(TubeWidget);
    await tester.tap(tubes.at(move.from), warnIfMissed: false);
    await tester.pump();
    await tester.tap(tubes.at(move.to), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100)); // whole pour
  }
  fail('level $levelId was not solved');
}

void main() {
  group('settings', () {
    testWidgets('switches change and persist settings', (tester) async {
      final c = await _pump(tester, const SettingsScreen());
      final persistence = c.read(persistenceProvider);

      for (final label in ['Colorblind symbols', 'Reduce motion']) {
        await _scrollTo(tester, label);
        await tester.tap(_switchFor(label));
        await tester.pump();
      }
      final s = c.read(settingsProvider);
      expect(s.colorblindMode, isTrue);
      expect(s.reduceMotion, isTrue);
      expect(persistence.loadSettings().colorblindMode, isTrue);

      // And back off again.
      await tester.tap(_switchFor('Reduce motion'));
      await tester.pump();
      expect(c.read(settingsProvider).reduceMotion, isFalse);
    });

    testWidgets('pour speed chips pick the speed', (tester) async {
      final c = await _pump(tester, const SettingsScreen());
      await _scrollTo(tester, 'Quick');
      await tester.tap(find.text('Quick'));
      await tester.pump();
      expect(c.read(settingsProvider).pourSpeed, PourSpeed.quick);
      await tester.tap(find.text('Relaxed'));
      await tester.pump();
      expect(c.read(settingsProvider).pourSpeed, PourSpeed.relaxed);
    });

    testWidgets('muting turns the whole mix off', (tester) async {
      final c = await _pump(tester, const SettingsScreen());
      await tester.tap(_switchFor('Mute all'));
      await tester.pump();
      expect(c.read(settingsProvider).audio.muted, isTrue);
    });
  });

  group('level select', () {
    testWidgets('shows stars, locks unplayed levels and opens a level', (
      tester,
    ) async {
      await _pump(
        tester,
        const LevelSelectScreen(),
        // Two levels solved with 3 stars: header shows 6, level 3 unlocked.
        seed: (p) async {
          await p.recordResult(1, 3, 12);
          await p.recordResult(2, 3, 15);
        },
      );

      expect(find.text('6'), findsOneWidget); // star total
      for (final n in ['1', '2', '3']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text('4'), findsNothing); // locked
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(6 + 1)); // + header

      await tester.tap(find.text('3'));
      await _settleRoute(tester);
      expect(tester.widget<GameScreen>(find.byType(GameScreen)).levelId, 3);
    });

    testWidgets('locked levels do nothing when tapped', (tester) async {
      await _pump(tester, const LevelSelectScreen());
      await tester.tap(find.byIcon(Icons.lock_rounded).first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GameScreen), findsNothing);
    });
  });

  group('game', () {
    testWidgets('leaving mid-level asks first', (tester) async {
      final c = await _pump(tester, const _Launcher());
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Make one move, so there is progress to lose.
      final session = c.read(gameControllerProvider(1));
      final move = Solver.nextMove(session.state)!;
      await tester.tap(find.byType(TubeWidget).at(move.from));
      await tester.pump();
      await tester.tap(find.byType(TubeWidget).at(move.to));
      await tester.pump(const Duration(milliseconds: 1100));

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leave this level?'), findsOneWidget);

      await tester.tap(find.text('Keep playing'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GameScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Leave'));
      await _settleRoute(tester);
      expect(find.byType(GameScreen), findsNothing);
    });

    testWidgets('winning shows the result and moves on', (tester) async {
      final c = await _pump(tester, const GameScreen(levelId: 1));
      await _solve(tester, c, 1);
      await tester.pump(const Duration(seconds: 2)); // star animation

      expect(find.byType(WinOverlay), findsOneWidget);
      expect(find.text('Level 1 solved'), findsOneWidget);
      final moves = c.read(gameControllerProvider(1)).moves;
      expect(
        find.descendant(
          of: find.byType(WinOverlay),
          matching: find.text('$moves ${moves == 1 ? 'move' : 'moves'}'),
        ),
        findsOneWidget,
      );
      expect(c.read(progressProvider).resultFor(1), isNotNull);

      await tester.tap(find.text('Next level'));
      await _settleRoute(tester);
      expect(tester.widget<GameScreen>(find.byType(GameScreen)).levelId, 2);
    });
  });

  testWidgets('sound browser lists the ambience tracks', (tester) async {
    await _pump(tester, const SoundBrowserScreen(kind: SoundKind.ambient));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SoundBrowserScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// A home with one button that opens level 1, so the game screen has a
/// route underneath it to go back to.
class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GameScreen(levelId: 1)),
            ),
            child: const Text('open'),
          ),
        ),
      );
}
