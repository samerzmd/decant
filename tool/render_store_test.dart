// Renders the Google Play feature graphic (1024×500) from the in-app
// DecantMarkPainter, so store art matches the app and its icon.
//
//   fvm flutter test tool/render_store_test.dart
//   sips -s format jpeg store/feature_graphic.png --out store/feature_graphic.jpg
//
// Play wants the graphic without transparency, hence the JPEG step.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:decant/ui/theme/app_theme.dart';
import 'package:decant/ui/widgets/decant_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 1024.0;
const _h = 500.0;

/// Tests draw text in a placeholder font, so load Roboto (the app's Android
/// font) from the Flutter SDK cache that this test is running from.
Future<void> _loadRoboto() async {
  final exe = Platform.resolvedExecutable;
  final cache = exe.substring(0, exe.indexOf('bin/cache') + 'bin/cache'.length);
  final dir = '$cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final f in ['Roboto-Regular', 'Roboto-Medium', 'Roboto-Black']) {
    final bytes = File('$dir/$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void _text(Canvas canvas, String text, Offset at, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style.copyWith(fontFamily: 'Roboto')),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, at);
}

void main() {
  testWidgets('render store art', (tester) async {
    await tester.runAsync(() async {
      await _loadRoboto();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const full = Rect.fromLTWH(0, 0, _w, _h);

      // Twilight background, matching the app and the launcher icon.
      canvas.drawRect(
        full,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DecantColors.bgTop,
              DecantColors.bgMid,
              DecantColors.bgBottom,
            ],
          ).createShader(full),
      );

      void mark(double cx, double cy, double height, {bool glow = true}) {
        final w = height / DecantMarkPainter.aspect;
        canvas.save();
        canvas.translate(cx - w / 2, cy - height / 2);
        DecantMarkPainter(glow: glow).paint(canvas, Size(w, height));
        canvas.restore();
      }

      // Two faint marks behind the hero one, for depth.
      canvas.saveLayer(full, Paint()..color = const Color(0x40FFFFFF));
      mark(650, 300, 210, glow: false);
      mark(960, 230, 240, glow: false);
      canvas.restore();
      mark(805, 255, 380);

      // Wordmark and tagline.
      _text(
        canvas,
        'Decant',
        const Offset(72, 128),
        const TextStyle(
          fontSize: 112,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: DecantColors.onSurface,
        ),
      );
      _text(
        canvas,
        'Pour. Sort. Unwind.',
        const Offset(78, 272),
        const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w500,
          letterSpacing: 4,
          color: DecantColors.accent,
        ),
      );
      _text(
        canvas,
        'A calm water-sort puzzle',
        const Offset(78, 330),
        const TextStyle(fontSize: 26, color: DecantColors.subtle),
      );

      final image =
          await recorder.endRecording().toImage(_w.toInt(), _h.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('store').createSync(recursive: true);
      File('store/feature_graphic.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
