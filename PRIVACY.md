# Decant privacy policy

*Last updated: 13 November 2026*

Decant is a single-player puzzle game with no in-app purchases. You can play
without an account; signing in is only needed for the optional cloud save. The
only ads are optional videos you can choose to watch for a hint when you have
none left.

## What stays on your device

Your progress (levels, stars, best moves), stats (wins and streak) and
settings are saved on your device. Unless you turn on cloud save, they are
never uploaded, and uninstalling Decant deletes them.

## Cloud save (optional)

If you choose **Sign in with Google** in **Settings → Cloud save**, Decant
backs up your progress so you can restore it after reinstalling or continue on
another device. Nothing is uploaded unless you sign in.

- **Sign-in** uses **Firebase Authentication** with your Google account. It
  receives your Google account ID, email address, name and profile picture
  link, and creates a Decant account ID for you.
- **Your progress** is stored in **Cloud Firestore** under that account ID:
  levels and their stars, best moves and perfect badges, the highest unlocked
  level, wins and streaks, daily challenge results from the last 60 days,
  challenge-mode best stages, and hints in your pool. Settings are not
  uploaded.
- Only you can read or change your saved progress. It is sent encrypted and
  handled by Google under
  [Google's privacy policy](https://policies.google.com/privacy).

**Deleting it:** in **Settings → Cloud save**, tap **Delete cloud save**. This
deletes your saved progress and your Decant account right away; progress on
your device stays. Signing out stops syncing but keeps the cloud copy. If you
can no longer open the app, ask for deletion by opening an issue at
<https://github.com/samerzmd/decant/issues> or by emailing
<samerzmd@gmail.com> from the Google account you signed in with.

## What is collected

Decant uses **Google Analytics for Firebase** to understand how the game is
played, so levels and features can be improved. It records:

- Gameplay events: a level started or finished, with its stars, move count and
  hints used; hints and extra tubes used; the how-to-play guide being started,
  finished or skipped.
- Which screens are opened.
- Information Firebase collects automatically, such as a random app-instance
  ID, the device's advertising ID, device model, OS version, app version and
  approximate country.

Analytics also records whether a hint video was watched through.

Apart from the optional cloud save sign-in above, Decant does not collect your
name, email, contacts, precise location or any other personal information.
Analytics is not linked to your cloud save account.

## Ads

When your hint pool is empty, Decant offers a short video ad in exchange for a
hint. Nothing plays unless you tap **Watch video**, and there are no banners
or ads between levels.

These videos come from **Google AdMob**. To show and measure them, AdMob
collects the device's advertising ID, IP address, device and app information,
and how you interact with the ad. Google may use this to show personalized ads
where you allow it. See
[how Google uses information from apps that use its services](https://policies.google.com/technologies/partner-sites).

If you are in the European Economic Area, the UK or Switzerland, Decant asks
for your consent before any ad is loaded, using Google's consent form. You can
change your choice at any time in **Settings → Privacy → Ad privacy choices**.

You can reset or delete your advertising ID at any time in your device's
settings (on Android: Settings → Privacy → Ads).

Data is sent encrypted to Google and handled under
[Google's privacy policy](https://policies.google.com/privacy). It is linked to
these device IDs, not to your name or account. Reinstalling the app resets the
app-instance ID.

## Children

Decant is not directed at children under 13 and does not knowingly collect
personal information from them.

## Changes

If this policy changes, the new version will be published here with a new
date.

## Contact

Questions: open an issue at <https://github.com/samerzmd/decant/issues>.
