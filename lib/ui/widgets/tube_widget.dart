import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/tube.dart';
import '../painters/tube_painter.dart';

/// A single tappable tube. Pure presentation: it paints [tube] via
/// [LiquidTubePainter] and applies selection-lift and pour-tilt transforms.
/// All game logic lives in the controller; this just reports taps.
class TubeWidget extends StatelessWidget {
  final Tube tube;
  final double width;
  final double height;
  final double time;
  final bool colorblind;

  final bool selected;
  final bool hintSource;
  final bool hintTarget;
  final bool justCompleted;

  final int risingCount;
  final double risingProgress;
  final int? risingColor;

  /// Tilt in radians (source tube during a pour).
  final double tilt;
  final double wobble;

  final ui.FragmentShader? shader;
  final VoidCallback onTap;

  const TubeWidget({
    super.key,
    required this.tube,
    required this.width,
    required this.height,
    required this.time,
    required this.colorblind,
    required this.onTap,
    this.selected = false,
    this.hintSource = false,
    this.hintTarget = false,
    this.justCompleted = false,
    this.risingCount = 0,
    this.risingProgress = 1.0,
    this.risingColor,
    this.tilt = 0.0,
    this.wobble = 0.0,
    this.shader,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        offset: Offset(0, selected ? -0.08 : 0),
        child: Transform.rotate(
          angle: tilt,
          alignment: Alignment.topCenter,
          child: CustomPaint(
            size: Size(width, height),
            painter: LiquidTubePainter(
              tube: tube,
              colorblind: colorblind,
              time: time,
              risingCount: risingCount,
              risingProgress: risingProgress,
              risingColor: risingColor,
              selected: selected,
              hintSource: hintSource,
              hintTarget: hintTarget,
              justCompleted: justCompleted,
              wobble: wobble,
              glassShader: shader,
            ),
          ),
        ),
      ),
    );
  }
}
