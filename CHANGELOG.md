# Changelog

All notable changes to Decant are documented here. The format loosely follows
[Keep a Changelog](https://keepachangelog.com/), and the project aims to follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

- See [ROADMAP.md](ROADMAP.md) for what's planned next.

## [1.0.0] — 2026-05-30

First public release. 🍺

### Gameplay
- Classic water-sort mechanics (tap source → tap destination; whole top run
  pours; capacity 4).
- Multi-step undo, restart, optimal-move hint engine, and a limited
  "add empty tube" power-up.
- Procedural, **infinite**, always-solvable levels (reverse-shuffle + solver
  validation) with a difficulty ramp and an unbounded level-select grid.
- Stuck-state detection with undo / restart / add-tube prompts.

### Visuals
- 2.5-D glass tubes via `CustomPainter`: rounded-bottom glass, rim/mouth light,
  meniscus, gloss, bubbles, soft shadows, and a GLSL glass-highlight overlay
  (with a graceful Skia/gradient fallback).
- Pour animation: arcing stream, tube tilt, rising liquid, splash, settling
  wobble.
- Sophisticated launcher icon, native splash, and in-app logo (glowing glass
  tube + droplet).

### Audio & haptics
- Eight synthesized CC0 sounds; pour pitch rises with fill level.
- Five selectable ambient beds (Twilight Pad, Rain, Ocean, Stream, Fireplace).
- Haptics synced to pour / droplet / completion / win.
- Independent SFX / ambience / music volumes, mute, ambient toggle.

### UX / platform
- Riverpod state with pure, testable game logic.
- Persistent progress + settings (`shared_preferences`).
- Confirmation dialogs on leaving a level and exiting the app.
- Lifecycle-aware audio (silences in background, rebuilds on relaunch).
- Fast startup (audio loads after first frame) and a single, seamless splash.
- Colorblind-friendly symbol mode.
