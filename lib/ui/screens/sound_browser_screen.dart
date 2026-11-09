import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_service.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';

/// Which library a [SoundBrowserScreen] shows.
enum SoundKind { ambient, music }

/// Full-screen browser for a sound library (54 ambient beds or 54 music
/// tracks): search, category filter chips and a grid of tiles grouped by
/// category. Tapping a tile switches the sound immediately, so browsing
/// doubles as auditioning.
class SoundBrowserScreen extends ConsumerStatefulWidget {
  final SoundKind kind;
  const SoundBrowserScreen({super.key, required this.kind});

  @override
  ConsumerState<SoundBrowserScreen> createState() => _SoundBrowserScreenState();
}

class _SoundBrowserScreenState extends ConsumerState<SoundBrowserScreen> {
  String? _category; // null = all
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _isMusic => widget.kind == SoundKind.music;
  List<SoundItem> get _items => _isMusic ? kMusicCatalog : kAmbientCatalog;
  List<SoundCategory> get _categories =>
      _isMusic ? kMusicCategories : kAmbientCategories;

  String _categoryLabel(String id) => _categories
      .firstWhere((c) => c.id == id, orElse: () => _categories.first)
      .label;

  List<SoundItem> _matches() {
    final q = _query.trim().toLowerCase();
    return _items.where((t) {
      if (_category != null && t.category != _category) return false;
      if (q.isEmpty) return true;
      return t.label.toLowerCase().contains(q) ||
          _categoryLabel(t.category).toLowerCase().contains(q);
    }).toList();
  }

  String get _pack => _isMusic ? 'music' : 'ambient';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PackState>(
      valueListenable: SoundPacks.instance.stateOf(_pack),
      builder: (context, pack, _) => _build(context, pack),
    );
  }

  void _explainUnavailable(BuildContext context, PackState pack) {
    final what = _isMusic ? 'music tracks' : 'sounds';
    final msg = switch (pack.status) {
      PackStatus.unavailable =>
        'More $what download from the Play Store / App Store with the store version of Decant.',
      PackStatus.waitingForWifi =>
        'More $what will download when you connect to Wi-Fi.',
      PackStatus.failed || PackStatus.canceled => 'Download failed. Retrying…',
      _ => pack.total > 0
          ? 'Downloading more $what… ${(pack.progress * 100).round()}%'
          : 'Downloading more $what…',
    };
    if (pack.status != PackStatus.unavailable) SoundPacks.instance.fetch(_pack);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  Widget _build(BuildContext context, PackState pack) {
    final audio = ref.watch(settingsProvider).audio;
    final ctrl = ref.read(settingsProvider.notifier);
    final SoundItem selected = _isMusic ? audio.musicTrack : audio.ambientTrack;
    final matches = _matches();
    final grouped = _category == null && _query.trim().isEmpty;
    final off = _isMusic ? !audio.musicEnabled : !audio.ambientEnabled;

    bool available(SoundItem t) => t.pack == null || pack.ready;
    void select(SoundItem t) {
      if (!available(t)) return _explainUnavailable(context, pack);
      _isMusic
          ? ctrl.setMusicTrack(t as MusicTrack)
          : ctrl.setAmbientTrack(t as AmbientTrack);
    }

    final slivers = <Widget>[];
    if (matches.isEmpty) {
      slivers.add(const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text('No sounds match your search',
              style: TextStyle(color: DecantColors.subtle, fontSize: 14)),
        ),
      ));
    } else if (grouped) {
      for (final cat in _categories) {
        final tracks = _items.where((t) => t.category == cat.id).toList();
        slivers
          ..add(SliverToBoxAdapter(child: _SectionHeader(cat, tracks.length)))
          ..add(_grid(tracks, selected, select, available, pack));
      }
    } else {
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 6)));
      slivers.add(_grid(matches, selected, select, available, pack));
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 28)));

    return Scaffold(
      body: DecantBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 20, 2),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: DecantColors.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_isMusic ? 'Music' : 'Ambience',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: DecantColors.onSurface)),
                          Text(
                            audio.muted
                                ? 'Muted · ${selected.label}'
                                : off
                                    ? 'Off · ${selected.label}'
                                    : 'Now playing · ${selected.label}',
                            style: TextStyle(
                                color:
                                    DecantColors.accent.withValues(alpha: 0.9),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: _SearchField(
                  hint:
                      'Search ${_items.length} ${_isMusic ? 'tracks' : 'sounds'}',
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () => setState(() {
                    _search.clear();
                    _query = '';
                  }),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _FilterChip(
                      label: 'All',
                      icon: Icons.apps_rounded,
                      active: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    for (final c in _categories)
                      _FilterChip(
                        label: c.label,
                        icon: c.icon,
                        active: _category == c.id,
                        onTap: () => setState(
                            () => _category = _category == c.id ? null : c.id),
                      ),
                  ],
                ),
              ),
              if (!pack.ready) _PackBanner(pack: pack, isMusic: _isMusic),
              const SizedBox(height: 4),
              Expanded(child: CustomScrollView(slivers: slivers)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(
      List<SoundItem> tracks,
      SoundItem selected,
      ValueChanged<SoundItem> onSelect,
      bool Function(SoundItem) available,
      PackState pack) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 128,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.92,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final t = tracks[i];
            return _SoundTile(
              track: t,
              categoryLabel: _categoryLabel(t.category),
              active: t == selected,
              available: available(t),
              downloading: !available(t) && pack.inProgress,
              progress: pack.progress,
              onTap: () => onSelect(t),
            );
          },
          childCount: tracks.length,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final SoundCategory category;
  final int count;
  const _SectionHeader(this.category, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      child: Row(
        children: [
          Icon(category.icon, size: 16, color: DecantColors.accent),
          const SizedBox(width: 8),
          Text(
            category.label.toUpperCase(),
            style: TextStyle(
              color: DecantColors.accent.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Text('$count',
              style: TextStyle(
                  color: DecantColors.subtle.withValues(alpha: 0.7),
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _SoundTile extends StatelessWidget {
  final SoundItem track;
  final String categoryLabel;
  final bool active;
  final bool available;
  final bool downloading;
  final double progress;
  final VoidCallback onTap;

  const _SoundTile({
    required this.track,
    required this.categoryLabel,
    required this.active,
    required this.available,
    required this.downloading,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: available
          ? '${track.label}, $categoryLabel'
          : '${track.label}, $categoryLabel, not downloaded yet',
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: available ? 1.0 : 0.55,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: active
                  ? DecantColors.accent.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active
                    ? DecantColors.accent
                    : Colors.white.withValues(alpha: 0.08),
                width: active ? 1.6 : 1.0,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? DecantColors.accent
                            : DecantColors.accent.withValues(alpha: 0.12),
                      ),
                      child: Icon(track.icon,
                          size: 24,
                          color: active
                              ? DecantColors.bgTop
                              : DecantColors.accent),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      track.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? DecantColors.onSurface
                            : DecantColors.subtle,
                        fontSize: 12.5,
                        height: 1.15,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (active)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.graphic_eq_rounded,
                        size: 16, color: DecantColors.accent),
                  ),
                if (!available)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: downloading
                        ? SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: progress > 0 ? progress : null,
                              color: DecantColors.accent,
                            ),
                          )
                        : const Icon(Icons.cloud_download_rounded,
                            size: 16, color: DecantColors.subtle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? DecantColors.accent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? DecantColors.accent
                  : Colors.white.withValues(alpha: 0.12),
              width: 1.3,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: active ? DecantColors.accent : DecantColors.subtle),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color:
                        active ? DecantColors.onSurface : DecantColors.subtle,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.hint,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: DecantColors.onSurface, fontSize: 15),
      cursorColor: DecantColors.accent,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: DecantColors.subtle.withValues(alpha: 0.7)),
        prefixIcon:
            const Icon(Icons.search_rounded, color: DecantColors.subtle),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon:
                    const Icon(Icons.close_rounded, color: DecantColors.subtle),
                onPressed: onClear,
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Shown while a library's store pack isn't on the device yet.
class _PackBanner extends StatelessWidget {
  final PackState pack;
  final bool isMusic;
  const _PackBanner({required this.pack, required this.isMusic});

  @override
  Widget build(BuildContext context) {
    final what = isMusic ? 'music tracks' : 'sounds';
    final text = switch (pack.status) {
      PackStatus.unavailable => '50 more $what come with the store version',
      PackStatus.waitingForWifi => 'More $what will download on Wi-Fi',
      PackStatus.failed ||
      PackStatus.canceled =>
        'Download paused — tap a sound to retry',
      _ => pack.total > 0
          ? 'Downloading 50 more $what… ${(pack.progress * 100).round()}%'
          : 'Getting 50 more $what ready…',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                pack.status == PackStatus.unavailable
                    ? Icons.storefront_rounded
                    : Icons.cloud_download_rounded,
                size: 15,
                color: DecantColors.subtle,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        color: DecantColors.subtle.withValues(alpha: 0.9),
                        fontSize: 12)),
              ),
            ],
          ),
          if (pack.inProgress) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 3,
                value: pack.total > 0 ? pack.progress : null,
                color: DecantColors.accent,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
