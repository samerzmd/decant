# Decant — Roadmap

*Pour. Sort. Unwind.*

This is a living document of where Decant is and where it's headed. Items are
roughly ordered by priority within each milestone; nothing here is a promise of
a date. Ideas and PRs against any of these are very welcome — see
[CONTRIBUTING.md](CONTRIBUTING.md).

Legend: ✅ done · 🔜 next · 💡 idea/exploring

---

## ✅ v1.0 — Shipped

The calm, complete core game.

- [x] Classic water-sort engine (pure, unit-tested)
- [x] Undo (multi-step), restart, hint engine, add-empty-tube power-up
- [x] Infinite, always-solvable procedural levels + difficulty ramp
- [x] Stuck-state detection
- [x] 2.5-D glass rendering (CustomPainter + GLSL glass shader, Skia fallback)
- [x] Pour animation (arc stream, tilt, rising liquid, splash, wobble)
- [x] 8 synthesized CC0 SFX with fill-level pitch shift
- [x] 5 selectable ambient beds + independent volume mixer
- [x] Haptics, colorblind symbol mode, persistent progress & settings
- [x] Branded icon / splash / in-app logo (layered-tube mark, themed icon)
- [x] Lifecycle-aware audio, fast startup, single seamless splash
- [x] Exit/leave confirmation dialogs

---

## ✅ v1.1 — Polish & foundations

Tighten the release and lay groundwork for the community.

- [x] Keep debug `debugPrint`s out of release builds (all behind `kDebugMode`)
- [x] A proper logging toggle (`Log`: on in debug, off in release, back on
      with `--dart-define=DECANT_LOG=true`)
- [x] Re-evaluate Impeller vs Skia now that the freeze cause is fixed:
      Impeller (Vulkan) is back on for Android, since Flutter is removing the
      Skia opt-out. Verified on a Galaxy S22 Ultra across resume, exit/reopen
      and process death
- [x] Move `MainActivity.kt` to its package-matching folder
- [x] Expand widget/golden tests; wire coverage reporting into CI (painter
      goldens, screen tests, coverage summary on every CI run: 81%)
- [x] Settings: pour-animation speed, reduce-motion option
- [x] A simple **stats** screen (levels solved, stars, perfect levels, wins,
      daily streak)
- [x] In-app "how to play" / first-run tutorial overlay
- [x] Realistic pouring: the tube flies over and tips on its lip, the liquid
      stays level and drains, and a falling stream splashes into the target
- [x] App store assets (screenshots, feature graphic, store listing copy) in
      `store/`, plus a privacy policy (`PRIVACY.md`)

## 🔜 v1.2 — Modes & replayability

Give players reasons to come back.

- [x] **Daily challenge**: one seeded level per local day, the same for
      everyone, easiest on Monday and hardest on Sunday, with its own streak
- [ ] **Zen mode** (no move counter, no stars — pure unwind)
- [ ] **Challenge modes**: move-limited and timed variants
- [ ] Per-level star tuning + "perfect" (no-hint) badges
- [ ] Hint economy / cooldown so hints feel earned (optional)
- [ ] Level packs / chapters with themed palettes

## 💡 v1.3 — Accessibility & reach

- [ ] Localization (i18n) scaffolding + first translations
- [ ] Dynamic type / larger-text support audit
- [ ] Additional colorblind palettes and a high-contrast theme
- [ ] Theme system (light/dark + a few calm palettes), pluggable via a provider
- [ ] More ambient beds (soft wind, distant thunder, night, café) + crossfade
      when switching tracks
- [ ] Tablet / large-screen and landscape layouts

## 💡 v2.0 — Social & creation (exploratory)

Bigger bets, only if the community wants them.

- [ ] Cloud save / cross-device sync
- [ ] Leaderboards & shareable daily results
- [ ] **Level editor** + share-by-code/QR
- [ ] Achievements
- [ ] Flutter **web** build (playable demo) and desktop targets
- [ ] Richer 3D pass (real refraction, caustics) where performance allows

---

## 🛠️ Ongoing / infrastructure

- [x] GitHub Actions CI: format + analyze + test + algorithm verifier
      (`.github/workflows/ci.yml`, Flutter pinned via `.fvmrc`)
- [ ] Release automation (tagged builds, CHANGELOG enforcement)
- [ ] Publish to Google Play and the App Store; explore F-Droid
- [ ] Issue/PR templates and a `good first issue` set for newcomers

## ⚠️ Known limitations / tech debt

- Impeller was once disabled on Android over a Samsung surface-recreation
  freeze. It's back on and passes on an S22 Ultra; watch for reports from
  other devices (older Mali/PowerVR GPUs in particular).
- `flutter_soloud` is fully torn down on `detached` to survive Activity
  recreation; verify this plays nicely across the OEM matrix.
- Ambient loops use `LoadMode.disk`; if any device misbehaves on resume,
  in-memory loading is the fallback (startup is already deferred, so it's cheap).
- Painter goldens are made on macOS and checked on Linux CI with a small
  pixel tolerance; refresh them with `flutter test --update-goldens` after an
  intended visual change.

---

Have an idea that isn't here? Open an issue and let's talk. 🍺
