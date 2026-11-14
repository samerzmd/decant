import 'package:flutter/foundation.dart';

/// Whether this is the phone app (Android or iOS).
///
/// Firebase (analytics, cloud save, leaderboard), ads, streak reminders, QR
/// scanning and the extra sound packs are phone-only; the web and desktop
/// builds are the plain offline game. Uses [defaultTargetPlatform], so widget
/// tests (which report Android) see the phone app.
bool get isPhone =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
