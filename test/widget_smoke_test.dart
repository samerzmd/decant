import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/home_screen.dart';

void main() {
  testWidgets('Home screen renders brand, tagline and play button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final persistence = await PersistenceService.create();
    // AudioService is left uninitialized; all its calls become safe no-ops.
    final audio = AudioService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          persistenceProvider.overrideWithValue(persistence),
          audioServiceProvider.overrideWithValue(audio),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Decant'), findsOneWidget);
    expect(find.text('Pour. Sort. Unwind.'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Levels'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Stats'), findsOneWidget);
    expect(find.text('Daily challenge'), findsOneWidget);
  });
}
