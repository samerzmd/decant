import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Draws the arcing liquid stream from a source tube's spout to a destination
/// tube's mouth, plus splash droplets on impact. Rendered as a full-board
/// overlay so it can cross between tube widgets.
class PourStreamPainter extends CustomPainter {
  /// Spout point (top of the tilted source tube).
  final Offset source;

  /// Mouth point (top of the destination tube).
  final Offset dest;

  final int colorId;

  /// 0..1 progress of the pour.
  final double progress;

  PourStreamPainter({
    required this.source,
    required this.dest,
    required this.colorId,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) {
      if (progress <= 0) return;
    }

    // Arc up and over from the source spout to the destination mouth.
    final lift = (source.dy < dest.dy ? source.dy : dest.dy) - 46;
    final control = Offset((source.dx + dest.dx) / 2, lift);
    final path = Path()
      ..moveTo(source.dx, source.dy)
      ..quadraticBezierTo(control.dx, control.dy, dest.dx, dest.dy);

    // The stream shoots out (reaches dest by ~40%) and retracts after ~70%.
    final head = (progress / 0.4).clamp(0.0, 1.0);
    final tail = ((progress - 0.7) / 0.3).clamp(0.0, 1.0);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final len = metric.length;
    final sub = metric.extractPath(tail * len, head * len);

    // Stream body.
    canvas.drawPath(
      sub,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.5
        ..strokeCap = StrokeCap.round
        ..color = liquidColor(colorId).withValues(alpha: 0.92),
    );
    // Glossy core highlight.
    canvas.drawPath(
      sub,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = liquidTint(colorId).withValues(alpha: 0.85),
    );

    // Splash droplets at the destination once the stream has connected.
    if (head >= 1.0 && tail < 1.0) {
      _paintSplash(canvas);
    }
  }

  void _paintSplash(Canvas canvas) {
    final paint = Paint()..color = liquidColor(colorId).withValues(alpha: 0.9);
    final rng = math.Random(colorId * 31 + 7);
    final phase = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
    for (var i = 0; i < 5; i++) {
      final ang = -math.pi / 2 + (rng.nextDouble() - 0.5) * 1.8;
      final dist = 14 + 16 * phase * rng.nextDouble();
      final dx = dest.dx + math.cos(ang) * dist;
      final dy = dest.dy + math.sin(ang) * dist + phase * phase * 22; // gravity
      final r = (2.4 - 1.6 * phase) * (0.6 + rng.nextDouble() * 0.6);
      if (r <= 0.2) continue;
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PourStreamPainter old) =>
      old.progress != progress ||
      old.source != source ||
      old.dest != dest ||
      old.colorId != colorId;
}
