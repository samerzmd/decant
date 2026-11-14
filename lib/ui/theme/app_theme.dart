import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/liquid_palette.dart';

/// Decant's calm visual identity: deep twilight gradients, soft glass, a single
/// warm-teal accent. Centralized so every screen stays on-brand.
///
/// Every color follows [activeUiTheme], so the same widgets work on the dark
/// themes and on [UiTheme.daylight]. Screens never use raw white or black for
/// text and surfaces; they use these tokens.
class DecantColors {
  static bool get isLight => activeUiTheme.isLight;

  static Color get bgTop => activeUiTheme.colors[0];
  static Color get bgMid => activeUiTheme.colors[1];
  static Color get bgBottom => activeUiTheme.colors[2];

  /// The calm teal, darkened on light backgrounds so text stays readable.
  static Color get accent =>
      isLight ? const Color(0xFF0A7468) : const Color(0xFF49D6C3);
  static Color get accentDeep =>
      isLight ? const Color(0xFF075A51) : const Color(0xFF2BB6A6);

  /// Text and icons drawn on top of [accent].
  static Color get onAccent =>
      isLight ? const Color(0xFFFFFFFF) : const Color(0xFF0E1530);

  static Color get onSurface =>
      isLight ? const Color(0xFF1B2440) : const Color(0xFFEFF3FF);
  static Color get subtle =>
      isLight ? const Color(0xFF515C78) : const Color(0xFFA9B3D0);

  /// The base of translucent fills and borders (cards, chips, tracks): white
  /// on dark themes, deep navy on light ones. Use it with an alpha.
  static Color get ink =>
      isLight ? const Color(0xFF1B2440) : const Color(0xFFFFFFFF);

  /// A recessed, darker-than-background fill.
  static Color get recess => isLight
      ? const Color(0x0F1B2440)
      : const Color(0x38000000); // black at 22%

  static Color get glassEdge =>
      isLight ? const Color(0x661B2440) : const Color(0x55FFFFFF);

  /// Stars and gold highlights; deeper amber on light so it stays visible.
  static Color get star =>
      isLight ? const Color(0xFFAD6A00) : const Color(0xFFFFD66B);

  /// Red for warnings, deepened on light themes.
  static Color get danger =>
      isLight ? const Color(0xFFC0304A) : const Color(0xFFF08AA6);

  /// The two-stop gradient of dialogs, overlays and floating cards.
  static List<Color> get panel => isLight
      ? const [Color(0xFFFFFFFF), Color(0xFFF1EEF8)]
      : const [Color(0xFF2A3766), Color(0xFF31265C)];

  /// [panel], slightly see-through.
  static List<Color> get panelTranslucent => [
        for (final c in panel) c.withValues(alpha: 0.95),
      ];

  /// The dimming layer behind dialogs and overlays.
  static Color get scrim =>
      isLight ? const Color(0x661B2440) : const Color(0x8C000000);

  /// Drop shadows under floating cards.
  static Color get shadow =>
      isLight ? const Color(0x221B2440) : const Color(0x59000000);

  const DecantColors._();
}

ThemeData buildDecantTheme() {
  final light = activeUiTheme.isLight;
  final base = light
      ? ThemeData.light(useMaterial3: true)
      : ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: DecantColors.bgMid,
    colorScheme: base.colorScheme.copyWith(
      primary: DecantColors.accent,
      onPrimary: DecantColors.onAccent,
      secondary: DecantColors.accentDeep,
      surface: DecantColors.bgMid,
      onSurface: DecantColors.onSurface,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: DecantColors.onSurface,
      displayColor: DecantColors.onSurface,
      fontFamily: 'Roboto',
    ),
    iconTheme: base.iconTheme.copyWith(color: DecantColors.onSurface),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: DecantColors.accent,
      thumbColor: DecantColors.accent,
      inactiveTrackColor: DecantColors.subtle.withValues(alpha: 0.3),
    ),
  );
}

/// Status bar and navigation bar icons that read on the active theme.
SystemUiOverlayStyle decantOverlayStyle() {
  final light = activeUiTheme.isLight;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
    statusBarBrightness: light ? Brightness.light : Brightness.dark,
  );
}

/// The background theme, set from settings at the app root.
UiTheme activeUiTheme = UiTheme.twilight;

/// A full-screen container painting the brand gradient. Wrap each screen body.
/// [colors] swaps in another top-to-bottom gradient, such as a chapter theme.
/// Keeps menu content at a comfortable reading width, centered, so buttons
/// and lists don't stretch across tablets and landscape phones.
class ReadableWidth extends StatelessWidget {
  final Widget child;
  const ReadableWidth({super.key, required this.child});

  static const double maxWidth = 560;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

class DecantBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  const DecantBackground({super.key, required this.child, this.colors});

  /// The gradient actually painted: [colors], or the active theme's.
  List<Color> get effectiveColors => colors ?? activeUiTheme.colors;

  @override
  Widget build(BuildContext context) {
    final c = effectiveColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: c,
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// Applies [theme] to [activeUiTheme] and the system bars, and rebuilds the
/// whole subtree when it changes.
///
/// Screens read [DecantColors] directly rather than through an inherited
/// widget, so a switch marks every element below for rebuild, including
/// routes further down the navigator stack.
class UiThemeScope extends StatefulWidget {
  final UiTheme theme;
  final WidgetBuilder builder;
  const UiThemeScope({super.key, required this.theme, required this.builder});

  @override
  State<UiThemeScope> createState() => _UiThemeScopeState();
}

class _UiThemeScopeState extends State<UiThemeScope> {
  @override
  void didUpdateWidget(UiThemeScope old) {
    super.didUpdateWidget(old);
    if (old.theme != widget.theme) {
      WidgetsBinding.instance.addPostFrameCallback(_rebuildEverything);
    }
  }

  void _rebuildEverything(Duration _) {
    if (mounted) context.visitChildElements(_markForRebuild);
  }

  static void _markForRebuild(Element e) {
    e.markNeedsBuild();
    e.visitChildren(_markForRebuild);
  }

  @override
  Widget build(BuildContext context) {
    activeUiTheme = widget.theme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: decantOverlayStyle(),
      child: Builder(builder: widget.builder),
    );
  }
}
