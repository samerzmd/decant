import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../services/log.dart';

/// The fragment shaders the tube painter uses. Either can be null where the
/// platform can't compile it; the painter then falls back to plain drawing.
class GlassShaders {
  /// Highlights, rims and caustics drawn over the tube (`glass.frag`).
  final ui.FragmentShader? glass;

  /// Liquid seen through the curved glass (`refract.frag`).
  final ui.FragmentShader? refract;

  const GlassShaders({this.glass, this.refract});

  static Future<GlassShaders> load() async => GlassShaders(
      glass: await _load('glass'), refract: await _load('refract'));

  static Future<ui.FragmentShader?> _load(String name) async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/$name.frag');
      return program.fragmentShader();
    } catch (e) {
      Log.w('Shader', '$name unavailable, using fallback', e);
      return null;
    }
  }
}

/// The last liquid image one tube drew through the refraction shader, kept
/// until the liquid changes, so a still tube costs no offscreen pass.
class LiquidLayerCache {
  Object? _key;
  ui.Image? _image;

  /// How many images were made, for tests.
  @visibleForTesting
  int renders = 0;

  /// The cached image if it was made for [key].
  ui.Image? lookup(Object key) => key == _key ? _image : null;

  void store(Object key, ui.Image image) {
    _image?.dispose();
    _image = image;
    _key = key;
    renders++;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    _key = null;
  }
}
