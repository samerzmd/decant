// Golden images of the tube and stream painters, so a change to how glass,
// liquid or the pour is drawn shows up as a reviewable image diff.
//
// After an intended visual change, refresh them with:
//   fvm flutter test --update-goldens test/painter_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:decant/models/tube.dart';
import 'package:decant/ui/painters/pour_stream_painter.dart';
import 'package:decant/ui/widgets/tube_widget.dart';

const _bg = Color(0xFF1E2440);
const _w = 60.0;
const _h = 180.0;

Widget _tube(
  List<int> segments, {
  double tilt = 0,
  int drainCount = 0,
  double drainProgress = 0,
  int? drainColor,
  int risingCount = 0,
  double risingProgress = 1,
  int? risingColor,
  double agitation = 0,
  bool colorblind = false,
  bool selected = false,
}) {
  return SizedBox(
    // A tipped tube pivots on its top-right corner and swings left, so it
    // gets a wider cell with the pivot near the right edge.
    width: tilt > 0 ? 230 : 110,
    height: 250,
    child: Align(
      alignment: tilt > 0 ? const Alignment(0.85, 1) : Alignment.center,
      child: TubeWidget(
        tube: Tube(capacity: 4, segments: segments),
        width: _w,
        height: _h,
        time: 1.25,
        colorblind: colorblind,
        selected: selected,
        tilt: tilt,
        pivot: tilt > 0 ? Alignment.topRight : Alignment.topCenter,
        drainCount: drainCount,
        drainProgress: drainProgress,
        drainColor: drainColor,
        risingCount: risingCount,
        risingProgress: risingProgress,
        risingColor: risingColor,
        agitation: agitation,
        onTap: () {},
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget child, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        child: ColoredBox(color: _bg, child: Center(child: child)),
      ),
    ),
  );
}

void main() {
  testWidgets('tubes: upright, colorblind, draining tilted, filling', (
    tester,
  ) async {
    await _pump(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tube([0, 1, 2]),
          _tube([3, 3, 4, 5], colorblind: true),
          _tube(
            [1, 2],
            tilt: 1.0,
            drainCount: 2,
            drainProgress: 0.4,
            drainColor: 4,
          ),
          // The two poured segments are already in the tube; half have landed.
          _tube(
            [5, 2, 0, 0],
            risingCount: 2,
            risingProgress: 0.5,
            risingColor: 0,
            agitation: 1,
          ),
          _tube([], selected: true),
        ],
      ),
      const Size(720, 270),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/tubes.png'),
    );
  });

  testWidgets('pour stream: falling jet and splash', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: 260,
        height: 260,
        child: CustomPaint(
          painter: PourStreamPainter(
            spout: const Offset(70, 40),
            impact: const Offset(170, 220),
            side: 1,
            colorId: 2,
            head: 1,
            tail: 0,
            flow: 0.9,
            time: 0.7,
            scale: _w,
          ),
        ),
      ),
      const Size(280, 280),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/pour_stream.png'),
    );
  });
}
