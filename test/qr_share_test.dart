import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/l10n/app_localizations.dart';
import 'package:decant/logic/custom_level.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/audio/audio_service.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/level_editor_screen.dart';
import 'package:decant/ui/screens/qr_scan_screen.dart';

const _tubes = [
  [0, 1, 2, 0],
  [1, 2, 0, 1],
  [2, 0, 1, 2],
];

void main() {
  group('scanned QR values', () {
    final code = CustomLevel.encode(_tubes);

    test('the first Decant level wins; other codes are skipped', () {
      expect(QrScanScreen.levelIn([null, 'https://example.com', code]), _tubes);
      expect(QrScanScreen.levelIn(['Try my puzzle:\n$code']), _tubes);
    });

    test('nothing usable gives null', () {
      expect(QrScanScreen.levelIn([]), isNull);
      expect(QrScanScreen.levelIn([null, 'hello', 'DCT1-!!!']), isNull);
    });
  });

  testWidgets('sharing shows the QR, and text goes out only on request', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final persistence = await PersistenceService.create();
    final shared = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          persistenceProvider.overrideWithValue(persistence),
          audioServiceProvider.overrideWithValue(AudioService()),
          shareProvider.overrideWithValue((text, _) async => shared.add(text)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LevelEditorScreen(initial: _tubes),
        ),
      ),
    );
    await tester.pump();

    final share = find.text('Share code');
    await tester.ensureVisible(share);
    await tester.tap(share);
    // The solvability check runs in an isolate.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();

    final code = CustomLevel.encode(_tubes);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(code), findsOneWidget);
    expect(shared, isEmpty);

    await tester.tap(find.byKey(const ValueKey('send-code-text')));
    await tester.pumpAndSettle();
    expect(shared, hasLength(1));
    expect(CustomLevel.decode(shared.single), _tubes);
  });

  testWidgets('the code dialog offers a QR scan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final persistence = await PersistenceService.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          persistenceProvider.overrideWithValue(persistence),
          audioServiceProvider.overrideWithValue(AudioService()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LevelEditorScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Enter a code'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scan-qr')), findsOneWidget);
    expect(find.text('Scan a QR code'), findsOneWidget);
  });
}
