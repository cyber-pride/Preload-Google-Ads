import '../ad_internal.dart';

/// A singleton class to manage interstitial ads.
class InterAd extends BaseAdLoader {
  /// Singleton instance of [InterAd].
  static final InterAd instance = InterAd._internal();

  /// Factory constructor to provide access to the singleton [InterAd].
  factory InterAd() {
    return instance;
  }

  /// Private constructor for [InterAd] singleton.
  InterAd._internal();

  @override
  bool get isEnabled => shouldShowInterAd;

  @override
  String get adLabel => "Interstitial";

  @override
  bool get isAutoPreload => autoPreloadInterAd;

  /// The interstitial ad object.
  InterstitialAd? _interstitialAd;

  /// Loads an interstitial ad.
  ///
  /// Attempts to load an interstitial ad and set its immersive mode when it's loaded.
  @override
  void load() {
    if (!prepareLoad()) return;
    try {
      InterstitialAd.load(
        adUnitId: unitIDInter,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          /// Called when the ad is loaded successfully.
          onAdLoaded: (InterstitialAd ad) {
            AdStats.instance.interLoad.value++;
            _interstitialAd = ad;
            _interstitialAd!.setImmersiveMode(true);
            handleLoadSuccess();
          },

          /// Called if the ad fails to load.
          onAdFailedToLoad: (LoadAdError error) {
            _interstitialAd = null;
            AdStats.instance.interFailed.value++;
            handleFailureAndRetry(error);
          },
        ),
      );
    } catch (error) {
      state = AdLoadState.failed;
      /// Disposes the ad if any error occurs.
      _interstitialAd?.dispose();
      _interstitialAd = null;
      handleFailureAndRetry(error);
    }
  }

  /// Shows the interstitial ad if it's ready.
  ///
  /// Only shows the ad if the interstitial is loaded and the counter limit is reached.
  /// After showing the ad, it resets the counter and loads a new ad.
  ///
  /// Returns true if an ad is being presented; false if [callBack] was
  /// already called because no ad was shown.
  bool showInter({
    required Function({InterstitialAd? ad, AdError? error}) callBack,
  }) {
    incrementCounter();
    if (counter < getInterCounter) {
      // Counter limit not reached yet. Do NOT waste ad request or show.
      callBack();
      return false;
    }

    if (shouldShowInterAd && _interstitialAd != null && isAdLoaded) {
      // Check if ad expired (AdMob 4-hour TTL rule)
      if (isExpired) {
        AppLogger.warn('Interstitial ad expired. Fetching fresh ad.');
        discardAd();
        if (isAutoPreload) load();
        callBack();
        return false;
      }

      resetCounter();
      state = AdLoadState.showing;

      _interstitialAd!
        ..fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (_) => FullScreenAdGuard.onShown(),
          onAdClicked: (_) => FullScreenAdGuard.onClicked(),

          /// Called when the ad is dismissed.
          onAdDismissedFullScreenContent: (ad) {
            FullScreenAdGuard.onDismissed();
            callBack(ad: ad as InterstitialAd?);
            ad.dispose();
            _interstitialAd = null;
            state = AdLoadState.initial;
            if (isAutoPreload) load();
          },

          /// Called when an impression of the ad is recorded.
          onAdImpression: (_) {
            AdStats.instance.interImp.value++;
          },

          /// Called if the ad fails to show.
          onAdFailedToShowFullScreenContent: (ad, error) {
            FullScreenAdGuard.onDismissed();
            callBack(ad: ad as InterstitialAd?, error: error);
            AppLogger.error('$ad onAdFailedToShowFullScreenContent: $error');
            ad.dispose();
            _interstitialAd = null;
            state = AdLoadState.failed;
            if (isAutoPreload) load();
          },
        )
        ..show();
    } else {
      if (isAutoPreload && !isAdLoaded && state != AdLoadState.loading) {
        load(); // Request ad only when user is close/ready to view
      }
      callBack();
      return false;
    }
    return true;
  }

  @override
  void discardAd() {
    if (isShowing) return;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    super.discardAd();
  }

  /// Resets the ad state and disposes of loaded ads.
  @override
  void reset() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    super.reset();
  }
}
