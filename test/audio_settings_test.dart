import 'package:decant/audio/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioSettings defaults', () {
    test('fresh install: Ocean ambience with Warm Keys music on', () {
      const s = AudioSettings();
      expect(s.ambientTrack, AmbientTrack.ocean);
      expect(s.musicEnabled, isTrue);
      expect(s.musicTrack, MusicTrack.warmKeys);
    });

    test('older saved settings without a music key keep music off', () {
      final s = AudioSettings.fromJson({'ambientTrack': 'stream'});
      expect(s.musicEnabled, isFalse);
    });
  });

  group('Twilight Pad migration (ambient bed → music track)', () {
    test('saved "pad" ambience becomes Ocean + Twilight Pad music', () {
      final s = AudioSettings.fromJson(
          {'ambientTrack': 'pad', 'ambientEnabled': true});
      expect(s.ambientTrack, AmbientTrack.ocean);
      expect(s.musicEnabled, isTrue);
      expect(s.musicTrack, MusicTrack.twilightPad);
    });

    test('settings saved before track selection existed count as pad', () {
      final s = AudioSettings.fromJson({'sfx': 0.7, 'ambient': 0.4});
      expect(s.ambientTrack, AmbientTrack.ocean);
      expect(s.musicEnabled, isTrue);
      expect(s.musicTrack, MusicTrack.twilightPad);
      expect(s.sfxVolume, 0.7);
      expect(s.ambientVolume, 0.4);
    });

    test('ambience switched off: pad is not forced on as music', () {
      final s = AudioSettings.fromJson(
          {'ambientTrack': 'pad', 'ambientEnabled': false});
      expect(s.musicEnabled, isFalse);
    });

    test('music already on: the chosen music track is kept', () {
      final s = AudioSettings.fromJson({
        'ambientTrack': 'pad',
        'musicEnabled': true,
        'musicTrack': 'warmKeys',
      });
      expect(s.ambientTrack, AmbientTrack.ocean);
      expect(s.musicTrack, MusicTrack.warmKeys);
    });

    test('other ambient beds are untouched', () {
      final s = AudioSettings.fromJson({'ambientTrack': 'fireplace'});
      expect(s.ambientTrack, AmbientTrack.fireplace);
      expect(s.musicEnabled, isFalse);
    });
  });

  test('round-trips through JSON without re-migrating', () {
    const s = AudioSettings(
      ambientTrack: AmbientTrack.stream,
      musicEnabled: false,
      musicTrack: MusicTrack.musicBox,
    );
    final back = AudioSettings.fromJson(s.toJson());
    expect(back.ambientTrack, AmbientTrack.stream);
    expect(back.musicEnabled, isFalse);
    expect(back.musicTrack, MusicTrack.musicBox);
  });
}
