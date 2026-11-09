import 'package:flutter/widgets.dart';

/// A group of sounds shown together in a browser (Rain, Water… / Piano, Lo-fi…).
@immutable
class SoundCategory {
  final String id;
  final String label;
  final IconData icon;

  const SoundCategory(this.id, this.label, this.icon);
}

/// Anything selectable in a sound browser (ambient beds, music tracks).
abstract interface class SoundItem {
  /// Stable id, persisted in settings.
  String get name;
  String get label;

  /// [SoundCategory.id] this item belongs to.
  String get category;
  IconData get icon;

  /// Store-delivered pack this sound lives in (`ambient` / `music`), or null
  /// when it ships inside the app bundle.
  String? get pack;

  /// The audio file's name, in `assets/sounds/` (bundled) or in its pack.
  String get fileName;
}
