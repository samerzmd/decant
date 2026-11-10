import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Draws the falling stream of liquid from a tipped source tube's lip down
/// into the destination, plus the splash where it lands. Rendered as a
/// full-board overlay so it can cross between tube widgets.
///
/// The stream leaves the lip with a little sideways speed and then drops
/// under gravity, thinning as it speeds up (as a real falling jet does). Its
/// [head] falls from the lip when the pour starts, and its [tail] breaks off
/// the lip and falls after it when the pour ends.
class PourStreamPainter extends CustomPainter {
  /// Where liquid leaves the source tube.
  final Offset spout;

  /// Where the stream hits the destination's liquid surface (or its floor).
  final Offset impact;

  /// +1 when the source leans right (stream leaves toward +x), -1 for left.
  final double side;

  final int colorId;

  /// 0..1 how far the leading edge has fallen from the spout to [impact].
  final double head;

  /// 0..1 how far the trailing edge has fallen; the stream is gone at 1.
  final double tail;

  /// 0..1 flow rate: full stream at 1, a thin trickle near 0.
  final double flow;

  /// Seconds, for ripples along the stream and the splash.
  final double time;

  /// Tube width, so everything scales with the board.
  final double scale;

  PourStreamPainter({
    required this.spout,
    required this.impact,
    required this.side,
    required this.colorId,
    required this.head,
    required this.tail,
    required this.flow,
    required this.time,
    required this.scale,
  });

  // Cubic from the lip to the impact point: leaves sideways, then falls.
  Offset _at(double t) {
    final p1 = spout + Offset(side * scale * 0.24, scale * 0.02);
    final drop = impact.dy - spout.dy;
    final p2 = Offset(impact.dx, spout.dy + drop * 0.3);
    final u = 1 - t;
    return spout * (u * u * u) +
        p1 * (3 * u * u * t) +
        p2 * (3 * u * t * t) +
        impact * (t * t * t);
  }

  double _halfWidth(double t) {
    final necking = 1 - 0.42 * t;
    final ripple = 1 + 0.08 * math.sin(t * 26 - time * 34);
    return scale * 0.085 * (0.25 + 0.75 * flow) * necking * ripple;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (head <= 0 || tail >= 1) return;
    final t0 = tail;
    final t1 = head;

    const n = 28;
    final centre = <Offset>[];
    final left = <Offset>[];
    final right = <Offset>[];
    final widths = <double>[];
    for (var i = 0; i <= n; i++) {
      final t = t0 + (t1 - t0) * i / n;
      final p = _at(t);
      var d = _at(math.min(1, t + 0.01)) - _at(math.max(0, t - 0.01));
      if (d.distance == 0) d = const Offset(0, 1);
      final normal = Offset(-d.dy, d.dx) / d.distance;
      final hw = _halfWidth(t);
      centre.add(p);
      widths.add(hw);
      left.add(p + normal * hw);
      right.add(p - normal * hw);
    }

    final body = Paint()..color = liquidColor(colorId).withValues(alpha: 0.96);
    canvas.drawPath(
      Path()..addPolygon([...left, ...right.reversed], true),
      body,
    );
    // Rounded ends.
    canvas.drawCircle(centre.last, widths.last, body);
    canvas.drawCircle(centre.first, widths.first, body);

    // Shading: a darker edge on one side, a bright core and a thin glint on
    // the other, so the stream reads as a round, glossy column.
    final avgW = widths.reduce((a, b) => a + b) / widths.length;
    void line(double towardLeft, double width, Color color) {
      canvas.drawPoints(
        PointMode.polygon,
        [
          for (var i = 0; i <= n; i++)
            towardLeft >= 0
                ? Offset.lerp(centre[i], left[i], towardLeft)!
                : Offset.lerp(centre[i], right[i], -towardLeft)!,
        ],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width
          ..color = color,
      );
    }

    line(-0.6, avgW * 0.7, liquidShade(colorId).withValues(alpha: 0.55));
    line(0.35, avgW * 0.55, liquidTint(colorId).withValues(alpha: 0.7));
    line(
      0.62,
      math.max(1.0, avgW * 0.18),
      Colors.white.withValues(alpha: 0.45),
    );

    // The last drop clinging to the lip as the stream breaks away.
    if (tail > 0) {
      final r = scale * 0.05 * (1 - tail);
      if (r > 0.3) {
        canvas.drawCircle(
          spout + Offset(side * scale * 0.03, scale * 0.08 * tail),
          r,
          body,
        );
      }
    }

    // Splash once the stream is landing, fading as the tail comes down.
    if (head >= 1) _paintSplash(canvas, 1 - tail);
  }

  void _paintSplash(Canvas canvas, double strength) {
    final s = strength * (0.4 + 0.6 * flow);
    if (s <= 0.02) return;

    // Rings spreading across the surface.
    for (var k = 0; k < 2; k++) {
      final ph = (time * 2.4 + k * 0.5) % 1.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: impact,
          width: scale * (0.12 + 0.6 * ph),
          height: scale * (0.04 + 0.12 * ph),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.4 * (1 - ph) * s),
      );
    }

    // Droplets thrown up from the impact that arc back down.
    final drop = Paint()..color = liquidTint(colorId).withValues(alpha: 0.9);
    for (var i = 0; i < 7; i++) {
      final period = 0.38 + 0.18 * _hash(i);
      final ph = ((time + _hash(i + 3) * period) % period) / period;
      final height = scale * (0.18 + 0.22 * _hash(i + 7)) * s;
      final spread = (_hash(i + 1) - 0.5) * scale * 0.62;
      final x = impact.dx + spread * ph;
      final y = impact.dy - 4 * height * (ph - ph * ph);
      final r = scale * (0.018 + 0.016 * _hash(i + 5)) * (1 - 0.5 * ph);
      canvas.drawCircle(Offset(x, y), r, drop);
    }
  }

  double _hash(int i) {
    final x = math.sin(i * 12.9898 + colorId * 4.1) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant PourStreamPainter old) =>
      old.head != head ||
      old.tail != tail ||
      old.flow != flow ||
      old.time != time ||
      old.spout != spout ||
      old.impact != impact ||
      old.colorId != colorId;
}
