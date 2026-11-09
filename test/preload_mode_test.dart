import 'package:flutter_test/flutter_test.dart';
import 'package:preload_google_ads/src/ad_internal.dart';

/// Applies [cfg] as the active config, as initialize() would.
Future<void> useConfig(AdConfigData cfg) async {
  AdManager.instance.config = await setConfigData(cfg, releaseMode: false);
}

NativeAd fakeNative() => NativeAd(
      adUnitId: 'test',
      factoryId: 'medium_native',
      listener: NativeAdListener(),
      request: const AdRequest(),
    );

BannerAd fakeBanner() => BannerAd(
      adUnitId: 'test',
      size: AdSize.banner,
      listener: const BannerAdListener(),
      request: const AdRequest(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manual = AdConfigData(
    preloadConfig: const AdPreloadConfig.all(PreloadMode.manual),
    adCounter: AdCounter(interstitialCounter: 0),
  );

  final loaders = <BaseAdLoader>[
    InterAd.instance,
    RewardAd.instance,
    RewardInterAd.instance,
    AppOpenAdManager.instance,
    LoadBannerAd.instance,
    LoadMediumNative.instance,
    LoadSmallNative.instance,
  ];

  setUp(() {
    AdManager.instance.debugSdkStarted = true;
    AdManager.instance.canRequestAds = true;
    for (final l in loaders) {
      l.reset();
    }
  });

  tearDown(() async {
    for (final l in loaders) {
      l.reset();
    }
    AdManager.instance.debugSdkStarted = false;
    await useConfig(AdConfigData());
  });

  group('Config', () {
    test('every format defaults to auto (unchanged behavior)', () async {
      await useConfig(AdConfigData());
      for (final l in loaders) {
        expect(l.isAutoPreload, isTrue, reason: l.adLabel);
      }
    });

    test('per-format modes merge onto the current config', () async {
      final first = await setConfigData(
        AdConfigData(preloadConfig: const AdPreloadConfig(rewarded: PreloadMode.manual)),
      );
      final second = await setConfigData(
        AdConfigData(preloadConfig: const AdPreloadConfig(native: PreloadMode.manual)),
        base: first,
      );
      expect(second.preloadConfig?.rewarded, PreloadMode.manual);
      expect(second.preloadConfig?.native, PreloadMode.manual);
      expect(second.preloadConfig?.interstitial, isNull);

      final third = await setConfigData(AdConfigData(), base: second);
      expect(third.preloadConfig?.rewarded, PreloadMode.manual,
          reason: 'Omitting preloadConfig keeps the current modes.');
    });
  });

  group('Manual mode never requests ads on its own', () {
    test('reloadUnloadedAds (startup / network back) skips manual formats', () async {
      await useConfig(manual);
      AdManager.instance.reloadUnloadedAds();
      for (final l in loaders) {
        expect(l.state, AdLoadState.initial, reason: l.adLabel);
      }
    });

    test('show call with no ad ready does not start a load', () async {
      await useConfig(manual);
      var called = false;
      final shown = InterAd.instance.showInter(callBack: ({ad, error}) => called = true);
      expect(shown, isFalse);
      expect(called, isTrue);
      expect(InterAd.instance.state, AdLoadState.initial);

      RewardAd.instance.showRewarded(callBack: ({ad, error}) {}, onReward: (_, __) {});
      expect(RewardAd.instance.state, AdLoadState.initial);

      AppOpenAdManager.instance.showAdIfAvailable();
      expect(AppOpenAdManager.instance.state, AdLoadState.initial);
    });

    test('taking a preloaded native ad does not refill the pool', () async {
      await useConfig(manual);
      final loader = LoadMediumNative.instance;
      loader.ads.add(fakeNative());
      loader.state = AdLoadState.ready;
      loader.loadTime = DateTime.now();

      expect(loader.takeAd(), isNotNull);
      expect(loader.state, AdLoadState.initial, reason: 'No refill request.');
    });

    test('taking a preloaded banner does not refill the pool', () async {
      await useConfig(manual);
      final loader = LoadBannerAd.instance;
      loader.bannerAdObject.add(fakeBanner());
      loader.state = AdLoadState.ready;

      expect(loader.takeBanner(), isNotNull);
      expect(loader.state, AdLoadState.initial);
    });
  });

  group('preload()', () {
    test('returns false before the SDK has started', () async {
      AdManager.instance.debugSdkStarted = false;
      expect(await InterAd.instance.preload(), isFalse);
      expect(InterAd.instance.state, AdLoadState.initial);
    });

    test('returns false without consent', () async {
      AdManager.instance.canRequestAds = false;
      expect(await RewardAd.instance.preload(), isFalse);
    });

    test('returns true at once when an ad is already ready', () async {
      final loader = InterAd.instance;
      loader.state = AdLoadState.ready;
      loader.loadTime = DateTime.now();
      expect(await loader.preload(), isTrue);
    });

    test('joins an in-flight load and completes when it succeeds', () async {
      await useConfig(manual);
      final loader = RewardAd.instance;
      loader.state = AdLoadState.loading; // a request is already in flight
      final result = loader.preload();
      expect(loader.state, AdLoadState.loading, reason: 'No duplicate request.');
      loader.handleLoadSuccess();
      expect(await result, isTrue);
    });

    test('completes with false when the load fails', () async {
      await useConfig(manual);
      final loader = RewardInterAd.instance;
      loader.state = AdLoadState.loading;
      final result = loader.preload();
      loader.handleFailureAndRetry('no fill', onRetry: () {});
      expect(await result, isFalse);
    });

    test('completes with false if the loader is reset meanwhile', () async {
      final loader = InterAd.instance;
      loader.state = AdLoadState.loading;
      final result = loader.preload();
      loader.reset();
      expect(await result, isFalse);
    });

    test('native preload is ready as soon as the pool has an ad', () async {
      await useConfig(manual);
      final loader = LoadSmallNative.instance;
      loader.ads.add(fakeNative());
      loader.state = AdLoadState.ready;
      loader.loadTime = DateTime.now();
      expect(await PreloadGoogleAds.instance.preloadNativeAd(nativeADType: NativeADType.small), isTrue);
      loader.ads.clear();
    });
  });
}
