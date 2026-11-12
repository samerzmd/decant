import 'dart:ui';

/// The set of colors liquids are drawn in. Every palette has 12 colors, one
/// per liquid id, so levels play the same in any palette.
enum LiquidPalette {
  /// Vivid but calm: the original look.
  standard('Standard', [
    Color(0xFFE2425B), // Ruby
    Color(0xFFF2913D), // Amber
    Color(0xFFF6D04D), // Citrine
    Color(0xFF54B86B), // Jade
    Color(0xFF2BB6A6), // Teal
    Color(0xFF4AA6E8), // Azure
    Color(0xFF4C63D2), // Indigo
    Color(0xFF8E5BD9), // Violet
    Color(0xFFD45DB0), // Magenta
    Color(0xFFF08AA6), // Rose
    Color(0xFF7A8AA0), // Slate
    Color(0xFFA6D24A), // Lime
  ]),

  /// Built from the Okabe–Ito and Paul Tol palettes, which stay
  /// distinguishable with the common forms of color blindness.
  colorblindSafe('Colorblind-safe', [
    Color(0xFFE69F00), // orange
    Color(0xFF56B4E9), // sky blue
    Color(0xFF009E73), // bluish green
    Color(0xFFF0E442), // yellow
    Color(0xFF0072B2), // blue
    Color(0xFFD55E00), // vermillion
    Color(0xFFCC79A7), // reddish purple
    Color(0xFFDDDDDD), // pale grey
    Color(0xFF882255), // wine
    Color(0xFF999933), // olive
    Color(0xFF88CCEE), // cyan
    Color(0xFFAA4499), // purple
  ]),

  /// Fully saturated colors, as far apart as possible on a dark background.
  highContrast('High contrast', [
    Color(0xFFFF1744), // red
    Color(0xFFFF9100), // orange
    Color(0xFFFFEA00), // yellow
    Color(0xFF00E676), // green
    Color(0xFF00E5FF), // cyan
    Color(0xFF2979FF), // blue
    Color(0xFFD500F9), // purple
    Color(0xFFFF80AB), // pink
    Color(0xFFFFFFFF), // white
    Color(0xFF8D6E63), // brown
    Color(0xFF9E9E9E), // grey
    Color(0xFFC6FF00), // lime
  ]);

  final String label;
  final List<Color> colors;
  const LiquidPalette(this.label, this.colors);

  static LiquidPalette fromName(String? name) => LiquidPalette.values
      .firstWhere((p) => p.name == name, orElse: () => LiquidPalette.standard);
}

/// The app's background theme. Every screen paints it; campaign levels add
/// their chapter colors only on [twilight].
enum UiTheme {
  /// Deep twilight blues and violets: the original look.
  twilight(
      'Twilight', [Color(0xFF1B2440), Color(0xFF243156), Color(0xFF2E2150)]),

  /// Near-black: easier on the eyes at night, and on OLED screens.
  midnight(
      'Midnight', [Color(0xFF07090F), Color(0xFF0B0E18), Color(0xFF0E0B16)]),

  /// Pure black, for the strongest contrast with tubes and text.
  highContrast('High contrast',
      [Color(0xFF000000), Color(0xFF000000), Color(0xFF000000)]),

  /// Soft morning paper and pale sky: the light theme.
  daylight(
      'Daylight', [Color(0xFFF3F6FB), Color(0xFFE6EDF7), Color(0xFFEEE8F6)],
      isLight: true);

  final String label;
  final List<Color> colors;
  final bool isLight;
  const UiTheme(this.label, this.colors, {this.isLight = false});

  static UiTheme fromName(String? name) => UiTheme.values
      .firstWhere((t) => t.name == name, orElse: () => UiTheme.twilight);
}
