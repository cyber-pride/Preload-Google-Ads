import 'ad_internal.dart';

/// **PreloadGoogleAds**: The primary singleton entrypoint for managing AdMob preloading and ad display.
///
/// Use `PreloadGoogleAds.instance` to initialize ad configuration, show preloaded ads, and query stats.
class PreloadGoogleAds {
  /// Private constructor for singleton pattern.
  PreloadGoogleAds._privateConstructor();

  /// The global singleton instance of [PreloadGoogleAds].
  static final PreloadGoogleAds instance =
      PreloadGoogleAds._privateConstructor();

  /// Reference to the internal [AdManager] instance handling preloading tasks.
  final AdManager _adManager = AdManager.instance;

  /// Initializes the Google Mobile Ads SDK and preloading queues with optional custom [adConfigData].
  ///
  /// ```dart
  /// await PreloadGoogleAds.instance.initialize(
  ///   adConfigData: AdConfigData(
  ///     adIDs: AdIDS(bannerId: 'your-ad-unit-id'),
  ///   ),
  /// );
  /// ```
  Future<void> initialize({AdConfigData? adConfigData}) async {
    await AdManager.instance.initialize(adConfigData);
  }

  /// Dynamically updates the active ad theme mode ([AdThemeMode.system], [AdThemeMode.light], or [AdThemeMode.dark]).
  /// Synchronizes native platform ad styles immediately.
  Future<void> setThemeMode(AdThemeMode mode, {BuildContext? context}) async {
    await _adManager.setThemeMode(mode, context: context);
  }

  /// Static shortcut helper to initialize the ad system.
  static Future<void> init({AdConfigData? adConfigData}) async {
    await instance.initialize(adConfigData: adConfigData);
  }

  /// Force reloads native ad instances for [nativeADType] (Small or Medium).
  Future<void> reloadNativeAd({NativeADType? nativeADType, BuildContext? context}) async {
    await _adManager.reloadNativeAd(nativeADType: nativeADType, context: context);
  }

  /// Triggers background re-fetching of any missing or failed ads (e.g. after network connection returns).
  void reloadUnloadedAds() {
    _adManager.reloadUnloadedAds();
  }

  /// Static shortcut to trigger background reloading of all missing or unloaded ads.
  static void reloadAllUnloadedAds() {
    instance.reloadUnloadedAds();
  }

  /// Displays a preloaded native ad widget.
  ///
  /// Accepts an optional [key] for subtree identity preservation during dynamic style rebuilds,
  /// and [nativeADType] ([NativeADType.medium] or [NativeADType.small]).
  Widget showNativeAd({
    Key? key,
    NativeADType nativeADType = NativeADType.medium,
  }) {
    return KeyedSubtree(
      key: key,
      child: _adManager.showNativeAd(nativeADType: nativeADType),
    );
  }

  /// Displays the preloaded App Open ad on demand.
  ///
  /// Returns true if an ad is being presented.
  bool showOpenApp() {
    return _adManager.showOpenApp();
  }

  /// Displays a standard anchored adaptive banner ad inside a responsive container.
  Widget showBannerAd() {
    return _adManager.showBannerAd();
  }

  /// Displays a collapsible banner ad anchored to [CollapsibleBannerPosition.bottom] or [CollapsibleBannerPosition.top].
  Widget showCollapsibleBannerAd({
    Key? key,
    CollapsibleBannerPosition collapsiblePosition = CollapsibleBannerPosition.bottom,
  }) {
    return ShowCollapsibleBannerAd(
      key: key,
      collapsiblePosition: collapsiblePosition,
    );
  }

  /// Toggles the diagnostic real-time ad counter overlay widget.
  Widget showAdCounter({bool? showCounter}) {
    return _adManager.showAdCounter(showCounter: showCounter);
  }

  /// Displays a preloaded full-screen Interstitial ad based on configured click frequency.
  ///
  /// [callBack] is invoked when the ad closes or fails to present, or right
  /// away (with no ad and no error) when no ad is shown.
  ///
  /// Returns true if an ad is being presented, false if no ad was shown
  /// (frequency counter not reached, or no ad loaded yet).
  ///
  /// With [PreloadMode.auto] a missing ad is requested here and the next one
  /// is loaded after this one closes. With [PreloadMode.manual] neither
  /// happens: call [preloadInterstitialAd] beforehand.
  bool showInterstitialAd({
    required Function(InterstitialAd? ad, AdError? error) callBack,
  }) {
    return _adManager.showInterstitialAd(callBack: callBack);
  }

  /// Displays a preloaded Rewarded ad based on click counter rules.
  ///
  /// With [PreloadMode.manual], call [preloadRewardedAd] beforehand; no ad is
  /// requested here or after it closes.
  ///
  /// [onReward] is invoked when the user earns a reward item.
  ///
  /// Returns true if an ad is being presented, false if no ad was shown.
  bool showRewardedAd({
    required void Function(RewardedAd? ad, AdError? error) callBack,
    required void Function(AdWithoutView ad, RewardItem reward) onReward,
  }) {
    return _adManager.showRewardedAd(callBack: callBack, onReward: onReward);
  }

  ///==========================================================================
  /// Manual preloading
  ///
  /// Use these for formats set to [PreloadMode.manual] in
  /// [AdConfigData.preloadConfig]: call one when the user is about to reach the
  /// screen that shows the ad (e.g. on entering a level, before its "Watch ad"
  /// button), so ads are only requested when they are likely to be seen.
  ///
  /// They also work for [PreloadMode.auto] formats, and do nothing if an ad is
  /// already loaded or loading, so they are safe to call repeatedly.
  ///
  /// Each completes with true once an ad is ready, or false if the format is
  /// disabled, `initialize()` has not finished (or consent is missing), an ad
  /// of that format is on screen, or the request fails. A failed request still
  /// retries in the background (5s, 10s, 20s).
  ///==========================================================================

  /// Preloads an Interstitial ad.
  Future<bool> preloadInterstitialAd() => _adManager.preloadInterstitialAd();

  /// Preloads a Rewarded ad.
  Future<bool> preloadRewardedAd() => _adManager.preloadRewardedAd();

  /// Preloads a Rewarded Interstitial ad.
  Future<bool> preloadRewardedInterstitialAd() =>
      _adManager.preloadRewardedInterstitialAd();

  /// Preloads an App Open ad. In [PreloadMode.manual] the ad is shown the next
  /// time the user returns to the app (or via [showOpenApp]).
  Future<bool> preloadAppOpenAd() => _adManager.preloadAppOpenAd();

  /// Preloads a standard banner ad for the next [showBannerAd].
  Future<bool> preloadBannerAd() => _adManager.preloadBannerAd();

  /// Preloads a native ad of [nativeADType] for the next [showNativeAd].
  Future<bool> preloadNativeAd({NativeADType nativeADType = NativeADType.medium}) =>
      _adManager.preloadNativeAd(nativeADType: nativeADType);

  /// Whether the app must offer a "Privacy settings" entry point.
  ///
  /// Only relevant when [AdConfigData.requireConsent] is true. Google requires
  /// a way for users to change their consent; show a settings button that
  /// calls [showPrivacyOptionsForm] when this returns true.
  Future<bool> isPrivacyOptionsRequired() =>
      _adManager.isPrivacyOptionsRequired();

  /// Shows Google's privacy options form. If the user now allows ads, the SDK
  /// starts and preloading begins automatically.
  Future<void> showPrivacyOptionsForm() => _adManager.showPrivacyOptionsForm();

  /// Whether ads may currently be requested (consent obtained or not required).
  bool get canRequestAds => _adManager.canRequestAds;

  /// Whether an Interstitial ad is loaded and can be shown right now.
  bool get isInterstitialAdReady => InterAd.instance.isAdLoaded;

  /// Whether a Rewarded ad is loaded and can be shown right now.
  ///
  /// Google recommends only offering a "Watch ad for reward" button when this
  /// is true. Grant rewards only in `onReward`, never in `callBack`.
  bool get isRewardedAdReady => RewardAd.instance.isAdLoaded;

  /// Whether a Rewarded Interstitial ad is loaded and can be shown right now.
  bool get isRewardedInterstitialAdReady => RewardInterAd.instance.isAdLoaded;

  /// Displays a preloaded Rewarded Interstitial ad.
  ///
  /// [onReward] is invoked when the user earns a reward item.
  ///
  /// Returns true if an ad is being presented, false if no ad was shown.
  bool showRewardedInterstitialAd({
    required void Function(RewardedInterstitialAd? ad, AdError? error) callBack,
    required void Function(AdWithoutView ad, RewardItem reward) onReward,
  }) {
    return _adManager.showRewardedInterstitialAd(
      callBack: callBack,
      onReward: onReward,
    );
  }
}
