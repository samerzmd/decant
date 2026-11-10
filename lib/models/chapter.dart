import 'dart:ui';

/// Campaign chapters: every [size] levels form a chapter with its own name
/// and background palette. Six themes, then the cycle repeats with the
/// chapter number still counting up, so the campaign stays endless.
///
/// Only the background changes: liquid colors are the same in every
/// chapter, so puzzles and colorblind symbols read the same everywhere.
class Chapter {
  /// 1-based chapter number.
  final int number;
  final String name;

  /// Background gradient, top to bottom.
  final List<Color> colors;

  const Chapter._(this.number, this.name, this.colors);

  static const int size = 20;

  static const List<String> names = [
    'Dawn',
    'Tide',
    'Ember',
    'Grove',
    'Dusk',
    'Aurora',
  ];

  static const List<List<Color>> palettes = [
    // Dawn: the original twilight.
    [Color(0xFF1B2440), Color(0xFF243156), Color(0xFF2E2150)],
    // Tide: deep sea blues.
    [Color(0xFF0F2A3A), Color(0xFF14394F), Color(0xFF1B2D4E)],
    // Ember: warm plum and rust.
    [Color(0xFF2A1A2E), Color(0xFF3A2234), Color(0xFF40242A)],
    // Grove: dark moss and pine.
    [Color(0xFF13261F), Color(0xFF1B3329), Color(0xFF1E2B36)],
    // Dusk: violet into indigo.
    [Color(0xFF24183F), Color(0xFF2E2156), Color(0xFF1C2147)],
    // Aurora: night teal with a green glow.
    [Color(0xFF0E2230), Color(0xFF123A3A), Color(0xFF1D2448)],
  ];

  /// The chapter campaign level [levelId] (1-based) belongs to.
  static Chapter forLevel(int levelId) {
    final number = (levelId - 1) ~/ size + 1;
    final theme = (number - 1) % names.length;
    return Chapter._(number, names[theme], palettes[theme]);
  }

  /// First and last level in this chapter.
  int get firstLevel => (number - 1) * size + 1;
  int get lastLevel => number * size;

  /// E.g. "Chapter 2 · Tide".
  String get title => 'Chapter $number · $name';
}
