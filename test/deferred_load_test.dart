import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:preload_google_ads/src/ad_internal.dart';

Future<void> useConfig(AdConfigData cfg) async {
  AdManager.instance.config = await setConfigData(cfg, releaseMode: false);
}

/// Auto-preload waits until the trigger before the one that shows an ad.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loaders = <BaseAdLoader>[
    InterAd.instance,
    RewardAd.instance,
    RewardInterAd.instance,
    AppOpenAdManager.instance,
    LoadBannerAd.instance,
    LoadMediumNative.instance,
    LoadSmallNative.instance,
  ];

  void resetAll() {
    for (final l in loaders) {
      l.reset();
      l.counter = 0;
      l.hasShownFirstAd = false;
    }
  }

  setUp(() {
    // Ad requests reach a no-op platform side, so a load only flips the
    // loader to AdLoadState.loading.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(instanceManager.channel, (_) async => null);
    AdManager.instance.debugSdkStarted = true;
    AdManager.instance.canRequestAds = true;
    resetAll();
  });

  tearDown(() async {
    resetAll();
    AdManager.instance.debugSdkStarted = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(instanceManager.channel, null);
    await useConfig(AdConfigData());
  });

  void trigger() => InterAd.instance.showInter(callBack: ({ad, error}) {});

  test('counter 3: loads on the 2nd trigger, not at startup or the 1st',
      () async {
    await useConfig(AdConfigData(adCounter: AdCounter(interstitialCounter: 3)));
    final inter = InterAd.instance;

    AdManager.instance.reloadUnloadedAds();
    expect(inter.state, AdLoadState.initial, reason: 'Not due at startup.');

    trigger(); // 1
    expect(inter.state, AdLoadState.initial, reason: 'Not due after 1st.');

    trigger(); // 2
    expect(inter.state, AdLoadState.loading, reason: 'Due: 3rd shows.');
  });

  test('after a show the next ad waits for the counter again', () async {
    await useConfig(AdConfigData(adCounter: AdCounter(interstitialCounter: 3)));
    final inter = InterAd.instance;

    inter.resetCounter(); // as a show does
    inter.autoLoadIfDue(); // as dismissing the ad does
    expect(inter.state, AdLoadState.initial);
    expect(inter.isLoadDue, isFalse);
  });

  test('counter 0 or 1 still loads right away', () async {
    for (final limit in [0, 1]) {
      await useConfig(
          AdConfigData(adCounter: AdCounter(interstitialCounter: limit)));
      resetAll();
      AdManager.instance.reloadUnloadedAds();
      expect(InterAd.instance.state, AdLoadState.loading, reason: '$limit');
    }
  });

  test('counter 2: loads on the 1st trigger', () async {
    await useConfig(AdConfigData(adCounter: AdCounter(interstitialCounter: 2)));
    AdManager.instance.reloadUnloadedAds();
    expect(InterAd.instance.state, AdLoadState.initial);
    trigger();
    expect(InterAd.instance.state, AdLoadState.loading);
  });

  test('interstitialShowAdFirst preloads at startup for the first trigger',
      () async {
    await useConfig(AdConfigData(
      adCounter:
          AdCounter(interstitialShowAdFirst: true, interstitialCounter: 3),
    ));
    AdManager.instance.reloadUnloadedAds();
    expect(InterAd.instance.state, AdLoadState.loading);
  });

  test('rewarded formats follow their own counters', () async {
    await useConfig(AdConfigData(
      adCounter: AdCounter(rewardedCounter: 3, rewardedInterstitialCounter: 2),
    ));
    AdManager.instance.reloadUnloadedAds();
    expect(RewardAd.instance.state, AdLoadState.initial);
    expect(RewardInterAd.instance.state, AdLoadState.initial);

    RewardAd.instance
        .showRewarded(callBack: ({ad, error}) {}, onReward: (_, __) {});
    RewardInterAd.instance
        .showRewardedInter(callBack: ({ad, error}) {}, onReward: (_, __) {});
    expect(RewardAd.instance.state, AdLoadState.initial);
    expect(RewardInterAd.instance.state, AdLoadState.loading);
  });

  test('native counter 2 (shows every 3rd placement): due after 2 skips',
      () async {
    await useConfig(AdConfigData(adCounter: AdCounter(nativeCounter: 2)));
    final native = LoadSmallNative.instance;
    expect(native.isLoadDue, isFalse);
    native.incrementCounter();
    expect(native.isLoadDue, isFalse);
    native.incrementCounter();
    expect(native.isLoadDue, isTrue);
  });

  test('explicit preload ignores the counter', () async {
    await useConfig(AdConfigData(adCounter: AdCounter(interstitialCounter: 5)));
    InterAd.instance.preload();
    expect(InterAd.instance.state, AdLoadState.loading);
  });
}
