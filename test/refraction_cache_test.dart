import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:decant/models/tube.dart';
import 'package:decant/ui/painters/glass_shaders.dart';
import 'package:decant/ui/painters/tube_painter.dart';

void main() {
  late GlassShaders shaders;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    shaders = await GlassShaders.load();
  });

  void paint(LiquidTubePainter painter) {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(60, 180));
    recorder.endRecording().dispose();
  }

  LiquidTubePainter painter(
    LiquidLayerCache cache, {
    required double time,
    List<int> segments = const [0, 1, 2],
    double wobble = 0,
    double agitation = 0,
  }) =>
      LiquidTubePainter(
        tube: Tube(capacity: 4, segments: segments),
        colorblind: false,
        time: time,
        wobble: wobble,
        agitation: agitation,
        refractShader: shaders.refract,
        layerCache: cache,
        devicePixelRatio: 2,
      );

  test('a still tube draws its liquid image once', () {
    expect(shaders.refract, isNotNull);
    final cache = LiquidLayerCache();
    addTearDown(cache.dispose);
    for (var t = 0.0; t < 2; t += 0.1) {
      paint(painter(cache, time: t));
    }
    expect(cache.renders, 1);
    // A faint idle wobble (the home screen shelf) doesn't count as a change.
    paint(painter(cache, time: 3, wobble: 0.015));
    expect(cache.renders, 1);
  });

  test('new liquid or a churning surface draws it again', () {
    final cache = LiquidLayerCache();
    addTearDown(cache.dispose);
    paint(painter(cache, time: 0));
    paint(painter(cache, time: 0, segments: [0, 1]));
    expect(cache.renders, 2);
    paint(painter(cache, time: 0.1, agitation: 1));
    paint(painter(cache, time: 0.2, agitation: 1));
    expect(cache.renders, 4);
  });

  test('an empty tube makes no image', () {
    final cache = LiquidLayerCache();
    paint(painter(cache, time: 0, segments: const []));
    expect(cache.renders, 0);
  });
}
