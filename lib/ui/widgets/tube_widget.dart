import 'package:flutter/material.dart';

import '../../models/tube.dart';
import '../painters/glass_shaders.dart';
import '../painters/tube_painter.dart';

/// A single tappable tube. Pure presentation: it paints [tube] via
/// [LiquidTubePainter] and applies selection-lift and pour-tilt transforms.
/// All game logic lives in the controller; this just reports taps.
class TubeWidget extends StatefulWidget {
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

  /// Point the tube tilts around (its lip while pouring).
  final Alignment pivot;

  /// How far the tube has moved from its slot (the source flies to its target).
  final Offset offset;

  /// Liquid still leaving this tube, see [LiquidTubePainter.drainCount].
  final int drainCount;
  final double drainProgress;
  final int? drainColor;

  /// Churn from a stream landing in this tube.
  final double agitation;

  final GlassShaders? shader;
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
    this.pivot = Alignment.topCenter,
    this.offset = Offset.zero,
    this.drainCount = 0,
    this.drainProgress = 0.0,
    this.drainColor,
    this.agitation = 0.0,
    this.shader,
  });

  @override
  State<TubeWidget> createState() => _TubeWidgetState();
}

class _TubeWidgetState extends State<TubeWidget> {
  /// This tube's offscreen liquid image, reused while the liquid is still.
  final _layer = LiquidLayerCache();

  @override
  void dispose() {
    _layer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ??
        View.maybeOf(context)?.devicePixelRatio ??
        1.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Transform.translate(
        offset: widget.offset,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          offset: Offset(0, widget.selected ? -0.08 : 0),
          child: Transform.rotate(
            angle: widget.tilt,
            alignment: widget.pivot,
            child: CustomPaint(
              size: Size(widget.width, widget.height),
              painter: LiquidTubePainter(
                tube: widget.tube,
                colorblind: widget.colorblind,
                time: widget.time,
                risingCount: widget.risingCount,
                risingProgress: widget.risingProgress,
                risingColor: widget.risingColor,
                selected: widget.selected,
                hintSource: widget.hintSource,
                hintTarget: widget.hintTarget,
                justCompleted: widget.justCompleted,
                wobble: widget.wobble,
                glassShader: widget.shader?.glass,
                refractShader: widget.shader?.refract,
                layerCache: _layer,
                devicePixelRatio: dpr,
                drainCount: widget.drainCount,
                drainProgress: widget.drainProgress,
                drainColor: widget.drainColor,
                liquidTilt: widget.tilt,
                agitation: widget.agitation,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
