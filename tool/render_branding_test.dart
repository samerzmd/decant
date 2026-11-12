// Renders the brand images in branding/ from the in-app DecantMarkPainter, so
// the launcher icon, adaptive icon and splash always match the in-app logo.
//
//   fvm flutter test tool/render_branding_test.dart
//   fvm dart run flutter_launcher_icons
//   fvm dart run flutter_native_splash:create
//
// Outputs (1024×1024 PNG):
//   decant_icon.png        twilight gradient + mark   (iOS / legacy launcher icon)
//   decant_foreground.png  transparent mark, adaptive-icon safe zone
//   decant_monochrome.png  white silhouette, Android 13+ themed icons
//   decant_splash.png      transparent mark            (native splash)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:decant/ui/theme/app_theme.dart';
import 'package:decant/ui/widgets/decant_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

Future<void> _render(
  String name, {
  required double markHeight,
  bool background = false,
  bool glow = false,
  bool monochrome = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const full = Rect.fromLTWH(0, 0, _size, _size);

  if (background) {
    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DecantColors.bgTop,
            DecantColors.bgMid,
            DecantColors.bgBottom
          ],
        ).createShader(full),
    );
  }

  final h = _size * markHeight;
  final w = h / DecantMarkPainter.aspect;
  canvas.translate((_size - w) / 2, (_size - h) / 2);
  DecantMarkPainter(glow: glow, monochrome: monochrome)
      .paint(canvas, Size(w, h));

  final image =
      await recorder.endRecording().toImage(_size.toInt(), _size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File('branding/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('render branding images', (tester) async {
    await tester.runAsync(() async {
      // Full-bleed icon: the OS masks it, so the mark can be large.
      await _render('decant_icon.png',
          markHeight: 0.74, background: true, glow: true);
      // Adaptive layers: flutter_launcher_icons insets these by 16%, which
      // already matches the visible area, so the mark can fill most of it.
      await _render('decant_foreground.png', markHeight: 0.84);
      await _render('decant_monochrome.png',
          markHeight: 0.84, monochrome: true);
      // Splash (incl. the Android 12 icon, masked to the middle 2/3 circle).
      await _render('decant_splash.png', markHeight: 0.56);
    });
  });
}
