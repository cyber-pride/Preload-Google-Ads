import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:preload_google_ads/src/ad_internal.dart';

Future<void> useConfig(AdConfigData cfg) async {
  AdManager.instance.config = await setConfigData(cfg, releaseMode: false);
}

/// AdCounter's `…Seconds`: an ad shows only when the count is reached AND
/// enough time has passed since the last ad of that format.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loaders = <BaseAdLoader>[
    InterAd.instance,
    RewardAd.instance,
    RewardInterAd.instance,
    LoadSmallNative.instance,
  ];

  void resetAll() {
    for (final l in loaders) {
      l.reset();
      l.counter = 0;
      l.hasShownFirstAd = false;
      l.lastAdShownTime = null;
    }
  }

  setUp(() {
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

  DateTime secondsAgo(int s) => DateTime.now().subtract(Duration(seconds: s));

  test('seconds default to 0 and survive a config merge', () async {
    await useConfig(AdConfigData());
    expect(getInterSeconds, 0);
    expect(getRewardedSeconds, 0);
    expect(getRewardedInterSeconds, 0);
    expect(getNativeSeconds, 0);

    await useConfig(AdConfigData(
      adCounter: AdCounter(interstitialSeconds: 120, nativeSeconds: 30),
    ));
    expect(getInterSeconds, 120);
    expect(getNativeSeconds, 30);
    expect(getInterCounter, 3, reason: 'Counter keeps its default.');
  });

  test('no time limit (0): the gap always counts as passed', () async {
    await useConfig(AdConfigData());
    InterAd.instance.resetCounter(); // an ad was just shown
    expect(InterAd.instance.hasTimeGapPassed, isTrue);
  });

  test('count reached too soon: no ad, count kept, load waits for the gap',
      () async {
    await useConfig(AdConfigData(
      adCounter: AdCounter(interstitialCounter: 3, interstitialSeconds: 120),
    ));
    final inter = InterAd.instance;
    inter.resetCounter(); // an interstitial was shown just now
    expect(inter.hasTimeGapPassed, isFalse);

    for (var i = 0; i < 4; i++) {
      var called = false;
      final shown = inter.showInter(callBack: ({ad, error}) => called = true);
      expect(shown, isFalse);
      expect(called, isTrue);
    }
    expect(inter.counter, 4, reason: 'Count is kept until an ad shows.');
    expect(inter.state, AdLoadState.initial,
        reason: '120s gap left: loading now would leave the ad unused.');
    expect(inter.isTimeGapLoadScheduled, isTrue,
        reason: 'A load is scheduled for shortly before the gap ends.');

    inter.lastAdShownTime = secondsAgo(120);
    expect(inter.hasTimeGapPassed, isTrue);
  });

  test('next ad loads once the gap is within the load lead', () async {
    await useConfig(AdConfigData(
      adCounter: AdCounter(interstitialCounter: 1, interstitialSeconds: 60),
    ));
    final inter = InterAd.instance;

    inter.resetCounter(); // shown just now
    inter.autoLoadIfDue(); // as dismissing the ad does
    expect(inter.isLoadDue, isFalse);
    expect(inter.state, AdLoadState.initial);
    expect(inter.isTimeGapLoadScheduled, isTrue);

    inter.lastAdShownTime = secondsAgo(55); // 5s left, inside the 10s lead
    expect(inter.isLoadDue, isTrue);
    inter.autoLoadIfDue();
    expect(inter.state, AdLoadState.loading);
    expect(inter.isTimeGapLoadScheduled, isFalse);
  });

  test('the scheduled load fires before the gap ends', () async {
    await useConfig(AdConfigData(
      adCounter: AdCounter(rewardedCounter: 1, rewardedSeconds: 30),
    ));
    final rewarded = RewardAd.instance;
    // 11s left: the load is due in ~1s (10s lead).
    rewarded.lastAdShownTime = secondsAgo(19);
    rewarded.autoLoadIfDue();
    expect(rewarded.state, AdLoadState.initial);
    expect(rewarded.isTimeGapLoadScheduled, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(rewarded.state, AdLoadState.loading);
  });

  test('counter not due: nothing is scheduled', () async {
    await useConfig(AdConfigData(
      adCounter: AdCounter(interstitialCounter: 3, interstitialSeconds: 60),
    ));
    final inter = InterAd.instance;
    inter.resetCounter();
    inter.autoLoadIfDue();
    expect(inter.isTimeGapLoadScheduled, isFalse);
    expect(inter.state, AdLoadState.initial);
  });

  test('reset cancels a scheduled load', () async {
    await useConfig(AdConfigData(
      adCounter: AdCounter(interstitialCounter: 1, interstitialSeconds: 60),
    ));
    final inter = InterAd.instance;
    inter.resetCounter();
    inter.autoLoadIfDue();
    expect(inter.isTimeGapLoadScheduled, isTrue);
    inter.reset();
    expect(inter.isTimeGapLoadScheduled, isFalse);
  });

  test('first ad has no previous ad, so the gap does not block it', () async {
    await useConfig(AdConfigData(
      adCounter:
          AdCounter(interstitialShowAdFirst: true, interstitialSeconds: 120),
    ));
    expect(InterAd.instance.hasTimeGapPassed, isTrue);
  });

  test('each format uses its own seconds and its own last-shown time',
      () async {
    await useConfig(AdConfigData(
      adCounter: AdCounter(
        interstitialSeconds: 120,
        rewardedSeconds: 30,
        rewardedInterstitialSeconds: 60,
      ),
    ));
    for (final l in [
      InterAd.instance,
      RewardAd.instance,
      RewardInterAd.instance
    ]) {
      l.lastAdShownTime = secondsAgo(45);
    }
    expect(InterAd.instance.hasTimeGapPassed, isFalse);
    expect(RewardAd.instance.hasTimeGapPassed, isTrue);
    expect(RewardInterAd.instance.hasTimeGapPassed, isFalse);
  });

  testWidgets('native placement waits for the time gap', (tester) async {
    await useConfig(AdConfigData(
      adCounter: AdCounter(nativeCounter: 0, nativeSeconds: 60),
    ));
    final native = LoadSmallNative.instance;
    native.state = AdLoadState.loading; // keep the widget off the channel

    Future<void> place() async {
      await tester.pumpWidget(
        ShowNative(key: UniqueKey(), nativeADType: NativeADType.small),
      );
      await tester.pumpWidget(const SizedBox());
    }

    await place();
    expect(native.lastAdShownTime, isNotNull, reason: 'First placement shows.');
    expect(native.counter, 0);

    await place();
    expect(native.counter, 1, reason: 'Within 60s: hidden.');

    native.lastAdShownTime = secondsAgo(61);
    await place();
    expect(native.counter, 0, reason: 'Gap passed: shown.');
  });
}
