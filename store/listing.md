# Google Play listing

Copy for the Play Console's **Main store listing**, plus the assets in this
folder. Character limits are Play's.

## App name (30 max)

Decant: Water Sort Puzzle

## Short description (80 max)

Pour, sort and unwind. A calm water-sort puzzle with soothing sound.

## Full description (4000 max)

Decant is a calm puzzle about pouring colored liquid between glass tubes until
every tube holds a single color. No timers, no ads, no pressure. Just you, a
few glass tubes and a quiet soundtrack.

HOW TO PLAY
• Tap a tube to pick up the color on top.
• Tap another tube to pour. Liquid lands on the same color or in an empty tube.
• Sort every tube into one color to finish the level. Fewer moves earn more
  stars.

MADE TO UNWIND
• Glass tubes with rising liquid, a pouring stream and a gentle wobble.
• Pour sounds that rise in pitch as the tube fills.
• 54 ambient soundscapes and 54 music tracks, each with its own volume.
• A first-run guide that teaches the game on a real level.

ALWAYS A WAY FORWARD
• Endless levels that ramp up gently, every one guaranteed solvable.
• Undo as many pours as you like, or restart.
• Hints when you're stuck, and an extra empty tube when you need room.

YOUR PACE
• Stats: levels solved, stars, perfect levels and a daily streak.
• Pour speed: Relaxed, Normal or Quick.
• Reduce motion for calmer visuals (also follows your system setting).
• Colorblind symbols, so colors never rely on color alone.
• Haptics, and an option to keep the screen awake while you play.

No ads. No in-app purchases. Your progress stays on your device.

## Categorization

- **App or game:** Game
- **Category:** Puzzle
- **Tags (pick up to 5):** Puzzle, Casual, Relaxing, Sorting, Offline

## Graphics

| Asset | File | Play requirement |
|---|---|---|
| App icon | `../branding/decant_icon.png` (1024×1024, scale to 512×512) | 512×512 PNG |
| Feature graphic | `feature_graphic.jpg` (1024×500, no alpha) | 1024×500 JPEG or 24-bit PNG |
| Phone screenshots | `screenshots/phone/01–06` (1440×2880) | 2–8, 9:16 to 2:1 |

Screenshot order and suggested captions:

1. `01_home.png`: Pour. Sort. Unwind.
2. `02_gameplay.png`: Sort every tube into one color
3. `03_pour.png`: Smooth pours and soothing sound
4. `04_how_to_play.png`: Learn as you play
5. `05_stats.png`: Track your stars and streak
6. `06_sounds.png`: 54 music tracks, 54 soundscapes

The feature graphic is rendered from the in-app logo painter with
`fvm flutter test tool/render_store_test.dart`, then converted to JPEG with
`sips -s format jpeg store/feature_graphic.png --out store/feature_graphic.jpg`.

To retake the screenshots: install a release build on a phone and capture with
`adb exec-out screencap -p`. Then crop the status and navigation bars to 2:1,
for example `sips -c 2880 1440 --cropOffset 116 0` on a 1440×3088 screen.

## App content (Policy section)

- **Privacy policy URL:** the GitHub URL of [`PRIVACY.md`](../PRIVACY.md)
- **Ads:** No
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
  - *Device or other IDs*: the Firebase app-instance ID. Used for **Analytics**.
- **Is data encrypted in transit?** Yes.
- **Can users request deletion?** Data is tied to a random app-instance ID, not
  an account. Uninstalling resets it; Analytics data expires on Google's
  retention schedule.
- **Is collection optional?** No (there's no in-app opt-out today).
- Progress, stats and settings stay on the device and are not collected.
