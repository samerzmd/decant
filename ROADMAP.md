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

## ✅ v1.2 — Modes & replayability

Give players reasons to come back.

- [x] **Daily challenge**: one seeded level per local day, the same for
      everyone, easiest on Monday and hardest on Sunday, with its own streak
- [x] **Zen mode**: a setting that hides the move counter and stars; levels
      still count as solved and unlock the next one
- [x] **Challenge modes**: Move limit (no undo) and Against the clock, each an
      endless ladder of stages with the best stage saved
- [x] Per-level star targets shown while playing, and a "perfect" badge for
      solving in par with no hints or extra tube
- [x] Hint economy: a pool of hints (start 3, hold 5), one earned back per
      solve; unlimited in Zen mode
- [x] Optional rewarded video (AdMob) for a hint when the pool is empty, with
      Google's consent form where the law needs it
- [x] Chapters of 20 levels with themed backgrounds (Dawn, Tide, Ember, Grove,
      Dusk, Aurora), shown as sections on the level grid
- [x] Streak reminders: an opt-in local notification at a chosen hour when
      today's daily isn't solved, naming the streak at stake

## ✅ v1.3 — Accessibility & reach

- [x] Localization (i18n) scaffolding + first translations: gen-l10n ARB
      files with Spanish, French and German, and a Language setting. Sound and
      track names are still English only.
- [x] Dynamic type / larger-text support audit: every screen is checked at
      1.5× and 2× text, and in German, on a small phone.
- [x] Additional colorblind palettes and a high-contrast theme
- [x] Theme system (Twilight, Midnight, High contrast, Daylight) set in
      Settings. Every screen draws from theme tokens, and a test checks WCAG
      contrast for each theme.
- [x] More ambient beds + crossfade when switching tracks (the 50+ sound
      catalog, now with a 1.5 s crossfade)
- [x] Tablet / large-screen and landscape layouts: rotation unlocked, menus
      keep a readable width, the level grid widens

## 💡 v2.0 — Social & creation (exploratory)

Bigger bets, only if the community wants them.

- [x] Cloud save / cross-device sync: optional Google sign-in in Settings,
      progress merged and kept in Firestore (v1.5.0)
- [x] Leaderboards & shareable daily results: a Share button on the daily
      win card, and a daily leaderboard (fewest moves) for signed-in players
- [x] **Level editor** + share-by-code (`DCT1-…` codes, My levels), shown
      as a QR code and scannable in the app
- [x] Achievements: 22 tiered badges derived from progress, with toasts
- [x] Flutter **web** build (playable demo) and **desktop** apps for macOS,
      Windows and Linux, built in CI and attached to each release
- [x] Richer 3D pass: Fresnel rims, wall thickness, bounce light and
      caustics in the glass shader. True refraction (sampling the liquid
      behind the glass) is still open; it needs an offscreen pass per tube.

---

## 🛠️ Ongoing / infrastructure

- [x] GitHub Actions CI: format + analyze + test + algorithm verifier
      (`.github/workflows/ci.yml`, Flutter pinned via `.fvmrc`)
- [x] Release automation: a `v*` tag builds the signed bundle and publishes
      a GitHub release with the CHANGELOG notes; CI requires notes for the
      pubspec version
- [x] Publish to Google Play (live since v1.3)
- [ ] Publish to the App Store; explore F-Droid
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
