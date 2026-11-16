import 'package:flutter_test/flutter_test.dart';
import 'package:preload_google_ads/src/ad_internal.dart';

Future<void> useConfig(AdConfigData cfg) async {
  AdManager.instance.config = await setConfigData(cfg, releaseMode: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loaders = <BaseAdLoader>[
    InterAd.instance,
    RewardAd.instance,
    RewardInterAd.instance,
    LoadSmallNative.instance,
  ];

  setUp(() {
    AdManager.instance.debugSdkStarted = true;
    AdManager.instance.canRequestAds = true;
    for (final l in loaders) {
      l.reset();
      l.counter = 0;
      l.hasShownFirstAd = false;
      // Keep unit tests off the platform channel: a load "in flight" makes
      // every load request a no-op.
      l.state = AdLoadState.loading;
    }
  });

  tearDown(() async {
    for (final l in loaders) {
      l.reset();
      l.counter = 0;
      l.hasShownFirstAd = false;
    }
    AdManager.instance.debugSdkStarted = false;
    await useConfig(AdConfigData());
  });

  test('showAdFirst defaults to false and survives a config merge', () async {
    await useConfig(AdConfigData());
    expect(getShowAdFirst, isFalse);

    await useConfig(AdConfigData(adCounter: AdCounter(showAdFirst: true)));
    expect(getShowAdFirst, isTrue);
    // Leaving the counter numbers out keeps their defaults.
    expect(getInterCounter, 3);
  });

  test('default (false): first interstitial call only counts', () async {
    await useConfig(AdConfigData(adCounter: AdCounter(interstitialCounter: 3)));
    final loader = InterAd.instance;

    expect(loader.isFirstAdPending, isFalse);
    var called = false;
    final shown = loader.showInter(callBack: ({ad, error}) => called = true);
    expect(shown, isFalse);
    expect(called, isTrue);
    expect(loader.counter, 1);
  });

  test('true: first trigger is allowed to show, then the counter takes over',
      () async {
    await useConfig(AdConfigData(
      adCounter: AdCounter(interstitialCounter: 3, showAdFirst: true),
    ));
    final loader = InterAd.instance;
    expect(loader.isFirstAdPending, isTrue);

    // No ad ready yet: nothing shown, and the first-ad slot stays pending so
    // the next call tries again.
    loader.showInter(callBack: ({ad, error}) {});
    expect(loader.isFirstAdPending, isTrue);

    // An ad shown resets the counter, which ends the "first" phase.
    loader.resetCounter();
    expect(loader.isFirstAdPending, isFalse);
    loader.showInter(callBack: ({ad, error}) {});
    expect(loader.counter, 1);
  });

  test('each full-screen format tracks its own first ad', () async {
    await useConfig(AdConfigData(adCounter: AdCounter(showAdFirst: true)));
    InterAd.instance.resetCounter();
    expect(InterAd.instance.isFirstAdPending, isFalse);
    expect(RewardAd.instance.isFirstAdPending, isTrue);
    expect(RewardInterAd.instance.isFirstAdPending, isTrue);
  });

  Future<void> placeNative(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ShowNative(key: UniqueKey(), nativeADType: NativeADType.small),
    ));
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('native, default: placements are skipped first', (tester) async {
    await useConfig(AdConfigData(adCounter: AdCounter(nativeCounter: 2)));
    final loader = LoadSmallNative.instance;

    await placeNative(tester);
    expect(loader.counter, 1); // skipped
    expect(loader.hasShownFirstAd, isFalse);
  });

  testWidgets('native, showAdFirst: first placement shows, then counts',
      (tester) async {
    await useConfig(AdConfigData(
      adCounter: AdCounter(nativeCounter: 2, showAdFirst: true),
    ));
    final loader = LoadSmallNative.instance;

    await placeNative(tester);
    expect(loader.hasShownFirstAd, isTrue); // shown
    expect(loader.counter, 0);

    await placeNative(tester);
    expect(loader.counter, 1); // skipped
    await placeNative(tester);
    expect(loader.counter, 2); // skipped
    await placeNative(tester);
    expect(loader.counter, 0); // shown
  });
}
