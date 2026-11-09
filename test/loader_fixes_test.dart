import 'package:flutter_test/flutter_test.dart';
import 'package:preload_google_ads/src/ad_internal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Duplicate request protection', () {
    test('prepareLoad refuses to load while an ad is cached and ready', () {
      final loader = InterAd.instance;
      loader.reset();

      expect(loader.prepareLoad(), isTrue);
      loader.handleLoadSuccess();
      expect(loader.state, AdLoadState.ready);
      expect(loader.prepareLoad(), isFalse,
          reason: 'A second request would replace and leak the cached ad.');
      loader.reset();
    });

    test('a successful load cancels a pending retry', () {
      final loader = RewardAd.instance;
      loader.reset();

      var retried = false;
      loader.prepareLoad();
      loader.handleFailureAndRetry('no fill', onRetry: () => retried = true);

      // Another call path loads an ad before the retry timer fires.
      loader.state = AdLoadState.loading;
      loader.handleLoadSuccess();

      return Future<void>.delayed(const Duration(seconds: 6), () {
        expect(retried, isFalse);
        loader.reset();
      });
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('Show methods report whether an ad was presented', () {
    test('showInter returns false when no ad is shown', () {
      final loader = InterAd.instance;
      loader.reset();
      var called = false;
      final shown = loader.showInter(callBack: ({ad, error}) => called = true);
      expect(shown, isFalse);
      expect(called, isTrue);
      loader.reset();
    });

    test('showAdIfAvailable returns false with no App Open ad', () {
      AppOpenAdManager.instance.reset();
      // Pretend a request is in flight so no real platform call is made.
      AppOpenAdManager.instance.state = AdLoadState.loading;
      expect(AppOpenAdManager.instance.showAdIfAvailable(), isFalse);
      AppOpenAdManager.instance.reset();
    });
  });

  group('Banner pool', () {
    test('takeBanner returns null when nothing is preloaded', () {
      LoadBannerAd.instance.reset();
      LoadBannerAd.instance.state = AdLoadState.loading;
      expect(LoadBannerAd.instance.takeBanner(), isNull);
      LoadBannerAd.instance.reset();
    });
  });

  group('colorToHex', () {
    test('opaque colors stay #RRGGBB', () {
      expect(colorToHex(const Color(0xFF2196F3)), '#2196F3');
    });

    test('translucent colors keep alpha as #AARRGGBB', () {
      expect(colorToHex(const Color(0x802196F3)), '#802196F3');
    });
  });

  group('Theme fallback', () {
    test('system mode without context follows the device brightness', () {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      expect(NativeADStyle.instance.isDarkMode(), isTrue);
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      expect(NativeADStyle.instance.isDarkMode(), isFalse);
      binding.platformDispatcher.clearPlatformBrightnessTestValue();
    });
  });

  group('Repeat initialize merges into the current config', () {
    test('consent stays required when a later call omits it', () async {
      final first = await setConfigData(AdConfigData(requireConsent: true));
      final second = await setConfigData(AdConfigData(), base: first);
      expect(second.requireConsent, isTrue);
    });

    test('ad unit IDs, flags and theme are kept unless passed again', () async {
      final first = await setConfigData(
        AdConfigData(
          adIDs: AdIDS(interstitialId: 'ca-app-pub-1/1'),
          adFlag: AdFlag(showBanner: false),
          themeMode: AdThemeMode.dark,
        ),
        releaseMode: true,
      );
      final second = await setConfigData(
        AdConfigData(nativeADLayout: NativeADLayout()),
        base: first,
        releaseMode: true,
      );
      expect(second.adIDs?.interstitialId, 'ca-app-pub-1/1');
      expect(second.adFlag?.showInterstitial, isTrue,
          reason: 'A real ID set earlier must not be treated as missing.');
      expect(second.adFlag?.showBanner, isFalse);
      expect(second.themeMode, AdThemeMode.dark);

      final third = await setConfigData(
        AdConfigData(themeMode: AdThemeMode.light),
        base: second,
        releaseMode: true,
      );
      expect(third.themeMode, AdThemeMode.light);
    });

    test('first call still starts from the package defaults', () async {
      final cfg = await setConfigData(AdConfigData(), releaseMode: false);
      expect(cfg.requireConsent, isFalse);
      expect(cfg.themeMode, AdThemeMode.system);
      expect(cfg.adCounter?.interstitialCounter, 3);
    });
  });
}
