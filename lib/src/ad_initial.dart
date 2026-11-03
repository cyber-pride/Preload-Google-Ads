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
  void showOpenApp() {
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
  /// [callBack] is invoked when the ad closes or fails to present.
  void showInterstitialAd({
    required Function(InterstitialAd? ad, AdError? error) callBack,
  }) {
    return _adManager.showInterstitialAd(callBack: callBack);
  }

  /// Displays a preloaded Rewarded ad based on click counter rules.
  ///
  /// [onReward] is invoked when the user earns a reward item.
  void showRewardedAd({
    required void Function(RewardedAd? ad, AdError? error) callBack,
    required void Function(AdWithoutView ad, RewardItem reward) onReward,
  }) {
    return _adManager.showRewardedAd(callBack: callBack, onReward: onReward);
  }

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
  void showRewardedInterstitialAd({
    required void Function(RewardedInterstitialAd? ad, AdError? error) callBack,
    required void Function(AdWithoutView ad, RewardItem reward) onReward,
  }) {
    return _adManager.showRewardedInterstitialAd(
      callBack: callBack,
      onReward: onReward,
    );
  }
}
