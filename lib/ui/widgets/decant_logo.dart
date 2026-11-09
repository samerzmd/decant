import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Decant mark: a glass test tube holding three sorted liquid layers
/// (ruby, amber, teal) with a teal droplet falling in.
///
/// The launcher icon, adaptive icon and splash images are rendered from this
/// same painter by `tool/render_branding_test.dart`, so the in-app logo and
/// the OS branding never drift apart.
class DecantLogo extends StatelessWidget {
  final double size;
  const DecantLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * DecantMarkPainter.aspect,
      child: const CustomPaint(painter: DecantMarkPainter()),
    );
  }
}

/// Paints the mark into a box of width w and height w * [aspect].
class DecantMarkPainter extends CustomPainter {
  /// Height / width of the mark's box.
  static const double aspect = 1.25;

  static const _ruby = Color(0xFFE2425B);
  static const _amber = Color(0xFFF2913D);
  static const _teal = DecantColors.accent;

  /// Soft teal light behind the tube. Off for the adaptive/splash images,
  /// where the launcher supplies its own background.
  final bool glow;

  /// Flat white silhouette for Android 13+ themed (monochrome) icons.
  final bool monochrome;

  const DecantMarkPainter({this.glow = true, this.monochrome = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final stroke = w * 0.05;

    // ---- Tube geometry: flat top with a lip, fully rounded base ----
    final tubeW = w * 0.46;
    final tubeTop = h * 0.40;
    final tubeBottom = h * 0.975 - stroke / 2;
    final left = cx - tubeW / 2;
    final right = cx + tubeW / 2;
    final tube = RRect.fromRectAndCorners(
      Rect.fromLTRB(left, tubeTop, right, tubeBottom),
      topLeft: Radius.circular(tubeW * 0.06),
      topRight: Radius.circular(tubeW * 0.06),
      bottomLeft: Radius.circular(tubeW / 2),
      bottomRight: Radius.circular(tubeW / 2),
    );

    if (glow && !monochrome) {
      final c = Offset(cx, (tubeTop + tubeBottom) / 2);
      final r = tubeW * 1.45;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            _teal.withValues(alpha: 0.30),
            _teal.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // ---- Glass + liquid layers, clipped to the tube ----
    canvas.save();
    canvas.clipRRect(tube);
    if (!monochrome) {
      canvas.drawRRect(tube, Paint()..color = Colors.white.withValues(alpha: 0.10));
    }

    final innerTop = tubeTop + stroke / 2;
    final liquidTop = innerTop + (tubeBottom - innerTop) * 0.20;
    // The rounded base holds less, so the bottom band is taller to read as
    // an equal share.
    final liquidH = tubeBottom - liquidTop;
    const layers = [_teal, _amber, _ruby];
    const stops = [0.0, 0.29, 0.58, 1.0];
    for (var i = 0; i < 3; i++) {
      final top = liquidTop + liquidH * stops[i];
      final bottom = liquidTop + liquidH * stops[i + 1];
      // Each band overlaps the next a hair so no seam shows when scaled.
      // In the flat silhouette, small gaps keep the layers readable instead.
      final rect = Rect.fromLTRB(left, top, right,
          i == 2 ? bottom : (monochrome ? bottom - stroke * 0.45 : bottom + 0.5));
      final paint = Paint();
      if (monochrome) {
        paint.color = Colors.white;
      } else {
        paint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(layers[i], Colors.white, 0.10)!,
            Color.lerp(layers[i], Colors.black, 0.10)!,
          ],
        ).createShader(rect);
      }
      canvas.drawRect(rect, paint);
    }

    if (!monochrome) {
      // Meniscus on the top (teal) layer.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, liquidTop), width: tubeW, height: tubeW * 0.26),
        Paint()..color = Color.lerp(_teal, Colors.white, 0.45)!,
      );
      // Glass reflection down the left side.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + tubeW * 0.17, innerTop + tubeW * 0.30, tubeW * 0.11,
              (tubeBottom - innerTop) * 0.58),
          Radius.circular(tubeW * 0.06),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.30),
      );
    }
    canvas.restore();

    // ---- Glass outline + lip ----
    canvas.drawRRect(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
    final lipW = tubeW + stroke * 2.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, tubeTop), width: lipW, height: stroke * 1.5),
        Radius.circular(stroke * 0.75),
      ),
      Paint()..color = Colors.white,
    );

    // ---- Teal droplet falling in ----
    final r = w * 0.105;
    final cyD = h * 0.235;
    final tipY = h * 0.035;
    final reach = cyD - tipY;
    final drop = Path()
      ..moveTo(cx, tipY)
      ..cubicTo(cx + r * 0.25, tipY + reach * 0.35, cx + r, cyD - r * 0.75, cx + r, cyD)
      ..arcToPoint(Offset(cx - r, cyD), radius: Radius.circular(r))
      ..cubicTo(cx - r, cyD - r * 0.75, cx - r * 0.25, tipY + reach * 0.35, cx, tipY)
      ..close();
    final dropBounds = Rect.fromLTRB(cx - r, tipY, cx + r, cyD + r);
    final dropPaint = Paint();
    if (monochrome) {
      dropPaint.color = Colors.white;
    } else {
      dropPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(_teal, Colors.white, 0.25)!,
          Color.lerp(_teal, Colors.black, 0.08)!,
        ],
      ).createShader(dropBounds);
    }
    canvas.drawPath(drop, dropPaint);
    if (!monochrome) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - r * 0.38, cyD - r * 0.18), width: r * 0.34, height: r * 0.52),
        Paint()..color = Colors.white.withValues(alpha: 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DecantMarkPainter oldDelegate) =>
      oldDelegate.glow != glow || oldDelegate.monochrome != monochrome;
}
