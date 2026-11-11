import 'package:flutter_test/flutter_test.dart';
import 'package:preload_google_ads/src/ad_internal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Google best-practice safeguards', () {
    test('Retries are capped (5s/10s/20s) and then stop instead of looping', () {
      final loader = InterAd.instance;
      loader.reset();

      for (var i = 0; i < 3; i++) {
        loader.handleFailureAndRetry('no fill', onRetry: () {});
      }
      expect(loader.retryAttempts, 0);

      // Fourth failure: give up and reset the budget for the next on-demand request.
      loader.handleFailureAndRetry('no fill', onRetry: () {});
      expect(loader.retryAttempts, loader.maxRetries);
      expect(loader.isFailed, isTrue);
      loader.reset();
    });

    test('Native ads expire after 1 hour; full-screen formats after 4 hours', () {
      expect(LoadMediumNative.instance.maxCacheDuration, const Duration(hours: 1));
      expect(LoadSmallNative.instance.maxCacheDuration, const Duration(hours: 1));
      expect(InterAd.instance.maxCacheDuration, const Duration(hours: 4));
      expect(AppOpenAdManager.instance.maxCacheDuration, const Duration(hours: 4));
    });

    test('App Open is blocked while another full-screen ad is showing', () {
      FullScreenAdGuard.onShown();
      expect(FullScreenAdGuard.canShowAppOpen(), isFalse);
    });

    test('App Open is blocked right after a full-screen ad is dismissed', () {
      FullScreenAdGuard.onShown();
      FullScreenAdGuard.onDismissed();
      expect(FullScreenAdGuard.canShowAppOpen(), isFalse);
    });

    test('Release build disables formats with no ad unit ID (no silent test ads)', () async {
      final cfg = await setConfigData(
        AdConfigData(adIDs: AdIDS(interstitialId: 'ca-app-pub-1111111111111111/2222222222')),
        releaseMode: true,
      );
      expect(cfg.adFlag?.showInterstitial, isTrue);
      expect(cfg.adFlag?.showBanner, isFalse);
      expect(cfg.adFlag?.showRewarded, isFalse);
      expect(cfg.adFlag?.showAppOpen, isFalse);
    });

    test('Debug build keeps formats enabled with Google test IDs', () async {
      final cfg = await setConfigData(null, releaseMode: false);
      expect(cfg.adFlag?.showBanner, isTrue);
      expect(isTestAdUnitId(cfg.adIDs?.bannerId), isTrue);
    });

    test('Default interstitial frequency is every 3rd trigger', () async {
      final cfg = await setConfigData(null, releaseMode: false);
      expect(cfg.adCounter?.interstitialCounter, 3);
    });

    test('No ad is requested while consent is missing', () {
      final loader = InterAd.instance;
      loader.reset();
      AdManager.instance.canRequestAds = false;
      expect(loader.prepareLoad(), isFalse);
      expect(loader.isLoading, isFalse);
      AdManager.instance.canRequestAds = true;
    });

    test('Consent settings survive a theme change', () {
      final cfg = AdConfigData(requireConsent: true).copyWith(themeMode: AdThemeMode.dark);
      expect(cfg.requireConsent, isTrue);
      expect(cfg.themeMode, AdThemeMode.dark);
    });

    test('Custom native ad sizes are honored', () {
      const medium = BoxConstraints(minHeight: 300, maxHeight: 320);
      const small = BoxConstraints(minHeight: 90, maxHeight: 100);
      final custom = CustomNativeADStyle(mediumBoxConstrain: medium, smallBoxConstrain: small);
      final flutter = FlutterNativeADStyle(mediumBoxConstrain: medium, smallBoxConstrain: small);
      expect(custom.mediumBoxConstrain, medium);
      expect(custom.smallBoxConstrain, small);
      expect(flutter.mediumBoxConstrain, medium);
      expect(flutter.smallBoxConstrain, small);
    });

    test('App Open is skipped once after the user clicks an ad', () {
      FullScreenAdGuard.isShowing = false;
      FullScreenAdGuard.onClicked();
      expect(FullScreenAdGuard.suppressNextAppOpen, isTrue);
      expect(FullScreenAdGuard.canShowAppOpen(), isFalse);
      expect(FullScreenAdGuard.suppressNextAppOpen, isFalse);
    });
  });
}
