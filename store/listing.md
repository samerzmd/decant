# Google Play listing

Copy for the Play Console's **Main store listing**, plus the assets in this
folder. Character limits are Play's.

## App name (30 max)

Decant: Water Sort Puzzle

## Short description (80 max)

Relaxing water sort puzzle: pour colors into glass tubes. A new level every day.

## Full description (4000 max)

Decant is a calm water sort puzzle. Pour colored liquid between glass tubes until every tube holds a single color. No timers unless you want them, no pop-up ads, no pressure. Just you, a few glass tubes and a quiet soundtrack.

HOW TO PLAY
• Tap a tube to pick up the color on top.
• Tap another tube to pour. Liquid lands on the same color or in an empty tube.
• Sort every tube into one color to finish the level. Fewer moves earn more stars.

A NEW PUZZLE EVERY DAY
• Daily challenge: one level a day, the same for everyone, easy on Monday and hardest on Sunday.
• Keep your daily streak going, with an optional reminder at the hour you choose.
• Share your result with friends, and see how you rank on the daily leaderboard.

ENDLESS LEVELS, ALWAYS SOLVABLE
• Infinite levels in chapters of 20, each with its own background, every one guaranteed solvable.
• Star targets and a perfect badge for solving in par.
• Undo as many pours as you like, restart, use a hint or add an empty tube.
• 22 achievements in bronze, silver and gold.

MORE WAYS TO PLAY
• Zen mode hides moves and stars. Just pour.
• Challenges: Move limit (no undo) and Against the clock.
• Level editor: build your own puzzle, check it's solvable and share it as a code.

MADE TO UNWIND
• Glass tubes that tip and pour, with a falling stream, a gentle splash and light that plays through the glass.
• Pour sounds that rise in pitch as the tube fills.
• 54 ambient soundscapes and 54 music tracks, each with its own volume.

PLAY YOUR WAY
• Themes: Twilight, Midnight, Daylight and High contrast.
• Colorblind-friendly palettes and symbols, so colors never rely on color alone.
• Works offline. Optional cloud save with Google sign-in to continue on another device.
• Phone, tablet and landscape layouts. English, Spanish, French and German.
• Pour speed, reduce motion, haptics and keep screen awake settings.

FAIR AND FREE
• No in-app purchases, no banners and no ads between levels.
• Out of hints? You can choose to watch a short video for one. Nothing plays unless you tap it.
• Decant is open source on GitHub.

Relaxing water sort, color sort and liquid sort puzzles for every day.

## Categorization

- **App or game:** Game
- **Category:** Puzzle
- **Tags (pick up to 5):** Puzzle, Casual, Relaxing, Sorting, Offline

## Graphics

| Asset | File | Play requirement |
|---|---|---|
| App icon | `../branding/decant_icon.png` (1024×1024, scale to 512×512) | 512×512 PNG |
| Feature graphic | `feature_graphic.jpg` (1024×500, no alpha) | 1024×500 JPEG or 24-bit PNG |
| Phone screenshots | `screenshots/phone/01–08` (1440×2880) | 2–8, 9:16 to 2:1 |

Screenshot order and suggested captions:

1. `01_home.png`: Pour. Sort. Unwind.
2. `02_gameplay.png`: Sort every tube into one color
3. `03_levels.png`: Endless levels, always solvable
4. `04_achievements.png`: 22 achievements to earn
5. `05_level_editor.png`: Build and share your own puzzles
6. `06_stats.png`: Track your stars and streak
7. `07_settings.png`: Zen mode, pour speed and four themes
8. `08_sounds.png`: 54 music tracks, 54 soundscapes

The feature graphic is rendered from the in-app logo painter with
`fvm flutter test tool/render_store_test.dart`, then converted to JPEG with
`sips -s format jpeg store/feature_graphic.png --out store/feature_graphic.jpg`.

To retake the screenshots: install a release build on a phone and capture with
`adb exec-out screencap -p`. Then crop the status and navigation bars to 2:1,
for example `sips -c 2880 1440 --cropOffset 116 0` on a 1440×3088 screen.

## App content (Policy section)

- **Privacy policy URL:** the GitHub URL of [`PRIVACY.md`](../PRIVACY.md)
- **Ads:** Yes (optional rewarded videos for a hint, AdMob)
- **Target audience:** 13 and over is the simplest choice. Picking ages under 13
  brings in Families policy, which restricts analytics SDKs.
- **Content rating:** answer the IARC questionnaire. No violence, no user
  interaction or sharing, no gambling, so expect Everyone / PEGI 3.

### Data safety answers

Decant uses Google Analytics for Firebase. Based on what the app logs:

- **Does the app collect or share user data?** Yes, collected (not shared).
- **Data types:**
  - *App activity → App interactions*: level start/complete, stars, moves,
    hints, tutorial and screen views. Used for **Analytics**.
  - *Device or other IDs*: the Firebase app-instance ID and the advertising ID.
    Used for **Analytics**.
- **Advertising ID declaration:** Yes, for **Analytics** only. Firebase
  Analytics adds the `AD_ID` permission to the manifest.
- **Is data encrypted in transit?** Yes.
- **Can users request deletion?** Data is tied to a random app-instance ID, not
  an account. Uninstalling resets it; Analytics data expires on Google's
  retention schedule.
- **Is collection optional?** No (there's no in-app opt-out today).
- Progress, stats and settings stay on the device and are not collected.
