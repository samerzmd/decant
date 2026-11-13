import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../logic/custom_level.dart';
import '../../models/tube.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/decant_button.dart';
import '../widgets/decant_notice.dart';
import '../widgets/tube_widget.dart';
import 'game_screen.dart';

/// Runs the solvability check off the UI thread.
CustomLevelProblem? _check(List<List<int>> tubes) => CustomLevel.problem(tubes);

/// Build a puzzle, play it, and share it as a code friends can paste.
///
/// Pick how many colors, then pour layers in: choose a color and tap a tube
/// to add a layer, long-press to take the top one off. Every color needs
/// exactly four layers; two empty tubes are added when you play.
class LevelEditorScreen extends ConsumerStatefulWidget {
  /// Tubes to start from (an opened code); null starts a shuffled puzzle.
  final List<List<int>>? initial;
  const LevelEditorScreen({super.key, this.initial});

  @override
  ConsumerState<LevelEditorScreen> createState() => _LevelEditorScreenState();
}

class _LevelEditorScreenState extends ConsumerState<LevelEditorScreen> {
  static const _cap = CustomLevel.capacity;

  late int _colors;
  late List<List<int>> _tubes;
  int _selected = 0;
  bool _busy = false;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _load(initial);
    } else {
      _colors = 5;
      _shuffle();
    }
  }

  void _load(List<List<int>> tubes) {
    _colors = tubes.length;
    _tubes = [for (final t in tubes) List<int>.of(t)];
    _selected = 0;
  }

  int _countOf(int color) =>
      _tubes.fold(0, (n, t) => n + t.where((c) => c == color).length);

  void _setColors(int n) {
    setState(() {
      _colors = n;
      _shuffle();
    });
  }

  void _shuffle() {
    final pool = [
      for (var c = 0; c < _colors; c++)
        for (var i = 0; i < _cap; i++) c,
    ];
    do {
      pool.shuffle(_rng);
      _tubes = [
        for (var t = 0; t < _colors; t++)
          pool.sublist(t * _cap, (t + 1) * _cap),
      ];
    } while (CustomLevel.shapeProblem(_tubes) != null);
    _selected = 0;
  }

  void _clear() => setState(() {
        _tubes = [for (var t = 0; t < _colors; t++) <int>[]];
      });

  void _add(int tube) {
    final t = _tubes[tube];
    if (t.length >= _cap || _countOf(_selected) >= _cap) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => t.add(_selected));
  }

  void _removeTop(int tube) {
    if (_tubes[tube].isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _tubes[tube].removeLast());
  }

  /// Validates (counts, not already sorted, solvable). Shows why not, if not.
  Future<bool> _ready() async {
    setState(() => _busy = true);
    final problem = await compute(_check, [
      for (final t in _tubes) List<int>.of(t),
    ]);
    if (!mounted) return false;
    setState(() => _busy = false);
    if (problem == null) return true;
    final l = context.l10n;
    showDecantNotice(
      context,
      switch (problem) {
        CustomLevelProblem.incomplete => l.editorIncomplete(_cap),
        CustomLevelProblem.alreadySolved => l.editorAlreadySolved,
        CustomLevelProblem.unsolvable => l.editorUnsolvable,
      },
      icon: Icons.do_not_disturb_alt_rounded,
      tone: NoticeTone.warning,
    );
    return false;
  }

  Future<void> _play() async {
    if (!await _ready() || !mounted) return;
    final level = CustomLevel.toLevel(_tubes);
    final code = CustomLevel.encode(_tubes);
    ref.read(customLevelsProvider.notifier).update(
          (m) => {...m, level.id: level},
        );
    await ref.read(persistenceProvider).rememberCustomLevel(code);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/game'),
      builder: (_) => GameScreen(levelId: level.id),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _share() async {
    if (!await _ready() || !mounted) return;
    final code = CustomLevel.encode(_tubes);
    await ref.read(persistenceProvider).rememberCustomLevel(code);
    if (!mounted) return;
    setState(() {});
    final box = context.findRenderObject() as RenderBox?;
    await ref.read(shareProvider)(
      '${context.l10n.editorShareInvite}\n$code',
      box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _enterCode() async {
    final tubes = await showDialog<List<List<int>>>(
      context: context,
      barrierColor: DecantColors.scrim,
      builder: (_) => const _CodeDialog(),
    );
    if (tubes != null && mounted) setState(() => _load(tubes));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final shader = ref.watch(glassShaderProvider).asData?.value;
    final colorblind = ref.watch(settingsProvider).colorblindMode;
    final saved = ref.read(persistenceProvider).customLevelCodes();

    return Scaffold(
      body: DecantBackground(
        child: SafeArea(
          child: ReadableWidth(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded,
                            color: DecantColors.onSurface),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          l.levelEditor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: DecantColors.onSurface,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _enterCode,
                        icon: Icon(Icons.input_rounded,
                            color: DecantColors.accent, size: 20),
                        label: Text(l.editorEnterCode,
                            style: TextStyle(color: DecantColors.accent)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    children: [
                      Text(
                        l.editorHelp,
                        style:
                            TextStyle(color: DecantColors.subtle, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      _ColorCount(value: _colors, onChanged: _setColors),
                      const SizedBox(height: 14),
                      _Palette(
                        colors: _colors,
                        selected: _selected,
                        countOf: _countOf,
                        onSelect: (c) => setState(() => _selected = c),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 14,
                        runSpacing: 18,
                        children: [
                          for (var i = 0; i < _tubes.length; i++)
                            GestureDetector(
                              key: ValueKey('editor-tube-$i'),
                              onLongPress: () => _removeTop(i),
                              child: TubeWidget(
                                tube: Tube(capacity: _cap, segments: _tubes[i]),
                                width: 44,
                                height: 150,
                                time: 0,
                                colorblind: colorblind,
                                shader: shader,
                                onTap: () => _add(i),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: DecantButton(
                              label: l.editorShuffle,
                              icon: Icons.shuffle_rounded,
                              primary: false,
                              onPressed: () => setState(_shuffle),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DecantButton(
                              label: l.editorClear,
                              icon: Icons.layers_clear_rounded,
                              primary: false,
                              onPressed: _clear,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DecantButton(
                              label: l.editorPlay,
                              icon: Icons.play_arrow_rounded,
                              onPressed: _busy ? null : _play,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DecantButton(
                              label: l.editorShare,
                              icon: Icons.share_rounded,
                              primary: false,
                              onPressed: _busy ? null : _share,
                            ),
                          ),
                        ],
                      ),
                      if (saved.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        Text(
                          l.myLevels.toUpperCase(),
                          style: TextStyle(
                            color: DecantColors.subtle,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final code in saved)
                              _SavedChip(
                                code: code,
                                onTap: () {
                                  final tubes = CustomLevel.decode(code);
                                  if (tubes != null) {
                                    setState(() => _load(tubes));
                                  }
                                },
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorCount extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _ColorCount({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          context.l10n.editorColors,
          style: TextStyle(
            color: DecantColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var n = CustomLevel.minColors;
                  n <= CustomLevel.maxColors;
                  n++)
                ChoiceChip(
                  label: Text('$n'),
                  selected: n == value,
                  showCheckmark: false,
                  selectedColor: DecantColors.accent,
                  labelStyle: TextStyle(
                    color: n == value
                        ? DecantColors.onAccent
                        : DecantColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: DecantColors.ink.withValues(alpha: 0.06),
                  side: BorderSide.none,
                  onSelected: (_) => onChanged(n),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The colors to pour, each with how many layers are still unplaced.
class _Palette extends StatelessWidget {
  final int colors;
  final int selected;
  final int Function(int color) countOf;
  final ValueChanged<int> onSelect;
  const _Palette({
    required this.colors,
    required this.selected,
    required this.countOf,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var c = 0; c < colors; c++)
          GestureDetector(
            key: ValueKey('editor-color-$c'),
            onTap: () => onSelect(c),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeLiquidPalette.colors[c],
                border: Border.all(
                  color: c == selected
                      ? DecantColors.onSurface
                      : DecantColors.ink.withValues(alpha: 0.15),
                  width: c == selected ? 3 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${CustomLevel.capacity - countOf(c)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(blurRadius: 3)],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SavedChip extends StatelessWidget {
  final String code;
  final VoidCallback onTap;
  const _SavedChip({required this.code, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = CustomLevel.decode(code)?.length ?? 0;
    const start = CustomLevel.prefix.length;
    final tag = code.substring(start, math.min(code.length, start + 6));
    return ActionChip(
      avatar: Icon(Icons.science_rounded, size: 18, color: DecantColors.accent),
      label: Text('$colors · $tag',
          style: TextStyle(color: DecantColors.onSurface)),
      backgroundColor: DecantColors.ink.withValues(alpha: 0.06),
      side: BorderSide.none,
      onPressed: onTap,
    );
  }
}

/// Paste a code; closes with its tubes once it's valid.
class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _text = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _open() {
    final tubes = CustomLevel.decode(_text.text);
    if (tubes == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(tubes);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      backgroundColor: DecantColors.panel.first,
      title: Text(l.editorEnterCode,
          style: TextStyle(color: DecantColors.onSurface)),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLines: 3,
        minLines: 1,
        style: TextStyle(color: DecantColors.onSurface),
        decoration: InputDecoration(
          hintText: l.editorCodeHint,
          errorText: _invalid ? l.editorInvalidCode : null,
        ),
        onSubmitted: (_) => _open(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.notNow),
        ),
        TextButton(onPressed: _open, child: Text(l.editorOpen)),
      ],
    );
  }
}
