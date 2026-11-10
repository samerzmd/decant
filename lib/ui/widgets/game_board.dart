import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/move.dart';
import '../../state/game_controller.dart';
import '../../state/game_session.dart';
import '../../state/providers.dart';
import '../painters/liquid_geometry.dart';
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

  /// Tutorial move to highlight (like a hint, but free). One tube glows at a
  /// time: the source until it's picked up, then the target until the pour.
  final Move? guide;

  const GameBoard({super.key, required this.levelId, this.guide});

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
    // Duration is set per pour from the pour-speed setting.
    _pour = AnimationController(vsync: this);
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
    final settings = ref.watch(settingsProvider);
    final colorblind = settings.colorblindMode;
    // Reduced motion: the in-app setting or the system's "remove animations".
    final reduceMotion =
        settings.reduceMotion || MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _bubble.isAnimating) {
      _bubble.stop();
    } else if (!reduceMotion && !_bubble.isAnimating) {
      _bubble.repeat();
    }
    final shader = ref.watch(glassShaderProvider).asData?.value;

    // Kick off animations when a new pour begins.
    final pour = session.pour;
    if (pour != null && pour.id != _lastPourId) {
      _lastPourId = pour.id;
      _pour.duration = pour.duration;
      _pour.forward(from: 0);
      if (!reduceMotion) {
        // The landed liquid settles once the stream has stopped falling.
        final settle = pour.duration * (PourAnim.flowEnd + PourAnim.fall);
        Future.delayed(settle, () {
          if (mounted) _wobble.forward(from: 0);
        });
      }
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
          // A plain method rather than an inline closure: release builds
          // crashed in the GC with this frame body as a nested closure.
          builder: (context, _) => _buildFrame(
            layout: layout,
            session: session,
            controller: controller,
            colorblind: colorblind,
            reduceMotion: reduceMotion,
            shader: shader,
            boardWidth: constraints.maxWidth,
          ),
        );
      },
    );
  }

  /// One animation frame of the board: every tube in its slot (the pouring
  /// source moved and tilted), plus the stream.
  ///
  /// Kept deliberately simple for the compiler: [pour] and [pose] are
  /// resolved to non-null locals once, and tubes are matched by index, with
  /// no promotion through stored booleans and no nested closures.
  Widget _buildFrame({
    required _Layout layout,
    required GameSession session,
    required GameController controller,
    required bool colorblind,
    required bool reduceMotion,
    required ui.FragmentShader? shader,
    required double boardWidth,
  }) {
    final time = _bubble.value * 8.0;
    final pourP = _pour.value;
    final PourAnim? pour = session.pour;
    final _PourPose? pose = pour == null
        ? null
        : _pose(layout, session, pour, pourP, reduceMotion, boardWidth, time);

    // -1 when no pour is running.
    final int sourceIndex = (pour != null && pose != null) ? pour.from : -1;
    final int destIndex = (pour != null && pose != null) ? pour.to : -1;
    final int pourCount = pour?.count ?? 0;
    final int? pourColor = pour?.color;
    final wobbleOn = _wobble.isAnimating;
    final wobbleValue = _wobble.value;

    final children = <Widget>[];
    Widget? source;
    final tubes = session.state.tubes;
    for (var i = 0; i < tubes.length; i++) {
      final rect = layout.rects[i];
      final isSource = i == sourceIndex;
      final isDest = i == destIndex;
      final child = Positioned(
        key: ValueKey(i),
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: TubeWidget(
          tube: tubes[i],
          width: rect.width,
          height: rect.height,
          time: time,
          colorblind: colorblind,
          selected: session.selected == i,
          hintSource: session.hint?.from == i ||
              (widget.guide?.from == i && session.selected != i),
          hintTarget: session.hint?.to == i ||
              (widget.guide?.to == i && session.selected == widget.guide?.from),
          risingCount: isDest ? pourCount : 0,
          risingProgress: isDest ? pose!.risen : 1.0,
          risingColor: isDest ? pourColor : null,
          drainCount: isSource ? pourCount : 0,
          drainProgress: isSource ? pose!.drained : 0.0,
          drainColor: isSource ? pourColor : null,
          tilt: isSource ? pose!.tilt : 0.0,
          pivot: isSource ? pose!.pivot : Alignment.topCenter,
          offset: isSource ? pose!.offset : Offset.zero,
          agitation: isDest ? pose!.agitation : 0.0,
          wobble: (isDest && wobbleOn) ? (1 - wobbleValue) : 0.0,
          shader: shader,
          onTap: _tapHandler(controller, i),
        ),
      );
      // The source is painted last, so it passes over other tubes.
      if (isSource) {
        source = child;
      } else {
        children.add(child);
      }
    }

    final stream = pose?.stream;
    if (stream != null) {
      children.add(Positioned.fill(
        child: IgnorePointer(child: CustomPaint(painter: stream)),
      ));
    }
    if (source != null) children.add(source);
    return Stack(clipBehavior: Clip.none, children: children);
  }

  /// Tap callback for tube [index], made outside the build loop.
  static VoidCallback _tapHandler(GameController controller, int index) =>
      () => controller.tapTube(index);

  // ---- Geometry ---------------------------------------------------------- //

  _Layout _computeLayout(Size size, int n, int capacity) {
    const gap = 14.0;
    const minW = 44.0;
    const maxW = 70.0;

    final maxPerRow = math.max(1, ((size.width + gap) / (minW + gap)).floor());
    var perRow = math.min(n, math.min(maxPerRow, 6));
    var rows = (n / perRow).ceil();
    perRow = (n / rows).ceil(); // rebalance

    var tubeW = ((size.width - (perRow - 1) * gap) / perRow)
        .clamp(minW, maxW)
        .toDouble();
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

  /// Where everything is at progress [p] of [pour]: the source tube flies
  /// to a spot beside the destination's mouth and tips there, pivoting on its
  /// lip. While liquid flows, the tilt follows the volume left inside, so the
  /// surface always just reaches the lip (as it does when you pour by hand).
  _PourPose _pose(
    _Layout layout,
    GameSession session,
    PourAnim pour,
    double p,
    bool reduceMotion,
    double boardWidth,
    double time,
  ) {
    const a = PourAnim.flowStart;
    const b = PourAnim.flowEnd;
    const fall = PourAnim.fall;
    final flowT = ((p - a) / (b - a)).clamp(0.0, 1.0);
    final drained = flowT * flowT * (3 - 2 * flowT); // eases in and out
    final risen = ((p - a - fall) / (b - a)).clamp(0.0, 1.0);

    if (reduceMotion) {
      // Levels still change, but nothing flies, tips or splashes.
      return _PourPose(drained: p, risen: p);
    }

    final src = layout.rects[pour.from];
    final dst = layout.rects[pour.to];
    final w = src.width;
    final capacity = session.level.capacity;

    // Lean toward the destination, unless the tipped tube would then stick
    // out past the board edge; then come in from the other side.
    var side = dst.center.dx >= src.center.dx ? 1.0 : -1.0;
    double lipX(double s) => dst.center.dx - s * w * 0.3;
    final room = side > 0 ? lipX(side) : boardWidth - lipX(side);
    if (room < src.height * 0.8) side = -side;
    final lip = Offset(lipX(side), dst.top - w * 0.3);
    final home = side > 0 ? src.topRight : src.topLeft;

    // Tilt that keeps the liquid level at the lip for a given fill.
    final cavity = LiquidGeometry.cavity(src.size);
    final left = session.state.tubes[pour.from].segments.length;
    double tiltFor(double segments) {
      final t = LiquidGeometry.pourTilt(cavity, segments / capacity, side);
      return side * math.max(t.abs(), 0.32);
    }

    final startTilt = tiltFor(left + pour.count.toDouble());
    final endTilt = tiltFor(left.toDouble());
    double travel;
    double tilt;
    if (p < a) {
      travel = Curves.easeInOut.transform(p / a);
      tilt = startTilt * travel;
    } else if (p <= b) {
      travel = 1;
      tilt = tiltFor(left + pour.count * (1 - drained));
    } else {
      travel = 1 - Curves.easeInOut.transform((p - b) / (1 - b));
      tilt = endTilt * travel;
    }
    // A slight lift on the way, so the tube arcs over rather than sliding.
    // (sin(pi * travel) is 0 at both ends, so this only acts mid-flight.)
    final arc = Offset(0, -w * 0.35 * math.sin(math.pi * travel));
    final offset = (lip - home) * travel + arc;

    PourStreamPainter? stream;
    var agitation = 0.0;
    final head = ((p - a) / fall).clamp(0.0, 1.0);
    final tail = ((p - b) / fall).clamp(0.0, 1.0);
    if (p > a && tail < 1) {
      // Liquid leaves from the inner corner of the lip, wherever it has turned.
      final wall = w * 0.07;
      final v = Offset(-side * wall * 0.9, wall * 0.5);
      final spout = lip +
          Offset(
            v.dx * math.cos(tilt) - v.dy * math.sin(tilt),
            v.dx * math.sin(tilt) + v.dy * math.cos(tilt),
          );
      final dCavity = LiquidGeometry.cavity(dst.size);
      final filled = pour.destFillBefore + pour.count * risen;
      final surface =
          dst.top + dCavity.bottom - filled * dCavity.height / capacity;
      stream = PourStreamPainter(
        spout: spout,
        impact: Offset(dst.center.dx, surface),
        side: side,
        colorId: pour.color,
        head: head * head, // falling: accelerates
        tail: tail * tail,
        flow: (math.min(1.0, flowT * 6) * (1 - 0.7 * math.pow(flowT, 4)))
            .toDouble(),
        time: time,
        scale: w,
      );
      agitation = head >= 1 ? (1 - tail) : 0.0;
    }

    return _PourPose(
      drained: drained,
      risen: risen,
      tilt: tilt,
      pivot: side > 0 ? Alignment.topRight : Alignment.topLeft,
      offset: offset,
      agitation: agitation,
      stream: stream,
    );
  }
}

/// One frame of an in-flight pour, see [_GameBoardState._pose].
class _PourPose {
  /// 0..1 of the poured liquid that has left the source.
  final double drained;

  /// 0..1 of the poured liquid that has landed in the destination.
  final double risen;

  final double tilt;
  final Alignment pivot;
  final Offset offset;
  final double agitation;
  final PourStreamPainter? stream;

  const _PourPose({
    required this.drained,
    required this.risen,
    this.tilt = 0,
    this.pivot = Alignment.topCenter,
    this.offset = Offset.zero,
    this.agitation = 0,
    this.stream,
  });
}

/// Convenience: a [Move] description for tooltips/debug (kept for reuse).
String describeMove(Move m) => 'Pour ${m.count} from ${m.from} to ${m.to}';
