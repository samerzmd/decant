# Changelog

All notable changes to Decant are documented here. The format loosely follows
[Keep a Changelog](https://keepachangelog.com/), and the project aims to follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.6.0] — 2026-11-13

### Added
- Share your daily result: a Share button on the daily win card sends your
  stars, moves and streak, with a link to the game.
- Daily leaderboard: signed-in players are ranked by fewest moves on each
  day's daily, under a friendly random name like "Teal Otter 42".
- Achievements: 22 badges (levels, stars, perfect solves, dailies, streaks,
  challenge stages) in bronze, silver and gold, with a toast when you earn
  one. Worked out from your progress, so cloud save carries them too.
- Level editor: build a puzzle, check that it's solvable, play it, and share
  it as a code friends can paste into Create → Enter a code. Your last 20
  puzzles are kept under My levels.
- A playable web build (no sign-in, ads or leaderboard there).

### Changed
- Richer glass: Fresnel rims, visible wall thickness, a soft second
  reflection and shimmering caustics at the base of every tube.
- Buttons side by side no longer cut their labels off ("Rep…").

## [1.5.0] — 2026-11-13

### Added
- Optional cloud save. Sign in with Google in Settings → Cloud save to back
  up your progress and continue on another device. Progress from two
  devices is merged, so nothing either one earned is lost. You can sign out
  or delete the cloud copy and account at any time; the game works exactly
  as before without signing in.

## [1.4.2] — 2026-11-13

### Changed
- In-game messages, such as "No moves left" or "No video is ready", now
  appear as a card in the app's own colours with an icon, floating above
  the buttons instead of covering them.

## [1.4.1] — 2026-11-12

### Fixed
- Four-digit levels showed as "Level 10…" on narrow phones. The game
  header now shows the full level number, with the chapter name on the
  line underneath.

## [1.4.0] — 2026-11-12

### Added
- Out of hints? Watch a short, optional video for one (Google AdMob rewarded
  ads). Nothing plays unless you choose to, Zen mode and challenge ladders
  never offer it, and players in the EEA and UK are asked for consent first,
  with "Ad privacy choices" in Settings to change it.

## [1.3.1] — 2026-11-12

### Added
- Daylight, a light theme. Every screen now draws its colors from theme
  tokens, and a test checks text contrast for each theme.
- Release automation: pushing a `v*` tag builds the signed app bundle and
  publishes a GitHub release with these notes.

## [1.3.0] — 2026-11-11

### Added
- A new, game-like home screen with a bobbing tube shelf, chapter progress
  and big Play, Daily and Challenges cards.
- Daily challenge: one seeded level per day, the same for everyone, with its
  own streak.
- Streak reminders: an opt-in notification at a chosen hour when today's
  daily isn't solved. The app offers them after a few wins.
- Zen mode, which hides moves and stars.
- Challenge modes: Move limit (no undo) and Against the clock.
- Star targets while playing, and a perfect badge.
- A hint pool: start with 3, hold up to 5, earn one back per solve.
- Chapters of 20 levels with themed backgrounds.
- Themes (Twilight, Midnight, High contrast) and colorblind-safe and
  high-contrast liquid palettes.
- Spanish, French and German, with a Language setting.
- Tablet and landscape layouts.
- A 1.5 s crossfade when switching ambience tracks.

### Fixed
- A crash in release builds while playing.
- Text overflow at large system text sizes.

## [1.1.0] — 2026-11-10

### Added
- A stats screen, pour speed and reduce motion settings, and a first-run
  guide.
- Realistic pouring: the tube tips over the target and the liquid drains.
- 54 ambience sounds and 54 music tracks, the extra ones delivered by
  Google Play asset packs.
- A Keep screen awake setting.

### Changed
- Impeller is back on for Android.
- Logging goes through one switchable logger, off in release builds.

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
