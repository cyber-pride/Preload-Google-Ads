import '../ad_internal.dart';

///==============================================================================
///              **  Initial Config Data Function  **
///==============================================================================

/// Initial ad configuration with default values and test IDs.
AdConfigData preData = AdConfigData(
  adIDs: AdIDS(
    appOpenId: AdTestIds.appOpen,
    bannerId: AdTestIds.banner,
    nativeId: AdTestIds.native,
    interstitialId: AdTestIds.interstitial,
    rewardedId: AdTestIds.rewarded,
    rewardedInterstitialId: AdTestIds.rewardedInterstitial,
  ),
  adCounter: AdCounter(
    // Show an interstitial on every 3rd trigger by default. Showing one on
    // every action is disruptive and risks AdMob's interstitial policy.
    interstitialCounter: 3,
    nativeCounter: 0,
    rewardedCounter: 0,
    rewardedInterstitialCounter: 0,
  ),
  adFlag: AdFlag(
    showAd: true,
    showBanner: true,
    showInterstitial: true,
    showNative: true,
    showAppOpenAd: true,
    showRewarded: true,
    showRewardedInterstitial: true,
  ),
  nativeADLayout: NativeADLayout(
    padding: EdgeInsets.all(5),
    margin: EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(5),
    ),
    adLayout: AdLayout.nativeLayout,
    customNativeADStyle: CustomNativeADStyle(),
    flutterNativeADStyle: FlutterNativeADStyle(),
  ),
);

///==============================================================================
///              **  Set Config Data Function  **
///==============================================================================

/// Google's public test ad unit IDs all belong to this publisher ID.
const String _testPublisherPrefix = 'ca-app-pub-3940256099942544/';

/// Whether [id] is one of Google's sample/test ad unit IDs.
bool isTestAdUnitId(String? id) =>
    id != null && id.startsWith(_testPublisherPrefix);

/// Resolves whether a format stays enabled given the ad unit ID the app set.
///
/// In release builds a format whose ad unit ID was not provided is disabled
/// instead of silently falling back to Google's test IDs (which earn nothing).
bool? _resolveFlag(
  bool? enabled,
  String? providedId,
  String label, {
  required bool releaseMode,
}) {
  if (enabled != true) return enabled;
  if (providedId == null || providedId.isEmpty) {
    if (releaseMode) {
      debugPrint(
        'PreloadGoogleAds: no $label ad unit ID provided. $label ads are '
        'disabled in this release build. Set it in AdIDS or turn it off in AdFlag.',
      );
      return false;
    }
    AppLogger.warn('$label: no ad unit ID provided, using Google test ID (debug only).');
  } else if (releaseMode && isTestAdUnitId(providedId)) {
    debugPrint(
      'PreloadGoogleAds: $label is using a Google TEST ad unit ID in a release '
      'build. These ads earn no revenue. Replace it with your AdMob ID.',
    );
  }
  return enabled;
}

/// Sets the configuration data for ads, allowing custom values for each ad type.
///
/// Values missing from [adConfig] come from [base] (the current config when
/// `initialize()` is called again) or, on the first call, from [preData].
/// Consent stays required once [base] required it.
///
/// [releaseMode] defaults to [kReleaseMode]; it is a parameter only for tests.
Future<AdConfigData> setConfigData(
  AdConfigData? adConfig, {
  bool releaseMode = kReleaseMode,
  AdConfigData? base,
}) async {
  final fallback = base ?? preData;
  final given = adConfig?.adIDs;
  final kept = base?.adIDs;
  // IDs the app actually set: in this call, or in an earlier initialize().
  final ids = AdIDS(
    appOpenId: given?.appOpenId ?? kept?.appOpenId,
    bannerId: given?.bannerId ?? kept?.bannerId,
    nativeId: given?.nativeId ?? kept?.nativeId,
    interstitialId: given?.interstitialId ?? kept?.interstitialId,
    rewardedId: given?.rewardedId ?? kept?.rewardedId,
    rewardedInterstitialId:
        given?.rewardedInterstitialId ?? kept?.rewardedInterstitialId,
  );
  bool? flag(bool? enabled, String? id, String label) =>
      _resolveFlag(enabled, id, label, releaseMode: releaseMode);

  return AdConfigData(
    requireConsent:
        (adConfig?.requireConsent ?? false) || (base?.requireConsent ?? false),
    consentRequestParameters:
        adConfig?.consentRequestParameters ?? base?.consentRequestParameters,
    preloadConfig: adConfig?.preloadConfig?.mergeOnto(base?.preloadConfig) ??
        base?.preloadConfig,
    adIDs: AdIDS(
      appOpenId: adConfig?.adIDs?.appOpenId ?? fallback.adIDs?.appOpenId,
      bannerId: adConfig?.adIDs?.bannerId ?? fallback.adIDs?.bannerId,
      nativeId: adConfig?.adIDs?.nativeId ?? fallback.adIDs?.nativeId,
      interstitialId:
          adConfig?.adIDs?.interstitialId ?? fallback.adIDs?.interstitialId,
      rewardedId: adConfig?.adIDs?.rewardedId ?? fallback.adIDs?.rewardedId,
      rewardedInterstitialId: adConfig?.adIDs?.rewardedInterstitialId ??
          fallback.adIDs?.rewardedInterstitialId,
    ),
    adCounter: AdCounter(
      interstitialCounter: adConfig?.adCounter?.interstitialCounter ??
          fallback.adCounter?.interstitialCounter,
      nativeCounter: adConfig?.adCounter?.nativeCounter ??
          fallback.adCounter?.nativeCounter,
      rewardedCounter: adConfig?.adCounter?.rewardedCounter ??
          fallback.adCounter?.rewardedCounter,
      rewardedInterstitialCounter:
          adConfig?.adCounter?.rewardedInterstitialCounter ??
              fallback.adCounter?.rewardedInterstitialCounter,
    ),
    adFlag: AdFlag(
      showAd: adConfig?.adFlag?.showAd ?? fallback.adFlag?.showAd,
      showBanner: flag(
        adConfig?.adFlag?.showBanner ?? fallback.adFlag?.showBanner,
        ids.bannerId,
        'Banner',
      ),
      showInterstitial: flag(
        adConfig?.adFlag?.showInterstitial ?? fallback.adFlag?.showInterstitial,
        ids.interstitialId,
        'Interstitial',
      ),
      showNative: flag(
        adConfig?.adFlag?.showNative ?? fallback.adFlag?.showNative,
        ids.nativeId,
        'Native',
      ),
      showAppOpenAd: flag(
        adConfig?.adFlag?.showAppOpenAd ?? fallback.adFlag?.showAppOpenAd,
        ids.appOpenId,
        'App Open',
      ),
      showRewarded: flag(
        adConfig?.adFlag?.showRewarded ?? fallback.adFlag?.showRewarded,
        ids.rewardedId,
        'Rewarded',
      ),
      showRewardedInterstitial: flag(
        adConfig?.adFlag?.showRewardedInterstitial ??
            fallback.adFlag?.showRewardedInterstitial,
        ids.rewardedInterstitialId,
        'Rewarded Interstitial',
      ),
    ),
    themeMode: (adConfig?.themeModeProvided ?? false)
        ? adConfig!.themeMode
        : fallback.themeMode,
    nativeADLayout: NativeADLayout(
      lightDecoration: adConfig?.nativeADLayout?.lightDecoration ??
          fallback.nativeADLayout?.lightDecoration,
      darkDecoration: adConfig?.nativeADLayout?.darkDecoration ??
          fallback.nativeADLayout?.darkDecoration,
      margin:
          adConfig?.nativeADLayout?.margin ?? fallback.nativeADLayout?.margin,
      padding:
          adConfig?.nativeADLayout?.padding ?? fallback.nativeADLayout?.padding,
      adLayout: adConfig?.nativeADLayout?.adLayout ??
          fallback.nativeADLayout?.adLayout,
      customNativeADStyle: adConfig?.nativeADLayout?.customNativeADStyle ??
          fallback.nativeADLayout?.customNativeADStyle,
      darkCustomNativeADStyle: adConfig?.nativeADLayout?.darkCustomNativeADStyle ??
          fallback.nativeADLayout?.darkCustomNativeADStyle,
      flutterNativeADStyle: adConfig?.nativeADLayout?.flutterNativeADStyle ??
          fallback.nativeADLayout?.flutterNativeADStyle,
      darkFlutterNativeADStyle: adConfig?.nativeADLayout?.darkFlutterNativeADStyle ??
          fallback.nativeADLayout?.darkFlutterNativeADStyle,
    ),
    bannerADLayout: BannerADLayout(
      lightDecoration: adConfig?.bannerADLayout?.lightDecoration ??
          fallback.bannerADLayout?.lightDecoration,
      darkDecoration: adConfig?.bannerADLayout?.darkDecoration ??
          fallback.bannerADLayout?.darkDecoration,
      margin: adConfig?.bannerADLayout?.margin ?? fallback.bannerADLayout?.margin,
      padding: adConfig?.bannerADLayout?.padding ?? fallback.bannerADLayout?.padding,
      adSize: adConfig?.bannerADLayout?.adSize ?? fallback.bannerADLayout?.adSize,
    ),
  );
}

///==============================================================================
///              **  Set Ad Style Data Function  **
///==============================================================================

/// Sets the ad style data by invoking a method on the native platform.
/// This method adjusts the appearance of various ad components like buttons and text.
Future<void> setAdStyleData(CustomNativeADStyle? adStyle) async {
  final channel = MethodChannel(nativeChannel);

  /// Fallback to default ad style if none is provided
  adStyle ??= CustomNativeADStyle();

  /// Passes ad style data to the native platform.
  await channel.invokeMethod(nativeMethod, {
    "title": colorToHex(adStyle.titleColor),
    "description": colorToHex(adStyle.bodyColor),
    "tag_background": colorToHex(adStyle.tagBackground),
    "tag_foreground": colorToHex(adStyle.tagForeground),
    "button_background": colorToHex(adStyle.buttonBackground),
    "button_foreground": colorToHex(adStyle.buttonForeground),
    "button_radius": adStyle.buttonRadius,
    "tag_radius": adStyle.tagRadius,
    "button_gradients":
        adStyle.buttonGradients.map((color) => colorToHex(color)).toList(),
  });
}

///==============================================================================
///              **  Ad Stats Function  **
///==============================================================================

/// Singleton class for tracking the statistics of various ads.
class AdStats {
  /// Private constructor to prevent external instantiation
  AdStats._privateConstructor();

  /// Singleton instance for accessing [AdStats]
  static final AdStats _instance = AdStats._privateConstructor();

  /// Getter to access the singleton instance
  static AdStats get instance => _instance;

  /// Statistics for Interstitial Ads
  /// Number of interstitial ads loaded.
  final ValueNotifier<int> interLoad = ValueNotifier(0);

  /// Number of interstitial ad impressions.
  final ValueNotifier<int> interImp = ValueNotifier(0);

  /// Number of interstitial ad load failures.
  final ValueNotifier<int> interFailed = ValueNotifier(0);

  /// Statistics for Rewarded Ads
  /// Number of rewarded ads loaded.
  final ValueNotifier<int> rewardedLoad = ValueNotifier(0);

  /// Number of rewarded ad impressions.
  final ValueNotifier<int> rewardedImp = ValueNotifier(0);

  /// Number of rewarded ad load failures.
  final ValueNotifier<int> rewardedFailed = ValueNotifier(0);

  /// Statistics for Rewarded Interstitial Ads
  /// Number of rewarded interstitial ads loaded.
  final ValueNotifier<int> rewardedInterLoad = ValueNotifier(0);

  /// Number of rewarded interstitial ad impressions.
  final ValueNotifier<int> rewardedInterImp = ValueNotifier(0);

  /// Number of rewarded interstitial ad load failures.
  final ValueNotifier<int> rewardedInterFailed = ValueNotifier(0);

  /// Statistics for Small Native Ads
  /// Number of small native ads loaded.
  final ValueNotifier<int> nativeLoadS = ValueNotifier(0);

  /// Number of small native ad impressions.
  final ValueNotifier<int> nativeImpS = ValueNotifier(0);

  /// Number of small native ad load failures.
  final ValueNotifier<int> nativeFailedS = ValueNotifier(0);

  /// Statistics for Medium Native Ads
  /// Number of medium native ads loaded.
  final ValueNotifier<int> nativeLoadM = ValueNotifier(0);

  /// Number of medium native ad impressions.
  final ValueNotifier<int> nativeImpM = ValueNotifier(0);

  /// Number of medium native ad load failures.
  final ValueNotifier<int> nativeFailedM = ValueNotifier(0);

  /// Statistics for App Open Ads
  /// Number of app open ads loaded.
  final ValueNotifier<int> openAppLoad = ValueNotifier(0);

  /// Number of app open ad impressions.
  final ValueNotifier<int> openAppImp = ValueNotifier(0);

  /// Number of app open ad load failures.
  final ValueNotifier<int> openAppFailed = ValueNotifier(0);

  /// Statistics for Banner Ads
  /// Number of banner ads loaded.
  final ValueNotifier<int> bannerLoad = ValueNotifier(0);

  /// Number of banner ad impressions.
  final ValueNotifier<int> bannerImp = ValueNotifier(0);

  /// Number of banner ad load failures.
  final ValueNotifier<int> bannerFailed = ValueNotifier(0);
}

///==============================================================================
///              **  Hex To Color Function  **
///==============================================================================

/// Converts a [Color] to its hexadecimal string representation.
///
/// Opaque colors become `#RRGGBB`; translucent colors keep their alpha as
/// `#AARRGGBB` (the format Android's `Color.parseColor` and the iOS factory read).
String colorToHex(Color color) {
  String hex(double channel) =>
      (channel * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');

  final rgb = hex(color.r) + hex(color.g) + hex(color.b);
  final alpha = (color.a * 255).round();
  return (alpha >= 255 ? '#$rgb' : '#${hex(color.a)}$rgb').toUpperCase();
}

///==============================================================================
///              **  Plug Unit ID's & AD Flags  **
///==============================================================================

/// Retrieves the current [AdConfigData] from the [AdManager].
AdConfigData get config => AdManager.instance.config;

/// Retrieves the App Open Ad Unit ID.
String get unitIDAppOpen => config.adIDs?.appOpenId ?? AdTestIds.appOpen;

/// Retrieves the Banner Ad Unit ID.
String get unitIDBanner => config.adIDs?.bannerId ?? AdTestIds.banner;

/// Retrieves the Interstitial Ad Unit ID.
String get unitIDInter =>
    config.adIDs?.interstitialId ?? AdTestIds.interstitial;

/// Retrieves the Native Ad Unit ID.
String get unitIDNative => config.adIDs?.nativeId ?? AdTestIds.native;

/// Retrieves the Rewarded Ad Unit ID.
String get unitIDRewarded => config.adIDs?.rewardedId ?? AdTestIds.rewarded;

/// Retrieves the Rewarded Interstitial Ad Unit ID.
String get unitIDRewardedInter =>
    config.adIDs?.rewardedInterstitialId ?? AdTestIds.rewardedInterstitial;

/// Determines if any ads should be shown based on flags.
bool get shouldShowAd => config.adFlag?.showAd == true;

/// Determines if native ads should be shown.
bool get shouldShowNativeAd =>
    config.adFlag?.showNative == true && config.adFlag?.showAd == true;

/// Determines if banner ads should be shown.
bool get shouldShowBannerAd =>
    config.adFlag?.showBanner == true && config.adFlag?.showAd == true;

/// Determines if interstitial ads should be shown.
bool get shouldShowInterAd =>
    config.adFlag?.showInterstitial == true && config.adFlag?.showAd == true;

/// Determines if rewarded ads should be shown.
bool get shouldShowRewardedAd =>
    config.adFlag?.showRewarded == true && config.adFlag?.showAd == true;

/// Determines if rewarded interstitial ads should be shown.
bool get shouldShowRewardedInterAd =>
    config.adFlag?.showRewardedInterstitial == true &&
    config.adFlag?.showAd == true;

/// Determines if the Open App ad should be shown.
bool get shouldshowAppOpenAd =>
    config.adFlag?.showAppOpenAd == true && config.adFlag?.showAd == true;

/// Whether interstitial ads are preloaded automatically.
bool get autoPreloadInterAd =>
    config.preloadConfig?.interstitial != PreloadMode.manual;

/// Whether rewarded ads are preloaded automatically.
bool get autoPreloadRewardedAd =>
    config.preloadConfig?.rewarded != PreloadMode.manual;

/// Whether rewarded interstitial ads are preloaded automatically.
bool get autoPreloadRewardedInterAd =>
    config.preloadConfig?.rewardedInterstitial != PreloadMode.manual;

/// Whether native ads are preloaded automatically.
bool get autoPreloadNativeAd =>
    config.preloadConfig?.native != PreloadMode.manual;

/// Whether banner ads are preloaded automatically.
bool get autoPreloadBannerAd =>
    config.preloadConfig?.banner != PreloadMode.manual;

/// Whether app open ads are preloaded automatically.
bool get autoPreloadOpenAppAd =>
    config.preloadConfig?.appOpen != PreloadMode.manual;

/// Gets the interstitial ad counter.
int get getInterCounter => config.adCounter?.interstitialCounter ?? 0;

/// Gets the native ad counter.
int get getNativeCounter => config.adCounter?.nativeCounter ?? 0;

/// Gets the rewarded ad counter.
int get getRewardedCounter => config.adCounter?.rewardedCounter ?? 0;

/// Gets the rewarded interstitial ad counter.
int get getRewardedInterCounter =>
    config.adCounter?.rewardedInterstitialCounter ?? 0;

/// Gets the Layout Type
bool get isFlutterLayout =>
    config.nativeADLayout?.adLayout == AdLayout.flutterLayout;
