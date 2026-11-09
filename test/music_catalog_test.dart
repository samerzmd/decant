import 'dart:io';

import 'package:decant/audio/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('music catalog has 54 tracks with unique ids', () {
    expect(kMusicCatalog.length, 54);
    expect(
        kMusicCatalog.map((t) => t.name).toSet().length, kMusicCatalog.length);
  });

  test('every track has a known category and every category is used', () {
    final cats = kMusicCategories.map((c) => c.id).toSet();
    for (final t in kMusicCatalog) {
      expect(cats, contains(t.category), reason: t.name);
    }
    for (final c in kMusicCategories) {
      expect(kMusicCatalog.where((t) => t.category == c.id), isNotEmpty,
          reason: c.id);
    }
  });

  test('every track has its audio file (bundled or in its pack)', () {
    for (final t in kMusicCatalog) {
      final path = t.pack == null
          ? 'assets/sounds/${t.fileName}'
          : 'sound_packs/${t.pack}/${t.fileName}';
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('ids persisted by earlier versions still resolve', () {
    for (final id in ['twilightPad', 'musicBox', 'feltPiano', 'warmKeys']) {
      expect(MusicTrack.byName(id)?.name, id);
    }
  });

  test('only the originals are bundled; the rest ship in the music pack', () {
    const catalog = kMusicCatalog;
    expect(catalog.where((t) => t.pack == null).length, 4);
    expect(catalog.where((t) => t.pack == 'music').length, 50);
  });
}
