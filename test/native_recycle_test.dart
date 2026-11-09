import 'package:flutter_test/flutter_test.dart';
import 'package:preload_google_ads/src/ad_internal.dart';

NativeAd fakeNative() => NativeAd(
      adUnitId: 'test',
      factoryId: 'small_native',
      listener: NativeAdListener(),
      request: const AdRequest(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = LoadSmallNative.instance;

  setUp(() async {
    AdManager.instance.config = await setConfigData(
      AdConfigData(preloadConfig: const AdPreloadConfig(native: PreloadMode.manual)),
      releaseMode: false,
    );
    loader.reset();
  });
  tearDown(() => loader.reset());

  test('an unseen ad goes back to the pool for the next placement', () async {
    final ad = fakeNative();
    loader.debugMarkLoaded(ad);
    loader.ads.add(ad);

    expect(loader.takeAd(), same(ad));
    expect(loader.hasReadyAd, isFalse);

    // The placement scrolled away before the ad was seen.
    var notified = 0;
    void listener() => notified++;
    loader.adAvailable.addListener(listener);
    loader.recycle(ad);
    expect(loader.hasReadyAd, isTrue);
    expect(loader.state, AdLoadState.ready);
    await Future<void>.delayed(Duration.zero);
    expect(notified, 1, reason: 'Waiting placements must be told.');
    loader.adAvailable.removeListener(listener);

    expect(loader.takeAd(), same(ad), reason: 'Reused, no new request.');
  });

  test('a seen ad is not reused', () {
    final ad = fakeNative();
    loader.debugMarkLoaded(ad);
    loader.debugMarkImpression(ad);
    loader.recycle(ad);
    expect(loader.ads, isEmpty);
  });

  test('an expired ad is not reused', () {
    final ad = fakeNative();
    loader.debugMarkLoaded(ad,
        at: DateTime.now().subtract(const Duration(hours: 2)));
    loader.recycle(ad);
    expect(loader.ads, isEmpty);
  });

  test('an ad from before a reset (old theme) is not reused', () {
    final ad = fakeNative();
    loader.debugMarkLoaded(ad);
    loader.reset();
    loader.recycle(ad);
    expect(loader.ads, isEmpty);
  });

  test('the pool keeps at most 3 unseen ads', () {
    for (var i = 0; i < 5; i++) {
      final ad = fakeNative();
      loader.debugMarkLoaded(ad);
      loader.recycle(ad);
    }
    expect(loader.ads.length, 3);
  });

  test('expired ads are dropped individually when taking', () {
    final old = fakeNative();
    final fresh = fakeNative();
    loader.debugMarkLoaded(old,
        at: DateTime.now().subtract(const Duration(hours: 2)));
    loader.debugMarkLoaded(fresh);
    loader.ads.addAll([old, fresh]);
    expect(loader.takeAd(), same(fresh));
    expect(loader.ads, isEmpty);
  });
}
