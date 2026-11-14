// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:decant/audio/audio_service.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the native engine. Loads wait on [gate] when it's set, so a
/// test can act while a load is in flight.
class _FakeEngine implements SoLoud {
  int inits = 0;
  int deinits = 0;
  final List<String> calls = [];
  Completer<void>? gate;
  int _next = 1;
  final Set<int> _live = {};

  int get plays => calls.where((c) => c == 'play').length;

  /// The OS reclaimed every voice while the app was away.
  void dropVoices() => _live.clear();

  @override
  dynamic noSuchMethod(Invocation i) {
    final name = i.memberName.toString().split('"')[1];
    switch (name) {
      case 'init':
        inits++;
        _live.clear();
        return Future<void>.value();
      case 'deinit':
        deinits++;
        _live.clear();
        return null;
      case 'loadAsset':
      case 'loadFile':
        return _load();
      case 'play':
        final id = _next++;
        _live.add(id);
        calls.add('play');
        return SoundHandle(id);
      case 'getIsValidVoiceHandle':
        return _live.contains((i.positionalArguments.first as SoundHandle).id);
      default:
        calls.add(name);
        return null;
    }
  }

  Future<AudioSource> _load() async {
    final g = gate;
    if (g != null) await g.future;
    return AudioSource(SoundHash(_next++));
  }
}

class _ThrowingEngine implements SoLoud {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('no audio here');
}

void main() {
  // The service watches the sound packs over a platform channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeEngine engine;
  late AudioService audio;

  setUp(() {
    engine = _FakeEngine();
    audio = AudioService(engine: engine);
  });

  test('loads, then starts the ambience and music asked for meanwhile',
      () async {
    final loading = audio.init();
    await audio.startAmbient();
    await audio.startMusic();
    expect(engine.plays, 0);
    await loading;
    expect(audio.isReady, isTrue);
    expect(engine.plays, 2);
  });

  test('a resume during the startup load joins it instead of a second load',
      () async {
    engine.gate = Completer<void>();
    final startup = audio.init();
    final resumed = audio.handleAppResumed();
    engine.gate!.complete();
    await Future.wait([startup, resumed]);
    expect(engine.inits, 1);
    expect(audio.isReady, isTrue);
  });

  test('a load cut off by detach never marks the dead engine ready', () async {
    engine.gate = Completer<void>();
    final startup = audio.init();
    await Future<void>.delayed(Duration.zero);
    await audio.handleAppDetached();
    engine.gate!.complete();
    await startup;
    expect(engine.deinits, 1);
    expect(audio.isReady, isFalse);
  });

  test('after a detach, resuming loads afresh and restarts the loops',
      () async {
    engine.gate = Completer<void>();
    final startup = audio.init();
    await Future<void>.delayed(Duration.zero);
    await audio.handleAppDetached();
    engine.gate!.complete();
    engine.gate = null;
    await startup;

    await audio.handleAppResumed();
    expect(engine.inits, 2);
    expect(audio.isReady, isTrue);
    expect(engine.plays, 2);
  });

  test('pause and resume un-pause the playing loops without replaying them',
      () async {
    await audio.init();
    await audio.startAmbient();
    await audio.startMusic();
    final plays = engine.plays;

    await audio.handleAppPaused();
    await audio.handleAppResumed();
    expect(engine.plays, plays);
    expect(engine.calls.where((c) => c == 'setPause'), hasLength(4));
  });

  test('a loop the engine dropped while away starts again on resume', () async {
    await audio.init();
    await audio.startAmbient();
    await audio.handleAppPaused();
    engine.dropVoices();
    final plays = engine.plays;
    await audio.handleAppResumed();
    expect(engine.plays, greaterThan(plays));
  });

  test('without an engine everything stays a silent no-op', () async {
    final silent = AudioService(engine: _ThrowingEngine());
    await silent.init();
    expect(silent.isReady, isFalse);
    silent.tap();
    await silent.handleAppPaused();
    await silent.handleAppResumed();
    await silent.handleAppDetached();
  });
}
