import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:decant/ui/painters/liquid_geometry.dart';

void main() {
  const rect = Rect.fromLTWH(4, 2, 52, 170);

  test('upright tubes fill in flat bands, as before', () {
    for (final f in [0.25, 0.5, 0.75]) {
      final level = LiquidGeometry.levelFor(rect, 0, f);
      expect(level, closeTo(rect.bottom - f * rect.height, 0.01));
    }
  });

  test('tilting keeps the volume of liquid the same', () {
    for (final tilt in [0.3, 0.9, -1.2, 1.5]) {
      for (final f in [0.1, 0.4, 0.8]) {
        final level = LiquidGeometry.levelFor(rect, tilt, f);
        final below = LiquidGeometry.band(rect, tilt, level, double.infinity);
        expect(
          LiquidGeometry.area(below) / (rect.width * rect.height),
          closeTo(f, 1e-4),
        );
      }
    }
  });

  test('a fuller tube pours with less tilt, mirrored for the other side', () {
    expect(LiquidGeometry.pourTilt(rect, 1, 1), 0);
    var last = 0.0;
    for (final f in [0.9, 0.7, 0.5, 0.3, 0.1]) {
      final t = LiquidGeometry.pourTilt(rect, f, 1);
      expect(t, greaterThan(last));
      expect(LiquidGeometry.pourTilt(rect, f, -1), closeTo(-t, 1e-9));
      last = t;
    }
    expect(last, lessThan(math.pi / 2 + 0.05));
  });

  test('at the pour tilt the surface passes through the lip', () {
    const f = 0.4;
    final tilt = LiquidGeometry.pourTilt(rect, f, 1);
    final level = LiquidGeometry.levelFor(rect, tilt, f);
    expect(
      LiquidGeometry.depth(rect.topRight, tilt),
      closeTo(level, 0.05),
    );
  });
}
