import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/models/liquid_palette.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/settings_screen.dart';
import 'package:decant/ui/theme/palette.dart';

void main() {
  tearDown(() => activeLiquidPalette = LiquidPalette.standard);

  test('every palette has 12 distinct colors', () {
    for (final p in LiquidPalette.values) {
      expect(p.colors.length, 12, reason: p.name);
      expect(p.colors.toSet().length, 12, reason: p.name);
    }
  });

  test('the palette survives a save; unknown names fall back', () {
    const s = AppSettings(liquidPalette: LiquidPalette.highContrast);
    expect(
      AppSettings.fromJson(s.toJson()).liquidPalette,
      LiquidPalette.highContrast,
    );
    expect(AppSettings.fromJson({}).liquidPalette, LiquidPalette.standard);
    expect(
      AppSettings.fromJson({'liquidPalette': 'neon'}).liquidPalette,
      LiquidPalette.standard,
    );
  });

  test('the UI theme survives a save; unknown names fall back', () {
    const s = AppSettings(uiTheme: UiTheme.midnight);
    expect(AppSettings.fromJson(s.toJson()).uiTheme, UiTheme.midnight);
    expect(AppSettings.fromJson({}).uiTheme, UiTheme.twilight);
    expect(AppSettings.fromJson({'uiTheme': 'neon'}).uiTheme, UiTheme.twilight);
    for (final t in UiTheme.values) {
      expect(t.colors.length, 3, reason: t.name);
    }
  });

  test('liquid colors follow the active palette', () {
    expect(liquidColor(0), LiquidPalette.standard.colors[0]);
    activeLiquidPalette = LiquidPalette.colorblindSafe;
    expect(liquidColor(0), LiquidPalette.colorblindSafe.colors[0]);
    expect(liquidColor(13), LiquidPalette.colorblindSafe.colors[1]);
  });

  testWidgets('Settings picks the liquid colors', (tester) async {
    tester.view.physicalSize = const Size(1440, 3088);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final persistence = await PersistenceService.create();
    final c = ProviderContainer(
      overrides: [
        persistenceProvider.overrideWithValue(persistence),
        audioServiceProvider.overrideWithValue(AudioService()),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Colorblind-safe'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Colorblind-safe'));
    await tester.pump();
    await tester.tap(find.text('Colorblind-safe'));
    await tester.pump();
    expect(
      c.read(settingsProvider).liquidPalette,
      LiquidPalette.colorblindSafe,
    );
    expect(
      persistence.loadSettings().liquidPalette,
      LiquidPalette.colorblindSafe,
    );
  });
}
