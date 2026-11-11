## Unreleased

- **New: manual preloading per ad format**: `AdConfigData(preloadConfig: AdPreloadConfig(...))` sets each format to `PreloadMode.auto` (default, unchanged behavior) or `PreloadMode.manual`. Manual formats are never requested by the package on its own; load them with the new `preloadInterstitialAd()`, `preloadRewardedAd()`, `preloadRewardedInterstitialAd()`, `preloadAppOpenAd()`, `preloadBannerAd()` and `preloadNativeAd()`, which return `Future<bool>` (true once an ad is ready). Use it for formats on screens many users never open, to keep show rate high.
- **Banners**: when no banner was preloaded, showing one no longer also starts an extra pool request alongside the widget's own.
- `reloadUnloadedAds()` now does nothing before the SDK has started.
- **Fix: native ads in fast-scrolled lists**: an ad whose placement left the screen before it was seen is now reused by the next placement instead of being disposed. Before, scrolling quickly through a list loaded ads that never got an impression (e.g. 15 loads, 11 impressions), lowering show rate. Seen, expired or old-theme ads are still disposed, and at most 3 unseen ads are kept.
- **Fix: duplicate requests and leaked ads**: a load is now skipped while an ad is already cached, and a successful load cancels any pending retry. Before, a retry firing after another call had already loaded an ad sent a second request and replaced the cached ad without disposing it (interstitial, rewarded, rewarded interstitial, App Open).
- **Fix: calling `initialize()` again**: a repeat call now updates the current config instead of resetting it to defaults. Settings you leave out keep their current value; consent stays required once enabled (before, a second call without `requireConsent` let ads load without consent); cached ads whose ad unit ID, flag or style changed are replaced.
- **Fix: theme changes with `AdLayout.flutterLayout`**: switching light/dark now also refreshes cached Flutter-template native ads, and a native ad still loading when the theme changes is dropped instead of appearing in the old style.
- **Fix: dark mode at startup**: with `AdThemeMode.system`, native-layout ads now follow the device's light/dark setting from `initialize()`, not only after `setThemeMode(context:)`.
- **New**: `showInterstitialAd`, `showRewardedAd`, `showRewardedInterstitialAd` and `showAppOpenAd` return `true` when an ad is being presented and `false` when none was shown. Existing code that ignores the result is unaffected.
- **Banners**: showing the preloaded banner now starts loading the next one, so every banner placement is instant, not just the first.
- **Colors**: translucent style colors keep their alpha (`#AARRGGBB`) on Android and iOS.
- **iOS**: a single `buttonGradients` color is used as the button color, matching Android.
- **Android**: Kotlin JVM target now uses the `compilerOptions` DSL (works with Kotlin 2.3+).

## v1.0.8

- **Real preloading**: `initialize()` now preloads one ad per enabled format and registers App Open on app resume, so the first show is instant.
- **Consent (GDPR/UMP)**: new `requireConsent` and `consentRequestParameters` in `AdConfigData`, plus `isPrivacyOptionsRequired()`, `showPrivacyOptionsForm()` and `canRequestAds`. No ad is requested before consent allows it.
- **Policy-safe defaults**: interstitials now show every 3rd trigger by default (`interstitialCounter: 3`). In release builds, formats without an ad unit ID are disabled instead of serving test ads.
- **Show rate / match rate**: failed loads retry 3 times (5s, 10s, 20s) and then wait for the next request instead of retrying forever. Native ads expire after 1 hour.
- **App Open**: never shown over another full-screen ad, right after one closes, or after the user clicks an ad. Reloads after a failed show. Listener registered only once.
- **New**: `isInterstitialAdReady`, `isRewardedAdReady`, `isRewardedInterstitialAdReady`.
- **Fixes**: first native ad no longer stays blank; native ads no longer disappear on rebuild; banners loaded after the widget is gone are disposed; banner widgets respect the banner flag; `rewardedInterstitialCounter` now works; cached native ads refresh on light/dark change; style sync errors no longer stop initialization.
- **iOS**: native CTA taps now register as clicks; no crash when the AppDelegate is not a `FlutterPluginRegistry`.
- **Android**: native MediaView meets the 120x120dp minimum.

## v1.0.7

- **Network Interruption & Auto-Recovery**:
  - Implemented continuous background auto-recovery retry (15s periodic cycle) when initial backoff retries are exhausted due to network loss.
  - Ads automatically recover and preload into memory as soon as network connectivity is restored without requiring manual re-initialization.
  - Added robust exception handling across all ad format catch blocks (`RewardAd`, `InterAd`, `RewardInterAd`, `AppOpenAdManager`, `LoadBannerAd`, `BaseNativeAdLoader`).
- **Rewarded Interstitial Format Integration**:
  - Added full preloading and management support for **Rewarded Interstitial Ads** via `RewardInterAd` and `showRewardedInterstitialAd(...)`.
- **Collapsible & Standard Banner Modularization**:
  - Introduced `ShowCollapsibleBannerAd` for dedicated, dynamic collapsible banner ad display.
  - Added strongly-typed `CollapsibleBannerPosition` enum (`bottom` and `top`) replacing string literals.
  - Added `FittedBox(fit: BoxFit.contain)` responsive layout container to scale standard and collapsible banners seamlessly inside parent constraints.
- **Native Customizer Live Updates**:
  - Fixed native ad disappearance on dynamic color selections by updating MethodChannel state without clearing active loaded ad instances.
  - Expanded `CustomNativeADStyle` to support title, body, button, tag foreground/background colors, radius sliders, and button gradient tokens.
  - Added optional `Key? key` parameter to `showNativeAd(...)` and `showCollapsibleBannerAd(...)` for instant subtree key identity updates.
- **Streamlined Library Exports**:
  - Exported all models, enums, constants, widgets, and singletons directly via `package:preload_google_ads/preload_google_ads.dart`.
- **Comprehensive Unit Testing Suite**:
  - Modularized unit tests into dedicated files under `test/`: `ad_commons_test.dart`, `banner_ad_test.dart`, `native_ad_test.dart`, `inter_ad_test.dart`, `rewarded_ad_test.dart`, `app_open_ad_test.dart`, and `preload_google_ads_test.dart`.
- **Showcase Example App Redesign**:
  - Streamlined navigation into clean top-level tabs: **Dashboard**, **Customizer**, **Native Feed**, **Banner Ads**, and **Ad Lab**.
  - Updated branding logo and app launcher icons across Android and iOS assets.

## v1.0.6

- Added Swift Package Manager (SPM) support for iOS.
- Improved package description for better pub.dev compliance and score.

## v1.0.5

- Added iOS implementation boilerplate and native ad factory foundations.
- General codebase cleanup and removal of unused constants.

## v1.0.4

- Modernized Android build configuration (Java 11, Kotlin 2.1.0, and latest AGP).
- Redesigned `README.md` for better clarity, aesthetics, and professional presentation.
- Organized project assets by moving demo GIFs to a dedicated `docs/assets` directory.

## v1.0.3

- Updated package version to `v1.0.3`.
- Fixed minor typos and wording issues across the codebase and documentation.
- No API changes or breaking behavior.
- Internal cleanups only; existing integrations continue to work without modification.

## v1.0.0

- Promoted to stable release from pre-release versions after multiple improvements and iterations.
- Consolidated and optimized internal architecture for long-term maintainability and scalability.
- Finalized and validated all major features:
    - Real-time ad status tracking across all supported ad types.
    - Stable and consistent ad lifecycle event handling (load, show, fail, click).
    - Custom native ad layout support with enhanced UI integration.
    - Full ad preloading for Open App, Interstitial, Rewarded, Native (Small/Medium), and Banner
      formats.
- Clean Dart analysis and fully production-ready for Android.
- Updated README.md with comprehensive usage samples and support documentation.
- Addressed minor bugs and preview issues from previous versions.
- Ready for production usage as v1.0.0 milestone.
