import 'package:flutter_test/flutter_test.dart';

import 'package:decant/services/log.dart';

void main() {
  late List<String> lines;
  late bool wasEnabled;
  final originalSink = Log.sink;

  setUp(() {
    lines = [];
    wasEnabled = Log.enabled;
    Log.sink = lines.add;
  });

  tearDown(() {
    Log.enabled = wasEnabled;
    Log.minLevel = LogLevel.debug;
    Log.sink = originalSink;
  });

  test('lines carry level, tag, message and error', () {
    Log.enabled = true;
    Log.d('Audio', 'engine released');
    Log.w('Shader', 'unavailable', StateError('no GPU'));
    expect(lines, [
      'Decant D/Audio: engine released',
      'Decant W/Shader: unavailable: Bad state: no GPU',
    ]);
  });

  test('the switch silences everything', () {
    Log.enabled = false;
    Log.e('Audio', 'init failed');
    expect(lines, isEmpty);
  });

  test('lines below the minimum level are dropped', () {
    Log.enabled = true;
    Log.minLevel = LogLevel.warning;
    Log.d('Lifecycle', 'resumed');
    Log.i('Audio', 'ready');
    Log.w('Haptics', 'failed');
    expect(lines, ['Decant W/Haptics: failed']);
  });

  test('on by default outside release builds', () {
    // Tests run as a debug build.
    expect(wasEnabled, isTrue);
  });
}
