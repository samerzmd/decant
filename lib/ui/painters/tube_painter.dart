import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/tube.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// Paints a single glass tube with a 2.5-D look: rounded-bottom glass body,
/// soft shadow, layered liquid segments with a rounded meniscus and glossy
/// reflections, rising bubbles, optional colorblind symbols, and a GLSL glass
/// highlight overlay (with a gradient fallback when the shader is unavailable).
///
/// Pour animation: the destination tube passes [risingCount] + [risingProgress]
/// so the newly-poured liquid grows upward; selection/hint states add glows.
class LiquidTubePainter extends CustomPainter {
  final Tube tube;
  final bool colorblind;

  /// Number of top segments currently "rising" (destination of an active pour).
  final int risingCount;

  /// 0..1 progress of the rising liquid.
  final double risingProgress;

  /// Color id of the rising liquid (the poured color).
  final int? risingColor;

  final bool selected;
  final bool hintSource;
  final bool hintTarget;
  final bool justCompleted;

  /// Continuous time (seconds) for bubble motion and shader specular drift.
  final double time;

  /// Landing wobble amount (0..1), applied as a subtle surface ripple.
  final double wobble;

  final ui.FragmentShader? glassShader;

  LiquidTubePainter({
    required this.tube,
    required this.colorblind,
    required this.time,
    this.risingCount = 0,
    this.risingProgress = 1.0,
    this.risingColor,
    this.selected = false,
    this.hintSource = false,
    this.hintTarget = false,
    this.justCompleted = false,
    this.wobble = 0.0,
    this.glassShader,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final wall = w * 0.07;
    final topR = Radius.circular(w * 0.18);
    final botR = Radius.circular(w * 0.46);

    final bodyRect = Rect.fromLTWH(0, 0, w, h);
    final bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: topR,
      topRight: topR,
      bottomLeft: botR,
      bottomRight: botR,
    );

    _paintShadow(canvas, w, h, botR);
    _paintGlassBody(canvas, bodyRRect, w, h);

    // Inner cavity that actually holds liquid.
    final innerRect =
        Rect.fromLTWH(wall, wall * 0.4, w - 2 * wall, h - wall * 1.2);
    final innerRRect = RRect.fromRectAndCorners(
      innerRect,
      topLeft: Radius.circular(w * 0.12),
      topRight: Radius.circular(w * 0.12),
      bottomLeft: Radius.circular((botR.x - wall).clamp(0, w)),
      bottomRight: Radius.circular((botR.x - wall).clamp(0, w)),
    );

    canvas.save();
    canvas.clipRRect(innerRRect);
    _paintLiquid(canvas, innerRect);
    _paintBubbles(canvas, innerRect);
    canvas.restore();

    _paintGlassOverlay(canvas, bodyRRect, size);
    _paintRim(canvas, bodyRRect, w);
    _paintStateGlow(canvas, bodyRRect);
  }

  // ----------------------------------------------------------------------- //

  void _paintShadow(Canvas canvas, double w, double h, Radius botR) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    final rect = Rect.fromCenter(
      center: Offset(w / 2 + w * 0.06, h - botR.y * 0.2),
      width: w * 0.86,
      height: w * 0.34,
    );
    canvas.drawOval(rect, shadowPaint);
  }

  void _paintGlassBody(Canvas canvas, RRect body, double w, double h) {
    // Translucent glass tint with a subtle vertical gradient.
    final glassPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x22FFFFFF), Color(0x11A9C4FF), Color(0x18101830)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(body.outerRect);
    canvas.drawRRect(body, glassPaint);
  }

  void _paintLiquid(Canvas canvas, Rect inner) {
    final capacity = tube.capacity;
    if (tube.isEmpty) return;
    final segH = inner.height / capacity;
    final len = tube.segments.length;

    final baseCount = (len - risingCount).clamp(0, len);

    // Draw the settled (non-rising) segments, bottom → up.
    for (var i = 0; i < baseCount; i++) {
      final colorId = tube.segments[i];
      final bottom = inner.bottom - i * segH;
      final top = inner.bottom - (i + 1) * segH;
      _paintSegmentBand(canvas, inner, top, bottom, colorId);
    }

    // The rising band (active pour into this tube).
    double surfaceY;
    int surfaceColor;
    if (risingCount > 0 && risingColor != null) {
      final baseTop = inner.bottom - baseCount * segH;
      final risingH = risingCount * segH * risingProgress.clamp(0.0, 1.0);
      final top = baseTop - risingH;
      if (risingH > 0.5) {
        _paintSegmentBand(canvas, inner, top, baseTop, risingColor!);
      }
      surfaceY = top;
      surfaceColor = risingColor!;
    } else {
      surfaceY = inner.bottom - len * segH;
      surfaceColor = tube.segments.last;
    }

    _paintMeniscus(canvas, inner, surfaceY, segH, surfaceColor);
    _paintGloss(canvas, inner);
    if (colorblind) _paintSymbols(canvas, inner, segH, baseCount);
  }

  void _paintSegmentBand(
      Canvas canvas, Rect inner, double top, double bottom, int colorId) {
    final rect = Rect.fromLTRB(inner.left, top, inner.right, bottom);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          liquidShade(colorId),
          liquidColor(colorId),
          liquidTint(colorId),
          liquidColor(colorId),
          liquidShade(colorId),
        ],
        stops: const [0.0, 0.22, 0.42, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintMeniscus(
      Canvas canvas, Rect inner, double surfaceY, double segH, int colorId) {
    // Concave surface: a lighter elliptical cap sitting on top of the column,
    // nudged by the landing [wobble] for a settling ripple.
    final dip = segH * 0.32;
    final ripple = math.sin(time * 9) * wobble * segH * 0.10;
    final capRect = Rect.fromLTRB(
      inner.left,
      surfaceY - dip * 0.5 + ripple,
      inner.right,
      surfaceY + dip * 0.5 + ripple,
    );
    final capPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [liquidTint(colorId), liquidColor(colorId)],
      ).createShader(capRect);
    canvas.drawOval(capRect, capPaint);

    // Bright thin highlight crescent on the meniscus.
    final hi = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..addArc(capRect.deflate(2), math.pi * 1.08, math.pi * 0.5);
    canvas.drawPath(path, hi);
  }

  void _paintGloss(Canvas canvas, Rect inner) {
    // Vertical glossy reflection strip on the left of the liquid column.
    final glossRect = Rect.fromLTWH(
      inner.left + inner.width * 0.16,
      inner.top,
      inner.width * 0.12,
      inner.height,
    );
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(glossRect, Radius.circular(glossRect.width)),
      paint,
    );
  }

  void _paintSymbols(Canvas canvas, Rect inner, double segH, int baseCount) {
    for (var i = 0; i < baseCount; i++) {
      final colorId = tube.segments[i];
      final cy = inner.bottom - (i + 0.5) * segH;
      final tp = TextPainter(
        text: TextSpan(
          text: liquidSymbol(colorId),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: segH * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(inner.center.dx - tp.width / 2, cy - tp.height / 2));
    }
  }

  void _paintBubbles(Canvas canvas, Rect inner) {
    if (tube.isEmpty) return;
    final liquidTop =
        inner.bottom - tube.segments.length * (inner.height / tube.capacity);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    // A handful of deterministic bubbles drifting upward and looping.
    const count = 4;
    for (var b = 0; b < count; b++) {
      final phase = (time * (0.25 + b * 0.05) + b * 0.37) % 1.0;
      final x = inner.left + inner.width * (0.3 + 0.4 * _hash(b));
      final y = inner.bottom - phase * (inner.bottom - liquidTop);
      if (y < liquidTop) continue;
      final r = inner.width * (0.03 + 0.02 * _hash(b + 9));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  void _paintGlassOverlay(Canvas canvas, RRect body, Size size) {
    final shader = glassShader;
    if (shader != null) {
      try {
        shader
          ..setFloat(0, size.width)
          ..setFloat(1, size.height)
          ..setFloat(2, 0)
          ..setFloat(3, 0)
          ..setFloat(4, time);
        canvas.drawRRect(body, Paint()..shader = shader);
        return;
      } catch (_) {
        // fall through to gradient fallback
      }
    }
    // Fallback glass shading: left highlight + right soft shadow.
    final hi = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.30),
          Colors.white.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.18),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(body.outerRect);
    canvas.drawRRect(body, hi);
  }

  void _paintRim(Canvas canvas, RRect body, double w) {
    // Outer edge stroke.
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = DecantColors.glassEdge,
    );
    // Bright mouth rim (ellipse at the opening) for a 3-D tube feel.
    final mouth =
        Rect.fromLTWH(body.left + w * 0.07, -w * 0.02, w * 0.86, w * 0.22);
    canvas.drawArc(
      mouth,
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  void _paintStateGlow(Canvas canvas, RRect body) {
    Color? glow;
    if (hintTarget) {
      glow = DecantColors.accent;
    } else if (hintSource) {
      glow = DecantColors.star;
    } else if (selected) {
      glow = DecantColors.accent;
    } else if (justCompleted) {
      glow = Colors.white;
    }
    if (glow == null) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = glow.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(body.inflate(2), paint);
  }

  double _hash(int i) {
    final x = math.sin(i * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant LiquidTubePainter old) {
    return old.tube != tube ||
        old.time != time ||
        old.risingProgress != risingProgress ||
        old.risingCount != risingCount ||
        old.selected != selected ||
        old.hintSource != hintSource ||
        old.hintTarget != hintTarget ||
        old.wobble != wobble ||
        old.colorblind != colorblind ||
        old.glassShader != glassShader;
  }
}
