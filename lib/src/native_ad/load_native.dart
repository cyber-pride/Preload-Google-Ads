import '../ad_internal.dart';

/// Base class for loading native ads to reduce code duplication.
abstract class BaseNativeAdLoader extends BaseAdLoader {
  /// List to store the loaded native ads.
  List<NativeAd> ads = [];

  /// Notifies waiting native ad widgets whenever a new ad enters [ads].
  final ValueNotifier<int> adAvailable = ValueNotifier(0);

  /// Bumped by [reset]; a load started before a reset is stale and its result
  /// is dropped (e.g. an ad styled for the old theme).
  int _generation = 0;

  /// Google recommends discarding native ads that were loaded but not shown
  /// within one hour.
  @override
  Duration get maxCacheDuration => const Duration(hours: 1);

  /// Most unseen ads kept for reuse; extra ones are disposed.
  static const int _maxPooled = 3;

  /// Per-ad bookkeeping: when each ad loaded, which [_generation] it belongs
  /// to, and whether it has recorded an impression.
  final Expando<DateTime> _loadedAt = Expando('loadedAt');
  final Expando<int> _generationOf = Expando('generation');
  final Expando<bool> _impressed = Expando('impressed');

  /// Whether [ad] is still within [maxCacheDuration].
  bool _isFresh(NativeAd ad) {
    final loadedAt = _loadedAt[ad];
    return loadedAt == null ||
        DateTime.now().difference(loadedAt) < maxCacheDuration;
  }

  /// Keeps [state] and [loadTime] (the oldest pooled ad) in line with [ads].
  void _syncPoolState() {
    if (ads.isEmpty) {
      loadTime = null;
      if (state == AdLoadState.ready) state = AdLoadState.initial;
      return;
    }
    DateTime? oldest;
    for (final ad in ads) {
      final t = _loadedAt[ad];
      if (t != null && (oldest == null || t.isBefore(oldest))) oldest = t;
    }
    loadTime = oldest ?? loadTime;
    if (state != AdLoadState.loading) state = AdLoadState.ready;
  }

  /// Takes the cached ad for display, or returns null if none is ready.
  ///
  /// Expired ads are disposed instead of shown. In [PreloadMode.auto] a fresh
  /// load refills the pool for the next placement; in [PreloadMode.manual] a
  /// load starts only when no ad was ready, because the calling widget is on
  /// screen and waiting for one.
  NativeAd? takeAd() {
    final expired = ads.where((ad) => !_isFresh(ad)).toList();
    if (expired.isNotEmpty) {
      AppLogger.warn("$adTypeLabel ad expired. Fetching fresh ad.");
      for (final old in expired) {
        ads.remove(old);
        old.dispose();
      }
    }
    final ad = ads.isNotEmpty ? ads.removeAt(0) : null;
    _syncPoolState();
    if (isAutoPreload || ad == null) loadAd();
    return ad;
  }

  /// Marks [ad] as loaded now (or at [at]) by the current load cycle, as a
  /// real load would.
  @visibleForTesting
  void debugMarkLoaded(NativeAd ad, {DateTime? at}) {
    _loadedAt[ad] = at ?? DateTime.now();
    _generationOf[ad] = _generation;
  }

  /// Records an impression for [ad], as the SDK callback would.
  @visibleForTesting
  void debugMarkImpression(NativeAd ad) => _impressed[ad] = true;

  /// Takes back an ad from a widget that left the screen.
  ///
  /// In a fast-scrolled list a placement can be built and removed before its
  /// ad is ever seen. Disposing it would waste the request (a load with no
  /// impression), so an ad without an impression goes back into the pool for
  /// the next placement. Ads that were seen, expired, styled for an old theme,
  /// or exceed the pool size are disposed.
  void recycle(NativeAd ad) {
    final reusable = _impressed[ad] != true &&
        _isFresh(ad) &&
        _generationOf[ad] == _generation &&
        isEnabled &&
        ads.length < _maxPooled &&
        !ads.contains(ad);
    if (!reusable) {
      ad.dispose();
      return;
    }
    ads.insert(0, ad);
    _syncPoolState();
    // Called while the widget tree is being torn down: notify waiting
    // placements afterwards, when they may call setState.
    scheduleMicrotask(() => adAvailable.value++);
  }

  @override
  bool get isEnabled => shouldShowNativeAd;

  @override
  bool get isAutoPreload => autoPreloadNativeAd;

  @override
  bool get hasReadyAd => ads.any(_isFresh);

  @override
  void discardAd() {
    for (final ad in ads) {
      ad.dispose();
    }
    ads.clear();
    super.discardAd();
  }

  @override
  String get adLabel => adTypeLabel;

  @override
  void load() {
    loadAd();
  }

  /// Abstract getters for ad-specific configuration.
  /// The factory ID to use for this ad loader.
  String? get factoryId;

  /// The template style to use for this ad loader.
  NativeTemplateStyle? get templateStyle;

  /// The stats for loaded ads.
  ValueNotifier<int> get loadStats;

  /// The stats for ad impressions.
  ValueNotifier<int> get impStats;

  /// The stats for failed ad loads.
  ValueNotifier<int> get failedStats;

  /// The human-readable label for this ad type.
  String get adTypeLabel;

  /// Loads a native ad.
  Future<void> loadAd() async {
    if (ads.isNotEmpty || !prepareLoad()) return;

    final generation = _generation;
    try {
      NativeAd? nativeAd;
      nativeAd = NativeAd(
        factoryId: factoryId,
        adUnitId: unitIDNative,
        nativeTemplateStyle: templateStyle,
        listener: NativeAdListener(
          onAdLoaded: (ad) async {
            loadStats.value++;
            if (generation != _generation) {
              ad.dispose();
              return;
            }
            final loaded = ad as NativeAd;
            _loadedAt[loaded] = DateTime.now();
            _generationOf[loaded] = generation;
            ads.add(loaded);
            handleLoadSuccess();
            _syncPoolState();
            adAvailable.value++;
          },
          onAdImpression: (ad) {
            impStats.value++;
            _impressed[ad] = true;
            // The impression can arrive just after the widget was removed and
            // the ad recycled: an ad that was seen must not be shown again.
            if (ads.remove(ad)) {
              ad.dispose();
              _syncPoolState();
            }
          },
          onAdFailedToLoad: (ad, error) {
            failedStats.value++;
            ad.dispose();
            if (generation != _generation) return;
            handleFailureAndRetry(error, onRetry: () => loadAd());
          },
        ),
        request: const AdRequest(),
      );
      await nativeAd.load();
    } catch (error) {
      state = AdLoadState.failed;
      AppLogger.error("Error in $adTypeLabel ad load catch: $error");
      handleFailureAndRetry(error, onRetry: () => loadAd());
    }
  }

  /// Disposes of all loaded ads and resets the state.
  @override
  void reset() {
    for (final ad in ads) {
      ad.dispose();
    }
    ads.clear();
    _generation++;
    super.reset();
  }
}

///==============================================================================
///   ** Medium Native ***
///==============================================================================

/// A singleton class that loads medium native ads.
class LoadMediumNative extends BaseNativeAdLoader {
  /// Singleton instance of [LoadMediumNative].
  static final LoadMediumNative instance = LoadMediumNative._internal();

  /// Factory constructor to provide access to the singleton [LoadMediumNative].
  factory LoadMediumNative() => instance;

  /// Private constructor for [LoadMediumNative] singleton.
  LoadMediumNative._internal();

  @override
  String? get factoryId => NativeADStyle.instance.mediumNativeFactoryId;

  @override
  NativeTemplateStyle? get templateStyle =>
      NativeADStyle.instance.nativeMediumTemplateStyle;

  /// Statistics for medium native ad loads.
  @override
  ValueNotifier<int> get loadStats => AdStats.instance.nativeLoadM;

  /// Statistics for medium native ad impressions.
  @override
  ValueNotifier<int> get impStats => AdStats.instance.nativeImpM;

  /// Statistics for medium native ad load failures.
  @override
  ValueNotifier<int> get failedStats => AdStats.instance.nativeFailedM;
  @override
  String get adTypeLabel => "Medium Native";

  /// Compatibility getter for existing code to access medium native ads.
  List<NativeAd> get nativeObjectLarge => ads;
}

///==============================================================================
///   ** Small Native ***
///==============================================================================

/// A singleton class that loads small native ads.
class LoadSmallNative extends BaseNativeAdLoader {
  /// Singleton instance of [LoadSmallNative].
  static final LoadSmallNative instance = LoadSmallNative._internal();

  /// Factory constructor to provide access to the singleton [LoadSmallNative].
  factory LoadSmallNative() => instance;

  /// Private constructor for [LoadSmallNative] singleton.
  LoadSmallNative._internal();

  @override
  String? get factoryId => NativeADStyle.instance.smallNativeFactoryId;

  @override
  NativeTemplateStyle? get templateStyle =>
      NativeADStyle.instance.nativeSmallTemplateStyle;

  /// Statistics for small native ad loads.
  @override
  ValueNotifier<int> get loadStats => AdStats.instance.nativeLoadS;

  /// Statistics for small native ad impressions.
  @override
  ValueNotifier<int> get impStats => AdStats.instance.nativeImpS;

  /// Statistics for small native ad load failures.
  @override
  ValueNotifier<int> get failedStats => AdStats.instance.nativeFailedS;

  /// Label for small native ads.
  @override
  String get adTypeLabel => "Small Native";

  /// Compatibility getter for existing code to access small native ads.
  List<NativeAd> get nativeObjectSmall => ads;
}
