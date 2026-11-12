import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'log.dart';

/// Which rewarded ad unit to use.
///
/// Release builds take the real unit from
/// `--dart-define=ADMOB_REWARDED_ID=ca-app-pub-…`. Without it a release build
/// shows no ads at all, so a test ad never ships. Debug and profile builds fall
/// back to Google's public test units.
class AdConfig {
  static const _rewardedId = String.fromEnvironment('ADMOB_REWARDED_ID');

  /// Google's sample rewarded units, safe to load as often as you like.
  static const testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  static String? get rewardedUnitId {
    if (_rewardedId.isNotEmpty) return _rewardedId;
    if (kReleaseMode || kIsWeb) return null;
    return Platform.isIOS ? testRewardedIos : testRewardedAndroid;
  }
}

/// Rewarded video ads: the player can watch one for a hint when the pool is
/// empty.
///
/// It asks for consent first (Google's consent form, shown only where the law
/// needs it, such as the EEA and the UK), then keeps one ad loaded so it plays
/// at once. Every call is a safe no-op when ads are off ([AdService.off], used
/// in tests) or before [init] succeeds.
class AdService {
  final String? _unitId;
  RewardedAd? _rewarded;
  bool _ready = false;
  bool _loading = false;
  bool _privacyOptionsRequired = false;
  int _failures = 0;
  Timer? _retry;

  AdService({String? unitId}) : _unitId = unitId ?? AdConfig.rewardedUnitId;

  /// No ads: the button never offers a video.
  AdService.off() : _unitId = null;

  /// Whether this build shows ads at all.
  bool get enabled => _unitId != null;

  /// A video is loaded and can play now.
  bool get rewardedReady => _rewarded != null;

  /// The player must be able to change their consent (Settings shows the
  /// "Ad privacy choices" row).
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  Future<void> init() async {
    if (!enabled || _ready) return;
    try {
      await _gatherConsent();
      _privacyOptionsRequired = await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      if (!await ConsentInformation.instance.canRequestAds()) {
        Log.d('Ads', 'consent not given yet; ads stay off');
        return;
      }
      await _start();
    } catch (e) {
      Log.w('Ads', 'init failed (ads off)', e);
    }
  }

  Future<void> _start() async {
    await MobileAds.instance.initialize();
    _ready = true;
    _load();
  }

  /// Refreshes consent info and shows the consent form if it's needed.
  Future<void> _gatherConsent() {
    final done = Completer<void>();
    void finish([Object? error]) {
      if (error != null) Log.w('Ads', 'consent', error);
      if (!done.isCompleted) done.complete();
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired(
          (error) => finish(error?.message)),
      (error) => finish(error.message),
    );
    return done.future;
  }

  /// Opens Google's form to change ad consent, then starts ads if they're now
  /// allowed.
  Future<void> showPrivacyOptions() async {
    if (!enabled) return;
    try {
      final done = Completer<void>();
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) Log.w('Ads', 'privacy options', error.message);
        if (!done.isCompleted) done.complete();
      });
      await done.future;
      if (!_ready && await ConsentInformation.instance.canRequestAds()) {
        await _start();
      }
    } catch (e) {
      Log.w('Ads', 'privacy options failed', e);
    }
  }

  void _load() {
    if (!_ready || _loading || _rewarded != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _unitId!,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _failures = 0;
          _rewarded = ad;
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          _failures++;
          Log.w('Ads', 'rewarded load failed', error.message);
          // Back off: 30 s, 60 s, 120 s … up to 10 minutes.
          final wait =
              Duration(seconds: (15 << _failures.clamp(1, 6)).clamp(30, 600));
          _retry?.cancel();
          _retry = Timer(wait, _load);
        },
      ),
    );
  }

  /// Plays the loaded video. Completes with true only when the player watched
  /// enough to earn the reward; false if none was ready, it failed, or they
  /// closed it early.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      _load();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final closed = Completer<bool>();
    void finish(RewardedAd ad) {
      ad.dispose();
      if (!closed.isCompleted) closed.complete(earned);
      _load();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: finish,
      onAdFailedToShowFullScreenContent: (ad, error) {
        Log.w('Ads', 'rewarded show failed', error.message);
        finish(ad);
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => earned = true);
    return closed.future;
  }

  void dispose() {
    _retry?.cancel();
    _rewarded?.dispose();
    _rewarded = null;
  }
}
