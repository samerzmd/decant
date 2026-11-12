import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:decant/models/liquid_palette.dart';
import 'package:decant/ui/theme/app_theme.dart';

/// WCAG relative luminance contrast between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  tearDown(() => activeUiTheme = UiTheme.twilight);

  test('only Daylight is a light theme', () {
    expect([
      for (final t in UiTheme.values)
        if (t.isLight) t
    ], [
      UiTheme.daylight
    ]);
    expect(UiTheme.fromName('daylight'), UiTheme.daylight);
  });

  test('tokens follow the active theme', () {
    activeUiTheme = UiTheme.twilight;
    final dark = DecantColors.onSurface;
    activeUiTheme = UiTheme.daylight;
    expect(DecantColors.onSurface, isNot(dark));
    expect(DecantColors.onSurface.computeLuminance(), lessThan(0.1));
    expect(buildDecantTheme().brightness, Brightness.light);
    expect(decantOverlayStyle().statusBarIconBrightness, Brightness.dark);
  });

  for (final t in UiTheme.values) {
    test('${t.name}: text keeps WCAG contrast on every background stop', () {
      activeUiTheme = t;
      for (final bg in t.colors) {
        expect(_contrast(DecantColors.onSurface, bg), greaterThan(7),
            reason: 'onSurface');
        expect(_contrast(DecantColors.subtle, bg), greaterThan(4.5),
            reason: 'subtle');
        expect(_contrast(DecantColors.accent, bg), greaterThan(4.5),
            reason: 'accent');
        expect(_contrast(DecantColors.star, bg), greaterThan(3),
            reason: 'star');
      }
      expect(_contrast(DecantColors.onAccent, DecantColors.accent),
          greaterThan(4.5),
          reason: 'onAccent');
      for (final p in DecantColors.panel) {
        expect(_contrast(DecantColors.onSurface, p), greaterThan(7),
            reason: 'panel');
      }
    });
  }

  testWidgets('switching theme rebuilds widgets that read tokens directly',
      (tester) async {
    Widget app(UiTheme t) => UiThemeScope(
          theme: t,
          builder: (_) => const Directionality(
            textDirection: TextDirection.ltr,
            // A const child is not rebuilt by its parent; only the scope's
            // switch can repaint it.
            child: _Swatch(),
          ),
        );
    await tester.pumpWidget(app(UiTheme.twilight));
    expect(_color(tester), DecantColors.onSurface);
    final dark = _color(tester);

    await tester.pumpWidget(app(UiTheme.daylight));
    await tester.pump();
    expect(activeUiTheme, UiTheme.daylight);
    expect(_color(tester), isNot(dark));
    expect(_color(tester), DecantColors.onSurface);
  });
}

Color? _color(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byType(ColoredBox)).color;

class _Swatch extends StatelessWidget {
  const _Swatch();
  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: DecantColors.onSurface);
}
