import '../ad_internal.dart';

/// Singleton class responsible for managing all ad operations.
class AdManager {
  /// Singleton instance of AdManager
  static final AdManager _instance = AdManager._internal();

  /// Factory constructor to provide access to the single instance of AdManager
  factory AdManager() => _instance;

  /// Private named constructor to ensure only one instance is created
  AdManager._internal();

  /// Getter for the singleton instance of AdManager
  static AdManager get instance => _instance;

  /// The current ad configuration
  AdConfigData config = preData;

  /// Whether ad requests are currently allowed.
  ///
  /// Always true unless [AdConfigData.requireConsent] is set, in which case it
  /// mirrors `ConsentInformation.canRequestAds()`. Every loader checks this
  /// before requesting an ad.
  bool canRequestAds = true;

  bool _sdkStarted = false;

  /// Initializes the AdManager with the provided ad configuration.
  ///
  /// Flow (Google recommended):
  /// 1. If [AdConfigData.requireConsent] is set, gather UMP consent first.
  /// 2. Start the Mobile Ads SDK once ads may be requested.
  /// 3. Preload one ad per enabled format and register the App Open listener.
  Future<void> initialize(AdConfigData? adConfig) async {
    config = await setConfigData(adConfig);

    // Sync initial native channel ad style based on configured mode
    await _syncNativeAdStyle();

    if (config.requireConsent) {
      canRequestAds = false;
      await _gatherConsent();
      canRequestAds = await _safeCanRequestAds();
    } else {
      canRequestAds = true;
    }

    if (!canRequestAds) {
      AppLogger.warn(
        'Consent not obtained: ads will not be requested. '
        'They start automatically if consent is given via showPrivacyOptionsForm().',
      );
      return;
    }
    await _startSdkAndPreload();
  }

  /// Starts the SDK and preloads ads exactly once.
  Future<void> _startSdkAndPreload() async {
    if (!_sdkStarted) {
      await MobileAds.instance.initialize();
      _sdkStarted = true;
    }

    // Google-recommended preloading: once the SDK is ready, load exactly one ad
    // for each enabled format so the first show is instant. Each loader refills
    // itself only after its ad is shown, so requests stay ~1:1 with impressions
    // (good show rate). Disable formats you don't use via AdFlag to avoid
    // requesting ads that will never be shown.
    // Nothing is shown here: no ad is forced on app launch.
    reloadUnloadedAds();

    // Show App Open ads when the user returns to the app (registered once).
    if (shouldShowOpenAppAd) {
      await LifeCycleManager.instance.getOpenAppAdvertise();
    }
  }

  /// Requests the latest consent info and shows the consent form if required.
  /// Never throws; on any error the previously stored consent still applies.
  Future<void> _gatherConsent() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      config.consentRequestParameters ?? ConsentRequestParameters(),
      () => updated.complete(),
      (FormError error) {
        AppLogger.error('Consent info update failed: ${error.message}');
        updated.complete();
      },
    );
    await updated.future;

    final dismissed = Completer<void>();
    try {
      await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (error != null) {
          AppLogger.error('Consent form error: ${error.message}');
        }
        if (!dismissed.isCompleted) dismissed.complete();
      });
      await dismissed.future;
    } catch (e) {
      AppLogger.error('Consent form failed: $e');
    }
  }

  Future<bool> _safeCanRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      AppLogger.error('canRequestAds failed: $e');
      return false;
    }
  }

  /// Whether the app must show a "Privacy settings" entry point
  /// (Google requires one when this is true).
  Future<bool> isPrivacyOptionsRequired() async {
    if (!config.requireConsent) return false;
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Shows the UMP privacy options form so users can change their choice.
  /// If ads become allowed afterwards, the SDK starts and preloading begins.
  Future<void> showPrivacyOptionsForm() async {
    final dismissed = Completer<void>();
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (error != null) {
          AppLogger.error('Privacy options form error: ${error.message}');
        }
        if (!dismissed.isCompleted) dismissed.complete();
      });
      await dismissed.future;
    } catch (e) {
      AppLogger.error('Privacy options form failed: $e');
      return;
    }

    final allowed = await _safeCanRequestAds();
    final wasAllowed = canRequestAds;
    canRequestAds = allowed;
    if (allowed && !wasAllowed) {
      await _startSdkAndPreload();
    }
  }

  /// Sets the ad theme mode dynamically at runtime and updates native styles.
  ///
  /// Cached (not yet displayed) native ads were rendered with the old style,
  /// so they are replaced when the effective light/dark mode changes.
  Future<void> setThemeMode(AdThemeMode mode, {BuildContext? context}) async {
    final wasDark = NativeADStyle.instance.isDarkMode(context: context);
    config = config.copyWith(themeMode: mode);
    final isDark = NativeADStyle.instance.isDarkMode(context: context);
    await _syncNativeAdStyle(context: context);

    if (wasDark != isDark && !isFlutterLayout) {
      for (final loader in [LoadMediumNative.instance, LoadSmallNative.instance]) {
        if (loader.ads.isNotEmpty) {
          loader.reset();
          loader.loadAd();
        }
      }
    }
  }

  /// Syncs native Kotlin/Swift ad styling via MethodChannel.
  ///
  /// Never throws: a styling failure must not stop the SDK from initializing
  /// or ads from loading.
  Future<void> _syncNativeAdStyle({BuildContext? context}) async {
    try {
      final style = NativeADStyle.instance.getCustomStyle(context: context);
      await setAdStyleData(style);
    } catch (e) {
      AppLogger.error("Failed to sync native ad style: $e");
    }
  }

  /// Force reloads native ads (Small or Medium).
  Future<void> reloadNativeAd({NativeADType? nativeADType, BuildContext? context}) async {
    await _syncNativeAdStyle(context: context);
    if (nativeADType == NativeADType.small) {
      LoadSmallNative.instance.reset();
      LoadSmallNative.instance.loadAd();
    } else if (nativeADType == NativeADType.medium) {
      LoadMediumNative.instance.reset();
      LoadMediumNative.instance.loadAd();
    } else {
      LoadMediumNative.instance.reset();
      LoadSmallNative.instance.reset();
      LoadMediumNative.instance.loadAd();
      LoadSmallNative.instance.loadAd();
    }
  }

  /// Triggers background reloading of any ad format that failed or was lost due to network issues.
  void reloadUnloadedAds() {
    if (!shouldShowAd || !canRequestAds) return;

    if (shouldShowRewardedAd && !RewardAd.instance.isAdLoaded) {
      RewardAd.instance.load();
    }
    if (shouldShowRewardedInterAd && !RewardInterAd.instance.isAdLoaded) {
      RewardInterAd.instance.load();
    }
    if (shouldShowInterAd && !InterAd.instance.isAdLoaded) {
      InterAd.instance.load();
    }
    if (shouldShowBannerAd && LoadBannerAd.instance.bannerAdObject.isEmpty) {
      LoadBannerAd.instance.loadAd();
    }
    if (shouldShowNativeAd) {
      if (LoadMediumNative.instance.ads.isEmpty) {
        LoadMediumNative.instance.loadAd();
      }
      if (LoadSmallNative.instance.ads.isEmpty) {
        LoadSmallNative.instance.loadAd();
      }
    }
    if (shouldShowOpenAppAd && !AppOpenAdManager.instance.isAdAvailable) {
      AppOpenAdManager.instance.loadAd();
    }
  }



  /// Below methods are used to show various types of ads

  /// Shows a native ad. Optionally specify if it is a small or medium-sized ad.
  Widget showNativeAd({NativeADType nativeADType = NativeADType.medium}) {
    return PlugAd.getInstance().showNative(nativeADType: nativeADType);
  }

  /// Shows the open app ad.
  void showOpenApp() {
    return PlugAd.getInstance().showOpenAppAd();
  }

  /// Shows a standard anchored banner ad.
  Widget showBannerAd() {
    return PlugAd.getInstance().showBannerAd();
  }

  /// Shows a collapsible banner ad ([CollapsibleBannerPosition.bottom] or [CollapsibleBannerPosition.top]).
  Widget showCollapsibleBannerAd({CollapsibleBannerPosition collapsiblePosition = CollapsibleBannerPosition.bottom}) {
    return PlugAd.getInstance().showCollapsibleBannerAd(collapsiblePosition: collapsiblePosition);
  }

  /// Displays the ad counter (if available).
  Widget showAdCounter({bool? showCounter}) {
    return PlugAd.getInstance().showAdCounter(showCounter ?? true);
  }

  /// Shows the interstitial ad and invokes the provided callback with the ad or error.
  void showInterstitialAd({
    required Function(InterstitialAd? ad, AdError? error) callBack,
  }) {
    return PlugAd.getInstance().showInterAd(
      callBack: ({InterstitialAd? ad, AdError? error}) {
        callBack(ad, error);
      },
    );
  }

  /// Shows the rewarded ad and invokes the provided callbacks with the ad, error, and reward information.
  void showRewardedAd({
    required void Function(RewardedAd? ad, AdError? error) callBack,
    required void Function(AdWithoutView ad, RewardItem reward) onReward,
  }) {
    return PlugAd.getInstance().showRewardedAd(
      callBack: ({RewardedAd? ad, AdError? error}) {
        callBack(ad, error);
      },
      onReward: onReward,
    );
  }

  /// Shows the rewarded interstitial ad and invokes the provided callbacks with the ad, error, and reward information.
  void showRewardedInterstitialAd({
    required void Function(RewardedInterstitialAd? ad, AdError? error) callBack,
    required void Function(AdWithoutView ad, RewardItem reward) onReward,
  }) {
    return PlugAd.getInstance().showRewardedInterAd(
      callBack: ({RewardedInterstitialAd? ad, AdError? error}) {
        callBack(ad, error);
      },
      onReward: onReward,
    );
  }
}
