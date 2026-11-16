import '../ad_internal.dart';

/// A class responsible for loading and managing banner ads.
class LoadBannerAd extends BaseAdLoader {
  /// Singleton instance of LoadBannerAd.
  static final LoadBannerAd instance = LoadBannerAd._internal();

  /// Factory constructor to return the singleton instance.
  factory LoadBannerAd() => instance;

  /// Private constructor to prevent external instantiation.
  LoadBannerAd._internal();

  @override
  bool get isEnabled => shouldShowBannerAd;

  @override
  String get adLabel => "Banner";

  @override
  bool get isAutoPreload => autoPreloadBannerAd;

  @override
  bool get hasReadyAd => bannerAdObject.any((ad) => !_isStale(ad));

  @override
  void discardAd() {
    for (final ad in bannerAdObject) {
      ad.dispose();
    }
    bannerAdObject.clear();
    super.discardAd();
  }

  /// List that holds currently loaded and cached banner ads.
  ///
  /// One shared pool for every placement: all banners use the same unit ID
  /// and size, so any pooled banner fits any page. At most one is kept.
  List<BannerAd> bannerAdObject = [];

  /// When each banner last loaded or refreshed, used to drop stale ones.
  final Expando<DateTime> _loadedAt = Expando('bannerLoadedAt');

  /// Records that [ad] has just loaded or refreshed its creative.
  void markLoaded(Ad ad) => _loadedAt[ad] = DateTime.now();

  /// Whether [ad] has gone longer than [maxCacheDuration] without a new creative.
  bool _isStale(BannerAd ad) {
    final loadedAt = _loadedAt[ad];
    if (loadedAt == null) return false;
    return DateTime.now().subtract(maxCacheDuration).isAfter(loadedAt);
  }

  /// Disposes pooled banners that are stale.
  void _dropStale() {
    final stale = bannerAdObject.where(_isStale).toList();
    if (stale.isEmpty) return;
    for (final ad in stale) {
      bannerAdObject.remove(ad);
      ad.dispose();
    }
    AppLogger.log("Banner: dropped ${stale.length} stale banner(s).");
    if (bannerAdObject.isEmpty && !isLoading) {
      loadTime = null;
      state = AdLoadState.initial;
    }
  }

  /// Legacy loading getter for backward compatibility.
  bool get loading => isLoading;

  /// Legacy reloadAd getter for backward compatibility.
  int get reloadAd => retryAttempts;

  @override
  void load() {
    loadAd();
  }

  /// Loads a banner ad (standard or collapsible) and handles its loading, errors, and impressions.
  ///
  /// Specify [isCollapsible] as 'bottom' or 'top' for collapsible banner ads.
  Future<void> loadAd({String? isCollapsible}) async {
    if (bannerAdObject.isNotEmpty || !prepareLoad()) return;

    BannerAd? bannerAd;

    try {
      AdSize? size = config.bannerADLayout?.adSize;

      if (size == null) {
        // Get the current screen's physical size.
        final view = PlatformDispatcher.instance.implicitView;
        if (view == null) {
          state = AdLoadState.failed;
          notifyPreloadResult(false);
          return;
        }

        final double logicalScreenWidth =
            view.physicalSize.width / view.devicePixelRatio;

        if (logicalScreenWidth <= 0) {
          state = AdLoadState.failed;
          notifyPreloadResult(false);
          return;
        }

        // Get the appropriate size for the banner ad based on the screen width.
        size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
          logicalScreenWidth.toInt(),
        );
      }

      if (size == null) {
        state = AdLoadState.failed;
        notifyPreloadResult(false);
        return;
      }

      // Configure request extras for Collapsible Banner if specified.
      final AdRequest request = isCollapsible != null
          ? AdRequest(
              extras: <String, String>{
                'collapsible': isCollapsible,
                'collapsible_request_id':
                    DateTime.now().millisecondsSinceEpoch.toString(),
              },
            )
          : const AdRequest();

      // Banners auto-refresh: the SDK calls onAdLoaded again on every
      // successful refresh and onAdFailedToLoad on every failed one, long after
      // the banner was handed to a widget. Only the first result counts.
      var initialLoadDone = false;

      // Create and configure the banner ad.
      bannerAd = BannerAd(
        adUnitId: unitIDBanner,
        size: size,
        request: request,
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) {
            if (initialLoadDone) {
              // A refresh of a banner that may already be on screen: re-adding
              // it to the pool would hand the same ad to a second widget.
              markLoaded(ad);
              AdStats.instance.bannerLoad.value++;
              return;
            }
            initialLoadDone = true;
            markLoaded(ad);
            // Handle successful ad load. A banner returned by a widget while
            // this request was in flight is replaced by the fresh one.
            for (final old in bannerAdObject) {
              old.dispose();
            }
            bannerAdObject.clear();
            if (bannerAd != null) {
              bannerAdObject.add(bannerAd);
            }
            AdStats.instance.bannerLoad.value++;
            handleLoadSuccess();
          },
          onAdImpression: (ad) {
            // Track ad impressions.
            AdStats.instance.bannerImp.value++;
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            // Handle failed ad load and retry logic.
            AdStats.instance.bannerFailed.value++;
            if (initialLoadDone) {
              // A failed refresh: the banner keeps its current creative. It may
              // be on screen, so disposing it here would crash its AdWidget
              // ("AdWidget requires Ad.load to be called...").
              AppLogger.log("Banner refresh failed: ${error.message}");
              return;
            }
            ad.dispose();
            handleFailureAndRetry(error,
                onRetry: () => loadAd(isCollapsible: isCollapsible));
          },
        ),
      );

      // Load the banner ad.
      await bannerAd.load();
    } catch (error) {
      // Catch and log any errors that occur during ad loading.
      state = AdLoadState.failed;
      AppLogger.error("catch error loading banner: $error");
      handleFailureAndRetry(error,
          onRetry: () => loadAd(isCollapsible: isCollapsible));
    }
  }

  /// Hands the preloaded banner to a widget, or returns null if none is ready.
  ///
  /// In [PreloadMode.auto], taking a banner starts loading the next one so the
  /// following placement is also instant. When nothing was preloaded the
  /// widget loads its own banner, so no extra pool request is made.
  BannerAd? takeBanner() {
    _dropStale();
    if (bannerAdObject.isEmpty) return null;
    final ad = bannerAdObject.removeAt(0);
    // A request may already be in flight (started before a widget returned
    // a banner); leave its state alone so its result still lands in the pool.
    if (!isLoading) {
      loadTime = null;
      state = AdLoadState.initial;
      if (isAutoPreload) loadAd();
    }
    return ad;
  }

  /// Takes a banner back from a widget that left the screen, so the next
  /// placement shows it at once instead of requesting a new one.
  ///
  /// This is reuse, not a new request, so it also applies in
  /// [PreloadMode.manual]. The banner is disposed instead when banners are
  /// disabled, consent is missing, it is stale, or the pool already holds one.
  void returnBanner(BannerAd ad) {
    if (!isEnabled ||
        !AdManager.instance.canRequestAds ||
        _isStale(ad) ||
        bannerAdObject.isNotEmpty) {
      ad.dispose();
      return;
    }
    bannerAdObject.add(ad);
    AppLogger.log("Banner returned to the pool for reuse.");
    if (isLoading) return; // The in-flight result will replace it.
    cancelReloadTimer();
    loadTime = _loadedAt[ad] ?? DateTime.now();
    state = AdLoadState.ready;
    notifyPreloadResult(true);
  }

  /// Disposes of all loaded ads and resets the state.
  @override
  void reset() {
    for (final ad in bannerAdObject) {
      ad.dispose();
    }
    bannerAdObject.clear();
    super.reset();
  }
}
