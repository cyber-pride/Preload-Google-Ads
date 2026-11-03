import '../ad_internal.dart';

/// Manages the lifecycle of the app's ads, especially the App Open Ads.
class LifeCycleManager {
  /// Singleton instance of LifeCycleManager.
  static final LifeCycleManager instance = LifeCycleManager._internal();

  /// Factory constructor that returns the singleton instance of LifeCycleManager.
  factory LifeCycleManager() {
    return instance;
  }

  /// Private constructor to prevent external instantiation.
  LifeCycleManager._internal();

  /// Instance of AppOpenAdManager to manage app open ads.
  AppOpenAdManager appOpenAdManager = AppOpenAdManager.instance;

  AppLifecycleReactor? _appLifecycleReactor;

  /// Preloads an App Open ad and starts listening for the app returning to the
  /// foreground. Safe to call more than once: the listener is registered only once.
  Future<void> getOpenAppAdvertise() async {
    appOpenAdManager.loadAd();

    if (_appLifecycleReactor != null) return;
    _appLifecycleReactor = AppLifecycleReactor(
      appOpenAdManager: appOpenAdManager,
    )..listenToAppStateChanges();
  }
}

/// Reacts to app lifecycle changes and triggers the display of ads based on app state.
class AppLifecycleReactor {
  /// Instance of AppOpenAdManager to show app open ads.
  final AppOpenAdManager appOpenAdManager;

  /// Constructor that requires an instance of AppOpenAdManager.
  AppLifecycleReactor({required this.appOpenAdManager});

  StreamSubscription<AppState>? _subscription;

  /// Starts listening for app state changes and reacts accordingly.
  void listenToAppStateChanges() {
    if (_subscription != null) return;
    AppStateEventNotifier.startListening();
    _subscription = AppStateEventNotifier.appStateStream.listen(_onAppStateChanged);
  }

  /// Stops listening for app state changes.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    AppStateEventNotifier.stopListening();
  }

  /// Shows an App Open ad when the app returns to the foreground, unless the
  /// user is coming back from another full-screen ad or from clicking an ad.
  void _onAppStateChanged(AppState appState) {
    AppLogger.log('New AppState state: $appState');

    if (appState != AppState.foreground || !shouldShowOpenAppAd) return;

    if (!FullScreenAdGuard.canShowAppOpen()) {
      AppLogger.log('Skipping App Open ad: returning from another ad.');
      // Make sure an ad is ready for the next real resume.
      if (!appOpenAdManager.isAdAvailable) appOpenAdManager.loadAd();
      return;
    }

    appOpenAdManager.showAdIfAvailable();
  }
}
