import 'dart:io';

import 'package:decant/audio/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog has 54 beds with unique ids', () {
    expect(kAmbientCatalog.length, 54);
    final ids = kAmbientCatalog.map((t) => t.name).toSet();
    expect(ids.length, kAmbientCatalog.length);
  });

  test('every bed belongs to a known category and every category is used', () {
    final cats = kAmbientCategories.map((c) => c.id).toSet();
    for (final t in kAmbientCatalog) {
      expect(cats, contains(t.category), reason: t.name);
    }
    for (final c in kAmbientCategories) {
      expect(
        kAmbientCatalog.where((t) => t.category == c.id),
        isNotEmpty,
        reason: c.id,
      );
    }
  });

  test('every bed has its audio file (bundled or in its pack)', () {
    for (final t in kAmbientCatalog) {
      final path = t.pack == null
          ? 'assets/sounds/${t.fileName}'
          : 'sound_packs/${t.pack}/${t.fileName}';
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('ids persisted by earlier versions still resolve', () {
    for (final id in ['rain', 'ocean', 'stream', 'fireplace']) {
      expect(AmbientTrack.byName(id)?.name, id);
    }
    expect(AmbientTrack.byName('pad'), isNull); // migrated to music
  });

  test('only the originals are bundled; the rest ship in the ambient pack', () {
    const catalog = kAmbientCatalog;
    expect(catalog.where((t) => t.pack == null).length, 4);
    expect(catalog.where((t) => t.pack == 'ambient').length, 50);
  });
}
