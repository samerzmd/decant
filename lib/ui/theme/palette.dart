import 'package:flutter/material.dart';

import '../../models/liquid_color.dart';

/// Rendered RGB values for each liquid id in [kLiquidPalette].
///
/// Chosen to be vivid yet calm, and as distinguishable as possible. When the
/// colorblind option is on, segments additionally show [LiquidColor.symbol].
const List<Color> kLiquidColors = <Color>[
  Color(0xFFE2425B), // 0 Ruby
  Color(0xFFF2913D), // 1 Amber
  Color(0xFFF6D04D), // 2 Citrine
  Color(0xFF54B86B), // 3 Jade
  Color(0xFF2BB6A6), // 4 Teal
  Color(0xFF4AA6E8), // 5 Azure
  Color(0xFF4C63D2), // 6 Indigo
  Color(0xFF8E5BD9), // 7 Violet
  Color(0xFFD45DB0), // 8 Magenta
  Color(0xFFF08AA6), // 9 Rose
  Color(0xFF7A8AA0), // 10 Slate
  Color(0xFFA6D24A), // 11 Lime
];

Color liquidColor(int id) => kLiquidColors[id % kLiquidColors.length];

/// A slightly darker shade of the same liquid, for the bottom gradient and the
/// rounded meniscus shading.
Color liquidShade(int id) {
  final c = liquidColor(id);
  return Color.lerp(c, Colors.black, 0.28)!;
}

/// A lighter tint, for the glossy top reflection on the liquid surface.
Color liquidTint(int id) {
  final c = liquidColor(id);
  return Color.lerp(c, Colors.white, 0.42)!;
}

String liquidSymbol(int id) =>
    kLiquidPalette[id % kLiquidPalette.length].symbol;
