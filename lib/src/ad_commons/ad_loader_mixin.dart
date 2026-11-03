import '../ad_internal.dart';

/// Represents the current lifecycle state of an ad loader.
enum AdLoadState {
  /// Ad has not been requested or has been reset.
  initial,

  /// Ad request is currently in flight.
  loading,

  /// Ad is successfully preloaded and ready to show.
  ready,

  /// Ad failed to load.
  failed,

  /// Ad is currently being displayed on screen.
  showing,
}

/// Base contract and unified handler for all ad format loaders in the package.
abstract class BaseAdLoader with AdLoaderMixin {
  /// Loads the target ad format asynchronously.
  void load();

  /// Checks whether the ad format is enabled in configuration and can be loaded/shown.
  bool get isEnabled;

  /// Human readable label for logging.
  String get adLabel;

  /// Maximum duration allowed between loading and showing an ad.
  ///
  /// Defaults to 4 hours (AdMob app open guidance). Formats with a shorter
  /// recommended lifetime (e.g. native ads, 1 hour) override this.
  Duration get maxCacheDuration => const Duration(hours: 4);

  /// Timestamp when the ad was successfully loaded into memory.
  DateTime? loadTime;

  Timer? _reloadTimer;

  /// Checks if the cached ad has passed the max cache duration.
  bool get isExpired {
    if (loadTime == null) return false;
    return DateTime.now().subtract(maxCacheDuration).isAfter(loadTime!);
  }

  /// Cancels any scheduled background reload timer to prevent memory leaks.
  void cancelReloadTimer() {
    _reloadTimer?.cancel();
    _reloadTimer = null;
  }

  /// Schedules a background load task safely.
  void scheduleReload(Duration duration, VoidCallback callback) {
    cancelReloadTimer();
    _reloadTimer = Timer(duration, () {
      _reloadTimer = null;
      callback();
    });
  }

  /// Shared helper to determine if loading can proceed.
  bool prepareLoad() {
    if (!isEnabled) {
      AppLogger.log("$adLabel ads are disabled.");
      return false;
    }
    if (!AdManager.instance.canRequestAds) {
      AppLogger.log("$adLabel: consent not obtained, ad request skipped.");
      return false;
    }
    if (isLoading || isShowing) {
      AppLogger.log("$adLabel is already ${state.name}. Skipping load request.");
      return false;
    }
    state = AdLoadState.loading;
    return true;
  }

  /// Handles successful load events across all ad types.
  void handleLoadSuccess() {
    AppLogger.log("$adLabel loaded successfully.");
    loadTime = DateTime.now();
    state = AdLoadState.ready;
    retryAttempts = maxRetries;
  }

  /// Centralized retry handling with a capped exponential backoff (5s, 10s, 20s).
  ///
  /// Following Google's guidance, failed requests are not retried endlessly:
  /// hammering the ad server after "no fill" errors lowers match rate and wastes
  /// battery. Once the attempts are used up the loader stays idle until the app
  /// asks for the ad again (a show call, [AdManager.reloadUnloadedAds], or the app
  /// returning to the foreground), which starts a fresh retry budget.
  void handleFailureAndRetry(dynamic error, {VoidCallback? onRetry}) {
    handleLoadError(adLabel, error);
    loadTime = null;
    if (retryAttempts > 0) {
      final attempt = maxRetries - retryAttempts; // 0-based
      retryAttempts--;
      final backoffSeconds = 5 * (1 << attempt);
      AppLogger.log(
        "Retrying $adLabel load in $backoffSeconds seconds (Remaining attempts: $retryAttempts)",
      );
      scheduleReload(Duration(seconds: backoffSeconds), () {
        if (onRetry != null) {
          onRetry();
        } else {
          load();
        }
      });
    } else {
      retryAttempts = maxRetries;
      AppLogger.log(
        "$adLabel failed after $maxRetries retries. Waiting for the next ad request before trying again.",
      );
    }
  }

  /// Centralized helper to evaluate showing condition against counters.
  bool canShowAd(int requiredLimit) {
    if (!isEnabled) return false;
    if (isAdLoaded && isLimitReached(requiredLimit)) {
      return true;
    }
    incrementCounter();
    if (!isAdLoaded && state != AdLoadState.loading) {
      load();
    }
    return false;
  }

  /// Resets state and disposes resources. Subclasses should override and call super.reset().
  @override
  void reset() {
    cancelReloadTimer();
    super.reset();
  }
}

/// Tracks full-screen ad activity so App Open ads never stack on top of,
/// or immediately follow, another full-screen ad or an ad click.
///
/// Google's App Open guidance: don't show an App Open ad when the user returns
/// to the app from an interstitial/rewarded ad or from a clicked ad.
class FullScreenAdGuard {
  FullScreenAdGuard._();

  /// True while any interstitial, rewarded or app open ad is on screen.
  static bool isShowing = false;

  /// Set when an ad is clicked; the next foreground event is ignored.
  static bool suppressNextAppOpen = false;

  static DateTime? _lastDismissed;

  /// Grace period after a full-screen ad closes during which App Open is skipped.
  static const Duration cooldown = Duration(seconds: 5);

  /// Call when a full-screen ad is presented.
  static void onShown() => isShowing = true;

  /// Call when a full-screen ad is dismissed or fails to show.
  static void onDismissed() {
    isShowing = false;
    _lastDismissed = DateTime.now();
  }

  /// Call when the user clicks an ad (they are leaving the app).
  static void onClicked() => suppressNextAppOpen = true;

  /// Whether an App Open ad may be shown right now. Consumes the click suppression.
  static bool canShowAppOpen() {
    if (isShowing) return false;
    if (suppressNextAppOpen) {
      suppressNextAppOpen = false;
      return false;
    }
    final last = _lastDismissed;
    if (last != null && DateTime.now().difference(last) < cooldown) return false;
    return true;
  }
}

/// A mixin to provide next-level ad loading and lifecycle state management.
mixin AdLoaderMixin {
  /// Current state of the ad loader.
  AdLoadState state = AdLoadState.initial;

  /// Counter to track when the ad should be shown.
  int counter = 0;

  /// Max load retries allowed on failure.
  int maxRetries = 3;

  /// Current retry attempt remaining.
  int retryAttempts = 3;

  /// Convenient boolean getter for loaded status.
  bool get isAdLoaded => state == AdLoadState.ready;

  /// Convenient boolean getter for loading status.
  bool get isLoading => state == AdLoadState.loading;

  /// Convenient boolean getter for showing status.
  bool get isShowing => state == AdLoadState.showing;

  /// Convenient boolean getter for failed status.
  bool get isFailed => state == AdLoadState.failed;

  /// Legacy reloadAdCount alias for retryAttempts.
  int get reloadAdCount => retryAttempts;

  /// Legacy setter compatibility
  set isAdLoaded(bool value) {
    if (value) {
      state = AdLoadState.ready;
    } else if (state == AdLoadState.ready) {
      state = AdLoadState.initial;
    }
  }

  /// Resets the counter to zero.
  void resetCounter() {
    counter = 0;
  }

  /// Increments the counter.
  void incrementCounter() {
    counter++;
  }

  /// Checks if the counter has reached the required limit.
  bool isLimitReached(int limit) {
    return counter >= limit;
  }

  /// Shared error handling and logging for ad loading.
  void handleLoadError(String adType, dynamic error) {
    AppLogger.error("Failed to load $adType: $error");
    state = AdLoadState.failed;
  }

  /// Resets the ad lifecycle state cleanly.
  void reset() {
    state = AdLoadState.initial;
    counter = 0;
    retryAttempts = maxRetries;
  }
}
