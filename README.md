<p align="center">
  <img src="https://raw.githubusercontent.com/bhx20/Preload-Google-Ads/main/doc/assets/Preload%20Google%20Ad%20Logo.png" alt="Preload Google Ads Logo" width="300" />
</p>

<p align="center">
  <a href="https://pub.dev/packages/preload_google_ads"><img src="https://img.shields.io/pub/v/preload_google_ads.svg" alt="Pub Version"></a>
  <a href="https://pub.dev/packages/preload_google_ads/score"><img src="https://img.shields.io/pub/points/preload_google_ads" alt="Pub Points"></a>
  <a href="https://pub.dev/packages/preload_google_ads"><img src="https://img.shields.io/pub/likes/preload_google_ads" alt="Pub Likes"></a>
  <a href="https://pub.dev/packages/preload_google_ads"><img src="https://img.shields.io/pub/popularity/preload_google_ads" alt="Popularity"></a>
  <a href="https://github.com/bhx20/Preload-Google-Ads/blob/main/LICENSE"><img src="https://img.shields.io/github/license/bhx20/Preload-Google-Ads" alt="License"></a>
</p>

---

## 🚀 Overview

**Preload Google Ads** is a high-performance Flutter plugin designed to eliminate ad latency and provide a seamless, non-intrusive user experience. It background-preloads **App Open**, **Interstitial**, **Rewarded**, **Rewarded Interstitial**, **Native (Small & Medium)**, and **Banner (Anchored Adaptive & Collapsible)** ads before they need to be displayed.

---

## ⚡ Key Features

- 🏎️ **Zero-Latency Ad Delivery**: Background preloading queues ads before user navigation.
- 📱 **All Major Formats**: App Open, Interstitial, Rewarded, Rewarded Interstitial, Native, and Banner ads.
- 🎨 **Adaptive & Collapsible Banners**: Built-in anchored adaptive and collapsible banner support.
- 🌙 **Light & Dark Mode**: Dynamic native ad style sync with system/app theme.
- 📊 **Match-Rate Optimization (>95%)**: Intelligent click counter gating and 4-hour TTL caching.
- 🛠️ **Diagnostic Ad Counter**: Live visual stats widget tracking loads and impressions.

---

## Preview

Below are some previews showing ad preloading in action. Notice the instant display!

<div style="display: flex; gap: 12px; justify-content: center; flex-wrap: wrap;">
  <img src="https://raw.githubusercontent.com/bhx20/Preload-Google-Ads/main/doc/assets/1.gif" alt="Demo 1" width="22%" />
  <img src="https://raw.githubusercontent.com/bhx20/Preload-Google-Ads/main/doc/assets/2.gif" alt="Demo 2" width="22%" />
  <img src="https://raw.githubusercontent.com/bhx20/Preload-Google-Ads/main/doc/assets/3.gif" alt="Demo 3" width="22%" />
  <img src="https://raw.githubusercontent.com/bhx20/Preload-Google-Ads/main/doc/assets/4.gif" alt="Demo 4" width="22%" />
</div>

---

## Getting Started

### 1. Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  preload_google_ads: ^1.0.8
```

Or run:
```bash
flutter pub add preload_google_ads
```

### 2. Platform Setup

**Important**: Configure your AdMob App ID in both Android and iOS projects to avoid crashes.

#### Android
Update `android/app/src/main/AndroidManifest.xml`:
```xml
<manifest>
    <application>
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>
    </application>
</manifest>
```

#### iOS
Update `ios/Runner/Info.plist`:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
```

---

## Basic Usage

Initialize the plugin in your `main()` function. This kicks off the background preloading immediately.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize and start preloading
  await PreloadGoogleAds.instance.initialize(
    adConfigData: AdConfigData(
      adIDs: AdIDS(
        appOpenId: AdTestIds.appOpen,
        bannerId: AdTestIds.banner,
        nativeId: AdTestIds.native,
        interstitialId: AdTestIds.interstitial,
        rewardedId: AdTestIds.rewarded,
        rewardedInterstitialId: AdTestIds.rewardedInterstitial,
      ),
    ),
  );

  runApp(const MyApp());
}
```

`initialize()` starts the SDK and preloads **one ad per enabled format**, so the first show is instant. Nothing is shown at launch. Turn off formats you don't use in `AdFlag`, so the package never requests ads that won't be shown (this keeps your show rate high).

---

## User Consent (GDPR / UMP)

If you have users in the EEA, UK or Switzerland, Google requires consent through its User Messaging Platform before ads are requested. Create a GDPR message in **AdMob → Privacy & messaging**, then set `requireConsent: true`:

```dart
await PreloadGoogleAds.instance.initialize(
  adConfigData: AdConfigData(
    requireConsent: true,
    adIDs: AdIDS(/* your IDs */),
  ),
);
```

`initialize()` then shows Google's consent form when needed, and only starts the SDK and requests ads once `canRequestAds` is true. Google also requires a way for users to change their choice:

```dart
if (await PreloadGoogleAds.instance.isPrivacyOptionsRequired()) {
  // Show a "Privacy settings" button in your settings screen:
  await PreloadGoogleAds.instance.showPrivacyOptionsForm();
}
```

To test outside the EEA, pass `consentRequestParameters` with `ConsentDebugSettings(debugGeography: DebugGeography.debugGeographyEea, testIdentifiers: [...])`.

---

## Advanced Configuration

### Click Counters & AD Flags
Control specifically which ads to show and how frequently they appear.

```dart
PreloadGoogleAds.instance.initialize(
  adConfigData: AdConfigData(
    adCounter: AdCounter(
      interstitialCounter: 3,        // Show every 3rd trigger (default: 3)
      nativeCounter: 0,              // Show every time
      rewardedCounter: 1,            // Show every click
      rewardedInterstitialCounter: 1, // Show every click
    ),
    adFlag: AdFlag(
      showAd: true,
      showBanner: true,
      showInterstitial: true,
      showNative: true,
      showOpenApp: true,
      showRewarded: true,
      showRewardedInterstitial: true,
    ),
  ),
);
```

### Automatic vs. Manual Preloading
By default every format is preloaded **automatically**: one ad is loaded at startup and the next one after each show. If some formats only appear on screens many users never open, those preloaded ads go unseen and lower your **show rate**. Set those formats to `PreloadMode.manual` and preload them yourself when the user is about to reach the screen:

```dart
await PreloadGoogleAds.instance.initialize(
  adConfigData: AdConfigData(
    preloadConfig: AdPreloadConfig(
      rewarded: PreloadMode.manual,
      rewardedInterstitial: PreloadMode.manual,
      // interstitial, native, banner, appOpen stay automatic (default)
    ),
  ),
);

// e.g. when the user opens the level screen that has a "Watch ad" button:
final ready = await PreloadGoogleAds.instance.preloadRewardedAd();
```

In manual mode the package never requests that format on its own: not at startup, not after a show, not from `reloadUnloadedAds()`, and not when a show call finds no ad ready (it just returns `false` and runs your `callBack`). Native and banner widgets still load their own ad if they appear with nothing preloaded, because that ad is about to be seen.

| Function | Format |
|----------|--------|
| `preloadInterstitialAd()` | Interstitial |
| `preloadRewardedAd()` | Rewarded |
| `preloadRewardedInterstitialAd()` | Rewarded Interstitial |
| `preloadAppOpenAd()` | App Open (shown on the next return to the app) |
| `preloadBannerAd()` | Standard banner |
| `preloadNativeAd(nativeADType: ...)` | Native (small / medium) |

Each returns a `Future<bool>`: `true` once an ad is ready, `false` if the format is disabled, `initialize()` hasn't finished, consent is missing, or the request failed. They work in automatic mode too and do nothing if an ad is already loaded or loading. Use `AdPreloadConfig.all(PreloadMode.manual)` to make every format manual.

### Native Ad Custom Styling
Customize the appearance of native ads with light and dark mode tokens.

```dart
NativeADLayout(
  padding: const EdgeInsets.all(8),
  lightDecoration: BoxDecoration(
    color: Colors.white,
    border: Border.all(color: Colors.grey.shade300),
    borderRadius: BorderRadius.circular(12),
  ),
  darkDecoration: BoxDecoration(
    color: const Color(0xFF1E293B),
    border: Border.all(color: const Color(0xFF334155)),
    borderRadius: BorderRadius.circular(12),
  ),
  lightCustomNativeADStyle: CustomNativeADStyle(
    titleColor: Colors.black,
    bodyColor: Colors.grey.shade700,
    buttonBackground: Colors.blueAccent,
    buttonForeground: Colors.white,
    buttonRadius: 10,
    tagBackground: Colors.amber,
    tagForeground: Colors.black,
  ),
  darkCustomNativeADStyle: CustomNativeADStyle.dark(
    titleColor: Colors.white,
    bodyColor: Colors.grey.shade300,
    buttonBackground: Colors.indigoAccent,
    buttonForeground: Colors.white,
    buttonRadius: 10,
  ),
)
```

---

## Showing Ads

### Code Examples for All Ad Formats

#### 1. Native Ad (Medium / Small)
```dart
// Native Medium Ad
PreloadGoogleAds.instance.showNativeAd(
  key: const ValueKey('home_native_ad'),
  nativeADType: NativeADType.medium,
);

// Native Small Ad
PreloadGoogleAds.instance.showNativeAd(
  key: const ValueKey('feed_native_ad'),
  nativeADType: NativeADType.small,
);
```

#### 2. Standard Anchored Banner Ad
```dart
PreloadGoogleAds.instance.showBannerAd();
```

#### 3. Collapsible Banner Ad (Bottom / Top)
```dart
// Bottom Collapsible Banner
PreloadGoogleAds.instance.showCollapsibleBannerAd(
  collapsiblePosition: CollapsibleBannerPosition.bottom,
);

// Top Collapsible Banner
PreloadGoogleAds.instance.showCollapsibleBannerAd(
  collapsiblePosition: CollapsibleBannerPosition.top,
);
```

#### 4. Interstitial Ad
```dart
PreloadGoogleAds.instance.showInterstitialAd(
  callBack: (ad, error) {
    if (error != null) {
      print("Interstitial failed to show: ${error.message}");
    }
    // Perform navigation or action after ad is closed
  },
);
```

#### 5. Rewarded Ad
```dart
PreloadGoogleAds.instance.showRewardedAd(
  callBack: (ad, error) {
    if (error != null) {
      print("Rewarded ad failed to show: ${error.message}");
    }
  },
  onReward: (ad, rewardItem) {
    print("User earned reward: ${rewardItem.amount} ${rewardItem.type}");
  },
);
```

#### 6. Rewarded Interstitial Ad
```dart
PreloadGoogleAds.instance.showRewardedInterstitialAd(
  callBack: (ad, error) {
    if (error != null) {
      print("Rewarded Interstitial failed to show: ${error.message}");
    }
  },
  onReward: (ad, rewardItem) {
    print("User earned rewarded interstitial reward!");
  },
);
```

#### 7. App Open Ad
```dart
PreloadGoogleAds.instance.showOpenApp();
```

---

### Quick Reference Table

| Format | Method | Description |
| :--- | :--- | :--- |
| **Native** | `PreloadGoogleAds.instance.showNativeAd(key: ..., nativeADType: NativeADType.medium)` | Displays native ad with key identity & medium/small layout |
| **Standard Banner** | `PreloadGoogleAds.instance.showBannerAd()` | Displays standard 320x50 adaptive banner scaled with `FittedBox` |
| **Collapsible Banner** | `PreloadGoogleAds.instance.showCollapsibleBannerAd(collapsiblePosition: CollapsibleBannerPosition.bottom)` | Displays dynamic collapsible banner anchored to `bottom` or `top` |
| **Interstitial** | `PreloadGoogleAds.instance.showInterstitialAd(callBack: (ad, error) => ...)` | Shows full-screen interstitial ad |
| **Rewarded** | `PreloadGoogleAds.instance.showRewardedAd(callBack: ..., onReward: (ad, reward) => ...)` | Shows rewarded ad and grants reward item |
| **Rewarded Interstitial** | `PreloadGoogleAds.instance.showRewardedInterstitialAd(callBack: ..., onReward: (ad, reward) => ...)` | Shows rewarded interstitial ad and grants reward item |
| **App Open** | `PreloadGoogleAds.instance.showOpenApp()` | Shows app open ad |

> [!TIP]
> **Pro Tip**: To show an ad during navigation, place your navigation logic inside the `callBack`. This ensures the transition happens exactly when the ad is closed or fails to load.

### Rewarded Ads: Best Practice
Only offer a "Watch ad" button when an ad is ready, and grant the reward only in `onReward` (`callBack` also fires when no ad was shown):

```dart
if (PreloadGoogleAds.instance.isRewardedAdReady) {
  PreloadGoogleAds.instance.showRewardedAd(
    callBack: (ad, error) {},
    onReward: (ad, reward) => grantCoins(reward.amount),
  );
}
```

### App Open Ads
App Open ads are shown automatically when the user returns to the app. They are skipped while another full-screen ad is open, for a few seconds after one closes, and when the user comes back from clicking an ad.

### Diagnostic Counter
Enable the built-in counter to track ad status in real-time during development.

```dart
PreloadGoogleAds.instance.showAdCounter(showCounter: true);
```

> [!IMPORTANT]
> **Ad IDs**: Use Google's test IDs while developing, and never click your own live ads. In **release** builds, any enabled format without an ad unit ID is turned off (it never falls back to test ads), and a warning is printed if you pass a test ID.

---

## Support & Contributions

We welcome contributions!
- **Bugs**: Open an issue on GitHub.
- **Feature Request**: Open a discussion.
- **Starred**: If this package helps you, give it a ⭐ on [pub.dev](https://pub.dev/packages/preload_google_ads).

---

## License & Contact

- **License**: [MIT License](https://github.com/coddyNet/Preload-Google-Ads/blob/main/LICENSE)
- **Author**: CoddyNet Infotech
- **Email**: coddynet@gmail.com
- **GitHub**: [https://github.com/coddyNet](https://github.com/coddyNet)

---

<p align="center">
  <b>Built with passion for Flutter Developers seeking top-tier performance.</b>
</p>
