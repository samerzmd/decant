import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/move.dart';
import '../../models/tube.dart';
import '../../state/game_controller.dart';
import '../../state/game_session.dart';
import '../../state/providers.dart';
import '../painters/pour_stream_painter.dart';
import 'tube_widget.dart';

/// Computed positions for every tube within the board area.
class _Layout {
  final double tubeW;
  final double tubeH;
  final List<Rect> rects;
  const _Layout(this.tubeW, this.tubeH, this.rects);
}

/// Lays out all tubes (auto-wrapping into balanced rows), drives the pour /
/// bubble / wobble animations, and overlays the arc-stream painter.
class GameBoard extends ConsumerStatefulWidget {
  final int levelId;
  const GameBoard({super.key, required this.levelId});

  @override
  ConsumerState<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends ConsumerState<GameBoard>
    with TickerProviderStateMixin {
  late final AnimationController _bubble;
  late final AnimationController _pour;
  late final AnimationController _wobble;
  int _lastPourId = 0;

  @override
  void initState() {
    super.initState();
    _bubble = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _pour = AnimationController(vsync: this, duration: kPourDuration);
    _wobble = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _bubble.dispose();
    _pour.dispose();
    _wobble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levelId = widget.levelId;
    final session = ref.watch(gameControllerProvider(levelId));
    final controller = ref.read(gameControllerProvider(levelId).notifier);
    final colorblind = ref.watch(settingsProvider).colorblindMode;
    final shader = ref.watch(glassShaderProvider).asData?.value;

    // Kick off animations when a new pour begins.
    final pour = session.pour;
    if (pour != null && pour.id != _lastPourId) {
      _lastPourId = pour.id;
      _pour.forward(from: 0);
      Future.delayed(kPourDuration, () {
        if (mounted) _wobble.forward(from: 0);
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _computeLayout(
          constraints.biggest,
          session.state.tubes.length,
          session.level.capacity,
        );
        return AnimatedBuilder(
          animation: Listenable.merge([_bubble, _pour, _wobble]),
          builder: (context, _) {
            final time = _bubble.value * 8.0;
            final pourP = _pour.value;
            final children = <Widget>[];

            for (var i = 0; i < session.state.tubes.length; i++) {
              final Tube tube = session.state.tubes[i];
              final rect = layout.rects[i];

              final isSource = pour != null && pour.from == i;
              final isDest = pour != null && pour.to == i;

              final tilt = isSource ? _sourceTilt(layout, pour, pourP) : 0.0;
              final wobble =
                  (isDest && _wobble.isAnimating) ? (1 - _wobble.value) : 0.0;

              children.add(Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: TubeWidget(
                  tube: tube,
                  width: rect.width,
                  height: rect.height,
                  time: time,
                  colorblind: colorblind,
                  selected: session.selected == i,
                  hintSource: session.hint?.from == i,
                  hintTarget: session.hint?.to == i,
                  risingCount: isDest ? pour.count : 0,
                  risingProgress: isDest ? pourP : 1.0,
                  risingColor: isDest ? pour.color : null,
                  tilt: tilt,
                  wobble: wobble,
                  shader: shader,
                  onTap: () => controller.tapTube(i),
                ),
              ));
            }

            if (pour != null) {
              children.add(Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: PourStreamPainter(
                      source: _spout(layout, pour, pourP),
                      dest: _mouth(layout, pour.to),
                      colorId: pour.color,
                      progress: pourP,
                    ),
                  ),
                ),
              ));
            }

            return Stack(children: children);
          },
        );
      },
    );
  }

  // ---- Geometry ---------------------------------------------------------- //

  _Layout _computeLayout(Size size, int n, int capacity) {
    const gap = 14.0;
    const minW = 44.0;
    const maxW = 70.0;

    final maxPerRow = math.max(1, ((size.width + gap) / (minW + gap)).floor());
    var perRow = math.min(n, math.min(maxPerRow, 6));
    var rows = (n / perRow).ceil();
    perRow = (n / rows).ceil(); // rebalance

    var tubeW =
        ((size.width - (perRow - 1) * gap) / perRow).clamp(minW, maxW).toDouble();
    var tubeH = tubeW * (capacity * 0.6 + 0.6);

    // Shrink to fit vertically if needed.
    final neededH = rows * tubeH + (rows - 1) * gap;
    if (neededH > size.height) {
      final scale = size.height / neededH;
      tubeH *= scale;
      tubeW *= scale;
    }

    final rowHeight = tubeH + gap;
    final totalH = rows * tubeH + (rows - 1) * gap;
    final startY = ((size.height - totalH) / 2).clamp(0.0, size.height);

    final rects = <Rect>[];
    var index = 0;
    for (var r = 0; r < rows; r++) {
      final itemsThisRow = math.min(perRow, n - r * perRow);
      final rowWidth = itemsThisRow * tubeW + (itemsThisRow - 1) * gap;
      final startX = (size.width - rowWidth) / 2;
      for (var c = 0; c < itemsThisRow; c++) {
        final x = startX + c * (tubeW + gap);
        final y = startY + r * rowHeight;
        rects.add(Rect.fromLTWH(x, y, tubeW, tubeH));
        index++;
        if (index >= n) break;
      }
    }
    return _Layout(tubeW, tubeH, rects);
  }

  double _sourceTilt(_Layout layout, PourAnim pour, double p) {
    final src = layout.rects[pour.from].center;
    final dst = layout.rects[pour.to].center;
    final sign = dst.dx >= src.dx ? 1.0 : -1.0;
    final env = math.sin(math.pi * p.clamp(0.0, 1.0)); // 0→1→0
    return sign * 0.20 * env;
  }

  Offset _spout(_Layout layout, PourAnim pour, double p) {
    final r = layout.rects[pour.from];
    final dst = layout.rects[pour.to].center;
    final sign = dst.dx >= r.center.dx ? 1.0 : -1.0;
    final env = math.sin(math.pi * p.clamp(0.0, 1.0));
    return Offset(
      r.center.dx + sign * r.width * 0.42 * env,
      r.top + r.height * 0.04,
    );
  }

  Offset _mouth(_Layout layout, int index) {
    final r = layout.rects[index];
    return Offset(r.center.dx, r.top + r.height * 0.06);
  }
}

/// Convenience: a [Move] description for tooltips/debug (kept for reuse).
String describeMove(Move m) => 'Pour ${m.count} from ${m.from} to ${m.to}';
