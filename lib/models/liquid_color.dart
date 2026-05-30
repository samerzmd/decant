/// A liquid color used by the puzzle logic.
///
/// This is intentionally framework-agnostic: it carries only an integer [id]
/// plus a human label and an optional colorblind [symbol]. The mapping from
/// [id] to an actual rendered colour lives in the UI layer (`ui/theme/palette.dart`),
/// which keeps all game logic pure and unit-testable without Flutter.
class LiquidColor {
  /// Stable identifier used for equality and persistence (0-based palette index).
  final int id;

  /// Short human-readable name (useful for accessibility / debugging).
  final String label;

  /// A glyph shown on segments when the colorblind-friendly option is enabled.
  final String symbol;

  const LiquidColor({
    required this.id,
    required this.label,
    required this.symbol,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LiquidColor && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LiquidColor($id:$label)';
}

/// The canonical, ordered palette of liquid colors.
///
/// Levels reference colors by index into this list. Up to 12 distinct colors
/// are supported, which is plenty for hard levels. The actual RGB values and
/// symbols rendered on screen are defined in the UI palette keyed by [id].
const List<LiquidColor> kLiquidPalette = <LiquidColor>[
  LiquidColor(id: 0, label: 'Ruby', symbol: '●'),
  LiquidColor(id: 1, label: 'Amber', symbol: '▲'),
  LiquidColor(id: 2, label: 'Citrine', symbol: '■'),
  LiquidColor(id: 3, label: 'Jade', symbol: '◆'),
  LiquidColor(id: 4, label: 'Teal', symbol: '★'),
  LiquidColor(id: 5, label: 'Azure', symbol: '✦'),
  LiquidColor(id: 6, label: 'Indigo', symbol: '✚'),
  LiquidColor(id: 7, label: 'Violet', symbol: '✿'),
  LiquidColor(id: 8, label: 'Magenta', symbol: '◐'),
  LiquidColor(id: 9, label: 'Rose', symbol: '✤'),
  LiquidColor(id: 10, label: 'Slate', symbol: '⬢'),
  LiquidColor(id: 11, label: 'Lime', symbol: '❉'),
];

/// Convenience accessor for the color at [id].
LiquidColor liquidColorById(int id) => kLiquidPalette[id];
