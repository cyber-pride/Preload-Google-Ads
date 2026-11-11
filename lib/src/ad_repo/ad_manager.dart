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

  /// Whether the Mobile Ads SDK has been started (after `initialize()` and,
  /// if required, consent). Ads can only be requested after this.
  bool get isSdkStarted => _sdkStarted;

  /// Lets tests simulate a started SDK without the platform plugin.
  @visibleForTesting
  set debugSdkStarted(bool value) => _sdkStarted = value;

  bool _initialized = false;

  /// Initializes the AdManager with the provided ad configuration.
  ///
  /// Flow (Google recommended):
  /// 1. If [AdConfigData.requireConsent] is set, gather UMP consent first.
  /// 2. Start the Mobile Ads SDK once ads may be requested.
  /// 3. Preload one ad per enabled format and register the App Open listener.
  ///
  /// Calling it again updates the current config: anything [adConfig] leaves
  /// out keeps its current value, consent stays required once it was, and
  /// cached ads whose ad unit ID, flag or style changed are replaced.
  Future<void> initialize(AdConfigData? adConfig) async {
    final previous = _initialized ? config : null;
    _reloadAfterInit.clear();
    config = await setConfigData(adConfig, base: previous);
    _initialized = true;
    if (previous != null) _discardOutdatedAds(previous, adConfig);

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

    for (final loader in _reloadAfterInit) {
      loader.load();
    }
    _reloadAfterInit.clear();
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
    if (shouldshowAppOpenAd) {
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

    // Both native layouts (platform factories and Flutter templates) apply
    // their style when the ad loads, so cached ads must be replaced.
    if (wasDark != isDark) _refreshNativeAds(reload: true);
  }

  /// Replaces cached (and in-flight) native ads so the next ones use the
  /// current style.
  void _refreshNativeAds({required bool reload}) {
    for (final loader in [LoadMediumNative.instance, LoadSmallNative.instance]) {
      if (loader.ads.isEmpty && !loader.isLoading) continue;
      loader.reset();
      if (reload) {
        loader.loadAd();
      } else if (!loader.isAutoPreload) {
        _reloadAfterInit.add(loader);
      }
    }
  }

  /// After a repeat [initialize], drops cached ads that no longer match the
  /// config. Auto formats are reloaded by [reloadUnloadedAds]; manual formats
  /// that had an ad are requested again too (see [_reloadAfterInit]).
  void _discardOutdatedAds(AdConfigData before, AdConfigData? update) {
    final now = config;
    bool changed(String? a, String? b, bool? fa, bool? fb) => a != b || fa != fb;
    final idsA = before.adIDs, idsB = now.adIDs;
    final flagA = before.adFlag, flagB = now.adFlag;
    final allOff = flagA?.showAd != flagB?.showAd;

    void discard(BaseAdLoader loader, bool outdated) {
      // Never dispose an ad that is on screen right now.
      if (!(outdated || allOff) || loader.isShowing) return;
      final hadAd = loader.hasReadyAd || loader.isLoading;
      loader.reset();
      if (hadAd && !loader.isAutoPreload) _reloadAfterInit.add(loader);
    }

    discard(InterAd.instance, changed(idsA?.interstitialId, idsB?.interstitialId,
        flagA?.showInterstitial, flagB?.showInterstitial));
    discard(RewardAd.instance, changed(idsA?.rewardedId, idsB?.rewardedId,
        flagA?.showRewarded, flagB?.showRewarded));
    discard(RewardInterAd.instance, changed(idsA?.rewardedInterstitialId,
        idsB?.rewardedInterstitialId, flagA?.showRewardedInterstitial,
        flagB?.showRewardedInterstitial));
    discard(AppOpenAdManager.instance, changed(idsA?.appOpenId, idsB?.appOpenId,
        flagA?.showAppOpen, flagB?.showAppOpen));
    discard(LoadBannerAd.instance, changed(idsA?.bannerId, idsB?.bannerId,
        flagA?.showBanner, flagB?.showBanner));

    final nativeOutdated = allOff ||
        changed(idsA?.nativeId, idsB?.nativeId, flagA?.showNative, flagB?.showNative) ||
        update?.nativeADLayout != null ||
        before.themeMode != now.themeMode;
    if (nativeOutdated) _refreshNativeAds(reload: false);
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

  /// Every format loader, in the order ads are preloaded at startup.
  List<BaseAdLoader> get _loaders => [
        RewardAd.instance,
        RewardInterAd.instance,
        InterAd.instance,
        LoadBannerAd.instance,
        LoadMediumNative.instance,
        LoadSmallNative.instance,
        AppOpenAdManager.instance,
      ];

  /// Triggers background reloading of any ad format that failed or was lost
  /// due to network issues.
  ///
  /// Only formats in [PreloadMode.auto] are reloaded; manual formats load
  /// only through their `preload…()` function.
  void reloadUnloadedAds() {
    if (!shouldShowAd || !canRequestAds || !_sdkStarted) return;
    for (final loader in _loaders) {
      if (loader.isAutoPreload && loader.isEnabled && !loader.hasReadyAd) {
        loader.load();
      }
    }
  }

  /// Manual-mode loaders whose ready ad was discarded by a repeat
  /// [initialize]; they are requested again once ads may be loaded, so a
  /// config update never silently drops an ad the app asked for.
  final Set<BaseAdLoader> _reloadAfterInit = {};

  /// Preloads an interstitial ad. See [BaseAdLoader.preload].
  Future<bool> preloadInterstitialAd() => InterAd.instance.preload();

  /// Preloads a rewarded ad. See [BaseAdLoader.preload].
  Future<bool> preloadRewardedAd() => RewardAd.instance.preload();

  /// Preloads a rewarded interstitial ad. See [BaseAdLoader.preload].
  Future<bool> preloadRewardedInterstitialAd() =>
      RewardInterAd.instance.preload();

  /// Preloads an app open ad. See [BaseAdLoader.preload].
  Future<bool> preloadAppOpenAd() => AppOpenAdManager.instance.preload();

  /// Preloads a standard banner ad. See [BaseAdLoader.preload].
  Future<bool> preloadBannerAd() => LoadBannerAd.instance.preload();

  /// Preloads a native ad of [nativeADType]. See [BaseAdLoader.preload].
  Future<bool> preloadNativeAd({NativeADType nativeADType = NativeADType.medium}) =>
      (nativeADType == NativeADType.small
              ? LoadSmallNative.instance
              : LoadMediumNative.instance)
          .preload();

  /// Below methods are used to show various types of ads

  /// Shows a native ad. Optionally specify if it is a small or medium-sized ad.
  Widget showNativeAd({NativeADType nativeADType = NativeADType.medium}) {
    return PlugAd.getInstance().showNative(nativeADType: nativeADType);
  }

  /// Shows the open app ad.
  bool showAppOpenAd() {
    return PlugAd.getInstance().showAppOpenAd();
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
  bool showInterstitialAd({
    required Function(InterstitialAd? ad, AdError? error) callBack,
  }) {
    return PlugAd.getInstance().showInterAd(
      callBack: ({InterstitialAd? ad, AdError? error}) {
        callBack(ad, error);
      },
    );
  }

  /// Shows the rewarded ad and invokes the provided callbacks with the ad, error, and reward information.
  bool showRewardedAd({
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
  bool showRewardedInterstitialAd({
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
