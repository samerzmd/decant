import 'dart:math' as math;
import 'dart:ui';

/// Geometry of liquid inside a tube that may be tilted.
///
/// Everything works in the tube's own (unrotated) coordinates. A tube rotated
/// clockwise by `tilt` radians sees world-down as the local direction
/// `(sin tilt, cos tilt)`, so a point's [depth] along that vector tells how
/// low it sits. Liquid fills every point deeper than its surface level, which
/// keeps the surface level with the world however the tube leans. With
/// `tilt == 0` the result is the same as flat horizontal bands.
class LiquidGeometry {
  LiquidGeometry._();

  /// Steepest tilt used when a tube pours its last drop (just past 90°).
  static const double maxTilt = 1.62;

  /// The liquid-holding cavity of a tube painted at [size]. Shared by the
  /// tube painter and the board, so both agree on where liquid sits.
  static Rect cavity(Size size) {
    final wall = size.width * 0.07;
    return Rect.fromLTWH(
      wall,
      wall * 0.4,
      size.width - 2 * wall,
      size.height - wall * 1.2,
    );
  }

  /// How low local point [p] sits for a tube tilted by [tilt].
  static double depth(Offset p, double tilt) =>
      p.dx * math.sin(tilt) + p.dy * math.cos(tilt);

  /// The part of [rect] whose depth lies between [top] and [bottom].
  static List<Offset> band(Rect rect, double tilt, double top, double bottom) {
    var poly = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft];
    poly = _clip(poly, (p) => depth(p, tilt) - top);
    if (bottom.isFinite) poly = _clip(poly, (p) => bottom - depth(p, tilt));
    return poly;
  }

  /// Where the surface at [level] meets the walls of [rect], or null.
  static (Offset, Offset)? chord(Rect rect, double tilt, double level) {
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];
    final hits = <Offset>[];
    for (var i = 0; i < 4; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % 4];
      final fa = depth(a, tilt) - level;
      final fb = depth(b, tilt) - level;
      if (fa == fb) continue;
      final t = fa / (fa - fb);
      if (t >= 0 && t < 1) hits.add(Offset.lerp(a, b, t)!);
    }
    if (hits.length < 2) return null;
    return (hits[0], hits[1]);
  }

  /// Surface level at which liquid below it fills [fraction] of [rect].
  static double levelFor(Rect rect, double tilt, double fraction) {
    final (minD, maxD) = _depthRange(rect, tilt);
    if (fraction <= 0) return maxD;
    if (fraction >= 1) return minD;
    final target = fraction * rect.width * rect.height;
    var lo = minD; // full
    var hi = maxD; // empty
    for (var i = 0; i < 30; i++) {
      final mid = (lo + hi) / 2;
      if (area(band(rect, tilt, mid, double.infinity)) > target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// The tilt at which a tube holding [fraction] of [rect] brings its liquid
  /// just up to the lip, leaning toward [side] (+1 right, -1 left). Tipping
  /// further would spill, so a pouring tube follows this angle as it drains.
  static double pourTilt(Rect rect, double fraction, double side) {
    if (fraction >= 1) return 0;
    if (fraction <= 0) return side * maxTilt;
    final lip = side > 0 ? rect.topRight : rect.topLeft;
    final full = rect.width * rect.height;
    var lo = 0.0;
    var hi = maxTilt;
    for (var i = 0; i < 30; i++) {
      final mid = (lo + hi) / 2;
      final t = side * mid;
      final below = area(band(rect, t, depth(lip, t), double.infinity));
      if (below / full > fraction) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return side * (lo + hi) / 2;
  }

  /// Area of a simple polygon.
  static double area(List<Offset> poly) {
    var sum = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum.abs() / 2;
  }

  /// Average of a polygon's corners: a good enough centre for small labels.
  static Offset centre(List<Offset> poly) {
    var x = 0.0;
    var y = 0.0;
    for (final p in poly) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / poly.length, y / poly.length);
  }

  static (double, double) _depthRange(Rect rect, double tilt) {
    final ds = [
      depth(rect.topLeft, tilt),
      depth(rect.topRight, tilt),
      depth(rect.bottomRight, tilt),
      depth(rect.bottomLeft, tilt),
    ];
    return (ds.reduce(math.min), ds.reduce(math.max));
  }

  /// Keeps the part of [poly] where [f] >= 0 (Sutherland–Hodgman).
  static List<Offset> _clip(List<Offset> poly, double Function(Offset) f) {
    final out = <Offset>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      final fa = f(a);
      final fb = f(b);
      if (fa >= 0) out.add(a);
      if ((fa >= 0) != (fb >= 0)) out.add(Offset.lerp(a, b, fa / (fa - fb))!);
    }
    return out;
  }
}
