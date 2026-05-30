import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Decant mark: a glowing glass test tube with a luminous teal liquid level
/// and meniscus, topped by a polished droplet. Mirrors the launcher icon so the
/// in-app and OS branding stay consistent.
class DecantLogo extends StatelessWidget {
  final double size;
  const DecantLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.25,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  static const _accent = DecantColors.accent;
  static const _accentDeep = DecantColors.accentDeep;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final stroke = w * 0.038;

    // Tube geometry (flat shoulders, rounded base).
    final tubeW = w * 0.42;
    final tubeTop = h * 0.42;
    final tubeBottom = h * 0.965;
    final left = cx - tubeW / 2;
    final right = cx + tubeW / 2;
    final tube = RRect.fromRectAndCorners(
      Rect.fromLTRB(left, tubeTop, right, tubeBottom),
      topLeft: Radius.circular(tubeW * 0.08),
      topRight: Radius.circular(tubeW * 0.08),
      bottomLeft: Radius.circular(tubeW * 0.48),
      bottomRight: Radius.circular(tubeW * 0.48),
    );

    // ---- Soft teal halo behind the tube ----
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, (tubeTop + tubeBottom) / 2),
          width: tubeW * 2.4,
          height: (tubeBottom - tubeTop) * 1.5),
      Paint()
        ..color = _accent.withOpacity(0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.10),
    );

    // ---- Glass body (translucent) ----
    canvas.drawRRect(tube, Paint()..color = Colors.white.withOpacity(0.10));

    // ---- Liquid + meniscus, clipped to the tube ----
    canvas.save();
    canvas.clipRRect(tube);
    final liquidTop = tubeTop + (tubeBottom - tubeTop) * 0.40;
    final liquidRect = Rect.fromLTRB(left, liquidTop, right, tubeBottom);
    canvas.drawRect(
      liquidRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(_accent, Colors.white, 0.12)!, _accentDeep],
        ).createShader(liquidRect),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, liquidTop), width: tubeW, height: tubeW * 0.34),
      Paint()..color = Color.lerp(_accent, Colors.white, 0.55)!.withOpacity(0.92),
    );
    // glossy vertical reflection on the liquid
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + tubeW * 0.20, liquidTop + tubeW * 0.18,
            tubeW * 0.12, (tubeBottom - liquidTop) * 0.55),
        Radius.circular(tubeW * 0.06),
      ),
      Paint()..color = Colors.white.withOpacity(0.22),
    );
    canvas.restore();

    // ---- Glass outline + mouth rim ----
    canvas.drawRRect(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.95),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, tubeTop), width: tubeW, height: tubeW * 0.30),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withOpacity(0.95),
    );

    // ---- Droplet floating above ----
    final r = w * 0.11;
    final tip = Offset(cx, h * 0.05);
    final cyD = h * 0.215;
    final dropRect = Rect.fromCircle(center: Offset(cx, cyD), radius: r * 1.4);
    final droplet = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(cx + r * 0.95, cyD - r * 0.55, cx + r, cyD)
      ..arcToPoint(Offset(cx - r, cyD),
          radius: Radius.circular(r), clockwise: false)
      ..quadraticBezierTo(cx - r * 0.95, cyD - r * 0.55, tip.dx, tip.dy)
      ..close();
    // faint droplet glow
    canvas.drawCircle(
      Offset(cx, cyD),
      r * 1.25,
      Paint()
        ..color = _accent.withOpacity(0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04),
    );
    canvas.drawPath(
      droplet,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(_accent, Colors.white, 0.30)!, _accentDeep],
        ).createShader(dropRect),
    );
    canvas.drawPath(
      droplet,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.5
        ..color = Colors.white.withOpacity(0.7),
    );
    // specular highlight
    canvas.drawCircle(Offset(cx - r * 0.32, cyD - r * 0.32), r * 0.26,
        Paint()..color = Colors.white.withOpacity(0.85));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
