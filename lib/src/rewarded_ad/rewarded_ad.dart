import '../ad_internal.dart';

/// A singleton class to manage loading and showing rewarded ads.
class RewardAd extends BaseAdLoader {
  /// Singleton instance of [RewardAd].
  static final RewardAd instance = RewardAd._internal();

  /// Factory constructor to provide access to the singleton [RewardAd].
  factory RewardAd() {
    return instance;
  }

  /// Private constructor for [RewardAd] singleton.
  RewardAd._internal();

  @override
  bool get isEnabled => shouldShowRewardedAd;

  @override
  String get adLabel => "Rewarded";

  @override
  bool get isAutoPreload => autoPreloadRewardedAd;

  RewardedAd? _rewardedAd; // Stores the loaded rewarded ad.

  /// Loads a rewarded ad with the given unit ID and configuration.
  @override
  void load() {
    if (!prepareLoad()) return;
    try {
      RewardedAd.load(
        adUnitId: unitIDRewarded, // ID for the rewarded ad unit.
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          // Called when the ad has successfully loaded.
          onAdLoaded: (ad) {
            AdStats.instance.rewardedLoad.value++; // Increment ad load count.
            _rewardedAd = ad;
            _rewardedAd!.setImmersiveMode(true); // Enable immersive mode.
            handleLoadSuccess();
          },
          // Called if the ad fails to load.
          onAdFailedToLoad: (LoadAdError error) {
            _rewardedAd = null;
            AdStats.instance.rewardedFailed
                .value++; // Increment ad load failure count.
            handleFailureAndRetry(error);
          },
        ),
      );
    } catch (error) {
      state = AdLoadState.failed;
      _rewardedAd?.dispose();
      _rewardedAd = null;
      handleFailureAndRetry(error);
    }
  }

  /// Shows the rewarded ad if it is loaded and the conditions are met.
  ///
  /// Returns true if an ad is being presented; false if [callBack] was
  /// already called because no ad was shown.
  bool showRewarded({
    required Function({RewardedAd? ad, AdError? error}) callBack,
    required Function(AdWithoutView ad, RewardItem reward) onReward,
  }) {
    incrementCounter();
    if (counter < getRewardedCounter) {
      callBack();
      return false;
    }

    if (shouldShowRewardedAd && _rewardedAd != null && isAdLoaded) {
      // Check if ad expired (AdMob 4-hour TTL rule)
      if (isExpired) {
        AppLogger.warn('Rewarded ad expired. Fetching fresh ad.');
        discardAd();
        if (isAutoPreload) load();
        callBack();
        return false;
      }

      resetCounter(); // Reset the counter after showing the ad.
      state = AdLoadState.showing;

      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) => FullScreenAdGuard.onShown(),
        onAdClicked: (_) => FullScreenAdGuard.onClicked(),
        // Called when the ad is dismissed.
        onAdDismissedFullScreenContent: (ad) {
          FullScreenAdGuard.onDismissed();
          callBack(ad: ad as RewardedAd?); // Callback after ad is dismissed.
          ad.dispose();
          _rewardedAd = null;
          state = AdLoadState.initial;
          if (isAutoPreload) load(); // Reload ad after dismissal.
        },
        // Called when the ad is shown (impression).
        onAdImpression: (ad) {
          AdStats.instance.rewardedImp.value++; // Increment impression count.
        },
        // Called if the ad fails to show.
        onAdFailedToShowFullScreenContent: (ad, error) {
          FullScreenAdGuard.onDismissed();
          callBack(ad: ad as RewardedAd?, error: error); // Callback on failure to show.
          AppLogger.error('$ad failed to show: $error');
          _rewardedAd = null;
          ad.dispose();
          state = AdLoadState.failed;
          if (isAutoPreload) load(); // Reload ad after failure.
        },
      );

      // Show the rewarded ad and handle the reward.
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          onReward(ad, reward); // Handle the reward when the user earns it.
        },
      );
    } else {
      if (isAutoPreload && !isAdLoaded && state != AdLoadState.loading) {
        load();
      }
      callBack(); // Callback if ads shouldn't be shown or limit not reached.
      return false;
    }
    return true;
  }

  @override
  void discardAd() {
    if (isShowing) return;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    super.discardAd();
  }

  /// Resets the ad state and disposes of loaded ads.
  @override
  void reset() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    super.reset();
  }
}
