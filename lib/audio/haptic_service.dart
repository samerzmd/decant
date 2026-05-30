import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper over Flutter's [HapticFeedback] so haptics can be globally
/// toggled and centrally tuned to gameplay moments.
class HapticService {
  bool enabled;
  HapticService({this.enabled = true});

  /// Pour begins — a light tick.
  void pourStart() => _run(HapticFeedback.lightImpact);

  /// A droplet lands — selection click (subtle, frequent).
  void droplet() => _run(HapticFeedback.selectionClick);

  /// A tube is solved — a medium thud.
  void tubeComplete() => _run(HapticFeedback.mediumImpact);

  /// Puzzle solved — a heavy celebratory bump.
  void win() => _run(HapticFeedback.heavyImpact);

  /// Tube selected/deselected — a crisp tick.
  void select() => _run(HapticFeedback.selectionClick);

  void _run(Future<void> Function() fn) {
    if (!enabled) return;
    // Fire-and-forget; haptics are unsupported on some platforms/desktop.
    fn().catchError((Object e) => debugPrint('Haptic failed: $e'));
  }
}
