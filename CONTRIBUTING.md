# Contributing to Decant

Thanks for your interest in **Decant** — *Pour. Sort. Unwind.* Contributions of
all kinds are welcome: bug reports, gameplay tuning, new ambient sounds, themes,
translations, docs, and code.

## Getting set up

You'll need the Flutter SDK (3.22+) and Dart 3.3+.

```bash
git clone https://github.com/<your-username>/decant.git
cd decant
flutter create .            # generate android/ and ios/ scaffolding (non-destructive)
flutter pub get
dart run flutter_launcher_icons          # branded launcher icon
dart run flutter_native_splash:create    # branded splash
flutter run
```

The Python scripts in `tool/` (used to (re)generate audio and brand art) need
`numpy`/`Pillow`:

```bash
pip3 install numpy Pillow
```

## Project layout

See the **Project structure** section of the [README](README.md). The golden
rule: **game logic stays pure**. Everything in `lib/models/` and `lib/logic/`
must be free of Flutter imports so it remains unit-testable in isolation.

## Before you open a PR

```bash
dart format .            # format
flutter analyze          # lint (uses flutter_lints, see analysis_options.yaml)
flutter test             # unit + widget tests must pass
```

CI runs the same checks on every PR (`.github/workflows/ci.yml`).

- Keep PRs focused; one logical change per PR.
- Add/update tests for logic changes (`test/`). The pour engine, solver and
  level generator are covered — please keep them green.
- For algorithm changes, the Python reference in `tool/verify_algorithm.py`
  should still pass (`python3 tool/verify_algorithm.py`).
- Changed how tubes or the pour are drawn on purpose? Refresh the painter
  goldens with `flutter test --update-goldens test/painter_golden_test.dart`
  and check the new images in `test/goldens/` before committing them.
- See coverage locally with `flutter test --coverage` then
  `tool/ci/coverage_summary.sh`. CI posts the same summary on every run.
- Log through `Log` (`lib/services/log.dart`), not `print`/`debugPrint`. It is
  silent in release builds; build with `--dart-define=DECANT_LOG=true` to see
  logs from a release build.
- Match the existing style: small widgets, `const` where possible, single
  quotes, comments that explain *why* not *what*.

## Adding levels

Levels are **procedural** — you don't hand-author them. Tune the difficulty
curve in `lib/logic/level_generator.dart` → `LevelGenerator.configFor()`. Every
generated board is guaranteed solvable (reverse-shuffle + solver validation).

## Adding / changing sounds

Edit `tool/generate_sounds.py` (add a `make_*` function + a `save(...)` call),
re-run it, then register the asset:

- One-shots: add to the `Sfx` enum + `_sfxAssets` map in
  `lib/audio/audio_service.dart` and trigger it from `GameController`.
- Ambient beds: add a recipe + a `CATALOG` row in `tool/ambient_library.py`,
  then run `python3 tool/generate_ambient.py <id>`. That renders the `.ogg`
  and regenerates `lib/audio/ambient_catalog.g.dart` (no Dart edits needed).

All shipped sounds are synthesized originals released as CC0. If you contribute
sourced audio instead, it must be CC0/public-domain and documented in the
README license table.

## Reporting bugs

Open an issue with: device + OS version, Flutter version (`flutter --version`),
steps to reproduce, and logs if it's a crash/freeze. Rendering or audio issues
on specific devices are especially useful — include the model.

## License

By contributing you agree your contributions are licensed under the project's
[Beerware license](LICENSE). 🍺
