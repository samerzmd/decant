# Decant

**Pour. Sort. Unwind.**

![platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-49D6C3)
![Flutter](https://img.shields.io/badge/Flutter-3.22%2B-02569B?logo=flutter)
![license](https://img.shields.io/badge/license-Beerware%20%F0%9F%8D%BA-F2913D)
![status](https://img.shields.io/badge/status-v1.0-54B86B)

A calm, polished **water sort puzzle** for Android and iOS, built in Flutter. Tap a tube to lift it, tap another to pour — sort every color into its own glass. Decant pairs a 3D-styled glass-and-liquid look (custom painting + a GLSL glass shader) with original, synthesized **ASMR** sound and synced haptics.

> Roadmap: see [ROADMAP.md](ROADMAP.md) · Contributing: see [CONTRIBUTING.md](CONTRIBUTING.md) · Changes: see [CHANGELOG.md](CHANGELOG.md)

---

## Features

- Classic water-sort rules: pour onto a matching top color or into an empty tube, the whole top run moves at once, tubes hold 4 segments.
- Multi-step **undo**, **restart**, an **optimal-move hint** engine, and a limited **"add empty tube"** power-up.
- **Procedurally generated, always-solvable levels** with difficulty that ramps from 3 colors up to 11. Deterministic per level number, so progress is stable across devices.
- Auto-detection of **stuck** boards, with a prompt to undo / restart / add a tube.
- **3D glass visuals**: rounded-bottom glass cylinders, rim and mouth lighting, soft drop shadows, layered liquid with a rounded **meniscus**, glossy reflections, rising bubbles, and a GLSL highlight overlay.
- **Pour animation**: arcing liquid stream, source-tube tilt, rising liquid in the destination, splash droplets, and a settling wobble on landing.
- **ASMR audio** (all synthesized, see below): looping water trickle (pitch rises as a tube fills), droplet plink, glass clink, glug, completion chime, combo cascade, win jingle, and a toggleable, **selectable ambient bed** (Twilight Pad, Rain, Ocean, Stream, Fireplace).
- **Haptics** synced to pour start, droplet landing, tube completion, and the win.
- Settings: separate volume sliders for SFX / ambience / music, a mute toggle, ambient on/off, haptics toggle, and a **colorblind-friendly** mode (distinct symbols on every color).
- Persistent progress, best stars, and settings via `shared_preferences`.

---

## Project structure

```
decant/
├── lib/
│   ├── main.dart                  # Entry point: boots audio + persistence, then runApp
│   ├── models/                    # Pure, framework-free data (testable without Flutter)
│   │   ├── liquid_color.dart      #   palette ids + colorblind symbols
│   │   ├── tube.dart              #   a glass tube (immutable)
│   │   ├── move.dart              #   one pour (for undo / hints)
│   │   ├── game_state.dart        #   board + history + power-ups
│   │   ├── level.dart             #   a level definition
│   │   ├── level_result.dart      #   best stars / moves
│   │   └── app_settings.dart      #   audio + haptics + accessibility
│   ├── logic/                     # Pure game logic
│   │   ├── pour_engine.dart       #   pour rules, undo, stuck detection
│   │   ├── solver.dart            #   best-first solver → hints + level validation
│   │   └── level_generator.dart   #   reverse-shuffle generator (guaranteed solvable)
│   ├── audio/
│   │   ├── audio_service.dart     #   flutter_soloud engine wrapper (pitch-shifting pour)
│   │   └── haptic_service.dart
│   ├── services/
│   │   └── persistence_service.dart
│   ├── state/                     # Riverpod
│   │   ├── providers.dart
│   │   ├── settings_controller.dart
│   │   ├── progress_controller.dart
│   │   ├── game_session.dart
│   │   └── game_controller.dart   #   selection, pouring, audio/haptic orchestration
│   └── ui/
│       ├── theme/                 #   colors, gradient, palette
│       ├── painters/              #   tube_painter.dart, pour_stream_painter.dart
│       ├── widgets/               #   tube, board, buttons, logo, win overlay, stars
│       └── screens/               #   splash, home, level select, game, settings
├── shaders/glass.frag             # GLSL glass-cylinder highlight overlay
├── assets/sounds/                 # 8 synthesized CC0 WAVs (see license table)
├── tool/
│   ├── generate_sounds.py         # regenerates every sound asset
│   └── verify_algorithm.py        # Python port that proves the logic invariants
├── test/                          # unit + widget tests
└── pubspec.yaml
```

---

## Setup & run

> Requires the Flutter SDK (3.22+) and Dart 3.3+.

This repository ships the Dart source, assets, shader, and tests. Generate the
platform folders (`android/`, `ios/`, etc.) once with `flutter create`, then run:

```bash
cd decant

# 1. Generate platform projects without touching lib/, assets, or pubspec:
flutter create .

# 2. Fetch dependencies:
flutter pub get

# 3. Generate the branded launcher icon + native splash screen:
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# 4. Run on a connected device or emulator:
flutter run

# 5. Run the tests:
flutter test
```

`flutter create .` is non-destructive to existing files — it only adds the
missing native scaffolding. `flutter_soloud` builds its native audio engine
automatically through the normal plugin build.

---

## Branding (launcher icon & splash)

The default Flutter icon and white launch screen are replaced with Decant
branding. Source art lives in `branding/` and is regenerated by
`tool/generate_branding.py` (Pillow):

```bash
python3 tool/generate_branding.py        # rebuild the source PNGs
dart run flutter_launcher_icons          # write native launcher icons
dart run flutter_native_splash:create    # write the native launch screen
```

- `branding/decant_icon.png` — teal-gradient launcher icon with the white
  droplet-over-tube mark (iOS + legacy Android).
- `branding/decant_foreground.png` — the white mark with adaptive-icon safe-zone
  padding (Android adaptive foreground + Android 12 splash icon).
- `branding/decant_splash.png` — the white mark centered on the `#243156` brand
  background for the native splash.

Config lives in `pubspec.yaml` under `flutter_launcher_icons:` and
`flutter_native_splash:`. The in-app splash (`lib/ui/screens/splash_screen.dart`)
and the `DecantLogo` widget use the same mark so OS and in-app branding match.
Re-run the two `dart run` commands whenever you change the art or colors.

---

## Audio — sources & licenses

**Every sound in Decant is original and synthesized from scratch**, so the
entire set is released into the public domain under **CC0 1.0**. There are no
third-party samples. The generator is `tool/generate_sounds.py` (NumPy); re-run
it to regenerate or tweak any sound:

```bash
python3 tool/generate_sounds.py
```

| File                     | Trigger                                   | How it's synthesized                            | License |
|--------------------------|-------------------------------------------|-------------------------------------------------|---------|
| `water_pour_loop.wav`    | Looping while pouring (pitch ↑ as it fills) | Band-passed noise + flutter + bubble blips, seamless loop | CC0 1.0 |
| `droplet.wav`            | Droplet lands                             | Falling-pitch sine chirp + resonant ring        | CC0 1.0 |
| `glass_clink.wav`        | Tube tap / select                         | Inharmonic bell partials + noise transient      | CC0 1.0 |
| `glug.wav`               | Tube fills                                | Wobbling low sine + bubble pop                  | CC0 1.0 |
| `tube_complete.wav`      | A tube is solved                          | Two-note bell (C6→E6)                            | CC0 1.0 |
| `combo.wav`              | Consecutive tube completions              | Ascending bell arpeggio (C6 E6 G6 C7)           | CC0 1.0 |
| `win_jingle.wav`         | Puzzle solved                             | Bell melody over a soft pad                      | CC0 1.0 |
| `ambient_loop.wav`       | Ambient bed — **Twilight Pad** (default)  | Slow detuned drone + airy shimmer, seamless loop | CC0 1.0 |
| `ambient_rain.wav`       | Ambient bed — **Rain**                    | High-passed hiss + scattered droplet ticks + low rumble | CC0 1.0 |
| `ambient_ocean.wav`      | Ambient bed — **Ocean**                   | Low-passed surf swelling in/out over a deep rumble | CC0 1.0 |
| `ambient_stream.wav`     | Ambient bed — **Stream**                  | Soft mid-band water flow + lazy bubbles          | CC0 1.0 |
| `ambient_fireplace.wav`  | Ambient bed — **Fireplace**               | Brown-noise rumble + airy hiss + random crackle pops | CC0 1.0 |

The ambient bed is toggleable and the track is selectable in **Settings → Audio → Ambience sound**. To add another bed: write a `make_ambient_*` function in `tool/generate_sounds.py`, save it as `assets/sounds/ambient_<name>.wav`, then add a value to the `AmbientTrack` enum (label + asset path) in `lib/audio/audio_service.dart`.

Playback uses [`flutter_soloud`](https://pub.dev/packages/flutter_soloud) for
low latency and per-voice pitch control. Assets are preloaded at startup, so
there's no first-play lag.

> **Silent mode:** behavior follows the platform audio session. If you want the
> game to honor the iOS hardware mute switch, configure the SoLoud/AVAudioSession
> category for your build; the in-app **Mute** toggle always works.

---

## How to add levels

Levels are **generated procedurally**, so you don't hand-author boards — level
*N* always produces the same puzzle. Tune the curve in
`lib/logic/level_generator.dart` → `LevelGenerator.configFor(levelId)`:

- `colorCount` — number of colors (drives difficulty),
- `emptyTubes` — spare tubes at the start,
- `capacity` — segments per tube (default 4),
- `scrambleSteps` — how thoroughly the solved board is reverse-shuffled.

Generation works by starting from a solved board and applying **invertible
reverse pours**, so every level is guaranteed solvable; each board is also
double-checked with the solver. To show more levels in the grid, change
`LevelSelectScreen.kShownLevels`.

## How to add / change sounds

Edit `tool/generate_sounds.py` (add a `make_*` function and a `save(...)` call),
re-run it, then register the file:

1. Drop the `.wav` in `assets/sounds/` (it's already covered by the `assets/sounds/`
   entry in `pubspec.yaml`).
2. Add it to the `Sfx` enum + `_sfxAssets` map in `lib/audio/audio_service.dart`,
   and trigger it from `lib/state/game_controller.dart`.

If you'd rather source clips from a free library (Freesound CC0, Pixabay, etc.)
instead of synthesizing, drop them in `assets/sounds/` and **record each clip's
source and license in the table above**.

---

## Verifying the logic

The game logic is pure Dart and covered by `test/` (`flutter test`). Because the
core algorithm is framework-independent, `tool/verify_algorithm.py` is a faithful
Python port that independently proves the invariants — pour rules, color
conservation, determinism, and that every generated level is solvable and its
solver solution actually solves it:

```bash
python3 tool/verify_algorithm.py
```

---

## Architecture notes

- **Pure logic, testable in isolation.** `models/` and `logic/` import no Flutter,
  so the engine, solver, and generator run under plain `dart test` if desired.
- **Riverpod** wires logic to UI; `GameController` is the single place that maps
  player actions to state transitions and to audio/haptic cues.
- **Rendering** is `CustomPainter`-based for full control of the glass/liquid look,
  with an optional GLSL overlay (`shaders/glass.frag`) that degrades gracefully to
  a gradient if a platform can't compile it.

---

## Roadmap

Decant 1.0 is the complete, calm core game. Planned next: a daily challenge,
zen/timed modes, themes, localization, and more ambient beds. The full plan
lives in **[ROADMAP.md](ROADMAP.md)**.

## Contributing

Issues and PRs are welcome — gameplay tuning, sounds, themes, translations, and
docs especially. Start with **[CONTRIBUTING.md](CONTRIBUTING.md)**. The golden
rule: keep `lib/models/` and `lib/logic/` pure Dart so the engine stays
testable. CI runs `dart format`, `flutter analyze`, `flutter test`, and the
Python algorithm verifier on every PR.

## License

Released under the **[Beerware license](LICENSE)** (Revision 42) — do whatever
you want with it; if we meet someday and you think it's worth it, buy me a beer.
🍺

All bundled sounds (`assets/sounds/`) and brand art (`branding/`) are original
and dedicated to the public domain under **CC0 1.0**.
