import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/tube.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'liquid_geometry.dart';

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

  /// Liquid still leaving this tube (source of an active pour): [drainCount]
  /// segments of [drainColor] sit on top of [tube], [drainProgress] of the way
  /// out.
  final int drainCount;
  final double drainProgress;
  final int? drainColor;

  /// How far the tube is rotated (radians, clockwise), so the liquid inside
  /// can stay level with the world.
  final double liquidTilt;

  /// 0..1 churn from a stream landing in this tube: surface ripple + bubbles.
  final double agitation;

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
    this.drainCount = 0,
    this.drainProgress = 0.0,
    this.drainColor,
    this.liquidTilt = 0.0,
    this.agitation = 0.0,
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
    final innerRect = LiquidGeometry.cavity(size);
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
    final segH = inner.height / capacity;
    final len = tube.segments.length;
    final baseCount = (len - risingCount).clamp(0, len);

    // Layers bottom → top: a color and a volume (in segments) each, kept in
    // two parallel lists. Volumes rather than heights, so the same liquid
    // looks right however far the tube is tilted.
    final colors = <int>[
      for (var i = 0; i < baseCount; i++) tube.segments[i],
    ];
    final volumes = <double>[for (var i = 0; i < baseCount; i++) 1.0];
    if (risingCount > 0 && risingColor != null) {
      final v = risingCount * risingProgress.clamp(0.0, 1.0);
      if (v > 0.004) {
        colors.add(risingColor!);
        volumes.add(v);
      }
    }
    if (drainCount > 0 && drainColor != null) {
      final v = drainCount * (1 - drainProgress.clamp(0.0, 1.0));
      if (v > 0.004) {
        colors.add(drainColor!);
        volumes.add(v);
      }
    }
    if (colors.isEmpty) return;

    final tilt = liquidTilt;
    var below = double.infinity; // depth of the previous layer's surface
    var filled = 0.0;
    final centres = <Offset>[];
    for (var i = 0; i < colors.length; i++) {
      final colorId = colors[i];
      filled += volumes[i];
      final level = LiquidGeometry.levelFor(inner, tilt, filled / capacity);
      // Lower bands reach a hair into the next one up, which paints over the
      // overlap, so no anti-aliased seam shows between them.
      final top = i == colors.length - 1 ? level : level - 0.6;
      final poly = LiquidGeometry.band(inner, tilt, top, below);
      if (poly.length >= 3) _paintBand(canvas, inner, poly, colorId);
      centres.add(poly.length >= 3 ? LiquidGeometry.centre(poly) : Offset.zero);
      below = level;
    }

    _paintMeniscus(canvas, inner, below, segH, colors.last);
    _paintGloss(canvas, inner);
    if (colorblind) {
      // Symbols only on whole settled segments, not liquid on the move.
      _paintSymbols(
        canvas,
        segH,
        [for (var i = 0; i < baseCount; i++) tube.segments[i]],
        centres,
      );
    }
  }

  void _paintBand(Canvas canvas, Rect inner, List<Offset> poly, int colorId) {
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
      ).createShader(inner);
    canvas.drawPath(Path()..addPolygon(poly, true), paint);
  }

  void _paintMeniscus(
      Canvas canvas, Rect inner, double level, double segH, int colorId) {
    final chord = LiquidGeometry.chord(inner, liquidTilt, level);
    if (chord == null) return;
    final a = chord[0];
    final b = chord[1];
    final mid = Offset.lerp(a, b, 0.5)!;
    final span = (b - a).distance;

    // Concave surface: a lighter elliptical cap lying along the (world-level)
    // surface, nudged by the landing [wobble] and by a stream's [agitation].
    final dip = segH * (0.32 - 0.12 * (liquidTilt.abs() / 1.6).clamp(0, 1));
    final ripple = math.sin(time * 9) * wobble * segH * 0.10 +
        math.sin(time * 31) * agitation * segH * 0.05;
    canvas.save();
    canvas.translate(mid.dx, mid.dy);
    canvas.rotate(-liquidTilt);
    final capRect = Rect.fromCenter(
      center: Offset(0, ripple),
      width: span,
      height: dip,
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
    canvas.drawPath(
      Path()..addArc(capRect.deflate(2), math.pi * 1.08, math.pi * 0.5),
      hi,
    );

    // Churned surface: froth and bubbles where the stream lands.
    if (agitation > 0.01) {
      final froth = Paint()
        ..color = liquidTint(colorId).withValues(alpha: 0.75 * agitation);
      for (var i = 0; i < 6; i++) {
        final ph = (time * (1.3 + 0.4 * _hash(i)) + _hash(i + 4)) % 1.0;
        final x = (_hash(i + 11) - 0.5) * span * 0.55;
        final y = ripple + segH * (0.05 + 0.55 * (1 - ph));
        final r = segH * (0.035 + 0.03 * _hash(i + 2)) * (0.5 + 0.5 * ph);
        canvas.drawCircle(Offset(x, y), r, froth);
      }
    }
    canvas.restore();
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

  void _paintSymbols(
    Canvas canvas,
    double segH,
    List<int> segmentColors,
    List<Offset> centres,
  ) {
    for (var i = 0; i < segmentColors.length; i++) {
      final colorId = segmentColors[i];
      final c = centres[i];
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
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintBubbles(Canvas canvas, Rect inner) {
    // Idle bubbles only drift in an upright tube.
    if (tube.isEmpty || liquidTilt != 0) return;
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
        old.drainCount != drainCount ||
        old.drainProgress != drainProgress ||
        old.liquidTilt != liquidTilt ||
        old.agitation != agitation ||
        old.colorblind != colorblind ||
        old.glassShader != glassShader;
  }
}
