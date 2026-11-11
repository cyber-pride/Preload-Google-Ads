import '../ad_internal.dart';

/// Enum representing the ad theme mode.
enum AdThemeMode {
  /// Automatically matches system / Flutter ThemeData brightness.
  system,

  /// Forces Light Mode ad styles.
  light,

  /// Forces Dark Mode ad styles.
  dark,
}

/// How an ad format is preloaded.
enum PreloadMode {
  /// The package loads the ad by itself: at startup, after each show, when a
  /// show call finds nothing ready, and after [AdManager.reloadUnloadedAds].
  /// This is the default and matches the behavior of earlier versions.
  auto,

  /// The package never requests the ad on its own. Call the matching
  /// `PreloadGoogleAds.instance.preload…()` function when the user is about to
  /// reach the screen that shows it, so ads are only requested when they are
  /// likely to be seen (better show rate).
  ///
  /// Native and banner widgets still load their own ad when they appear with
  /// nothing preloaded, because that ad is about to be seen.
  manual,
}

/// Chooses [PreloadMode.auto] or [PreloadMode.manual] per ad format.
///
/// Formats left null keep their current mode (on the first `initialize()`
/// call: [PreloadMode.auto]).
///
/// ```dart
/// AdConfigData(
///   preloadConfig: AdPreloadConfig(
///     rewarded: PreloadMode.manual,
///     rewardedInterstitial: PreloadMode.manual,
///   ),
/// )
/// ```
class AdPreloadConfig {
  /// Preload mode for interstitial ads.
  final PreloadMode? interstitial;

  /// Preload mode for rewarded ads.
  final PreloadMode? rewarded;

  /// Preload mode for rewarded interstitial ads.
  final PreloadMode? rewardedInterstitial;

  /// Preload mode for native ads (small and medium).
  final PreloadMode? native;

  /// Preload mode for standard banner ads.
  final PreloadMode? banner;

  /// Preload mode for app open ads.
  final PreloadMode? appOpen;

  /// Sets the mode per format; null keeps the current mode.
  const AdPreloadConfig({
    this.interstitial,
    this.rewarded,
    this.rewardedInterstitial,
    this.native,
    this.banner,
    this.appOpen,
  });

  /// Uses the same [mode] for every format.
  const AdPreloadConfig.all(PreloadMode mode)
      : interstitial = mode,
        rewarded = mode,
        rewardedInterstitial = mode,
        native = mode,
        banner = mode,
        appOpen = mode;

  /// Returns this config with null formats taken from [base].
  AdPreloadConfig mergeOnto(AdPreloadConfig? base) => AdPreloadConfig(
        interstitial: interstitial ?? base?.interstitial,
        rewarded: rewarded ?? base?.rewarded,
        rewardedInterstitial: rewardedInterstitial ?? base?.rewardedInterstitial,
        native: native ?? base?.native,
        banner: banner ?? base?.banner,
        appOpen: appOpen ?? base?.appOpen,
      );
}

/// Configuration data for all ad-related settings.
class AdConfigData {
  /// IDs for various ad formats.
  final AdIDS? adIDs;

  /// Controls ad display counters.
  final AdCounter? adCounter;

  /// Toggles for showing/hiding different types of ads.
  final AdFlag? adFlag;

  /// Automatic or manual preloading per ad format. Null means every format
  /// is preloaded automatically.
  final AdPreloadConfig? preloadConfig;

  /// Styling preferences for native ads (Light and Dark mode support).
  final NativeADLayout? nativeADLayout;

  /// Styling preferences for banner ads (Light and Dark mode support).
  final BannerADLayout? bannerADLayout;

  /// Theme mode for ad styling (system, light, or dark).
  final AdThemeMode themeMode;

  /// Whether [themeMode] was passed explicitly (rather than defaulted).
  ///
  /// When `initialize()` is called again, an omitted theme mode keeps the
  /// current one instead of resetting it to [AdThemeMode.system].
  final bool themeModeProvided;

  /// When true, `initialize()` runs Google's User Messaging Platform (UMP)
  /// consent flow before the Mobile Ads SDK starts, and no ad is requested
  /// until `ConsentInformation.canRequestAds()` is true.
  ///
  /// Required by Google for apps with users in the EEA, UK and Switzerland.
  /// Create a GDPR message in AdMob → Privacy & messaging first.
  ///
  /// Once enabled it stays enabled for the rest of the app session: calling
  /// `initialize()` again without it does not switch consent off.
  final bool requireConsent;

  /// Optional UMP request parameters (e.g. debug geography for testing,
  /// tag for under age of consent). Used only when [requireConsent] is true.
  final ConsentRequestParameters? consentRequestParameters;

  /// Constructor for [AdConfigData].
  AdConfigData({
    this.adIDs,
    this.adCounter,
    this.adFlag,
    this.nativeADLayout,
    this.bannerADLayout,
    AdThemeMode? themeMode,
    this.requireConsent = false,
    this.consentRequestParameters,
    this.preloadConfig,
  })  : themeMode = themeMode ?? AdThemeMode.system,
        themeModeProvided = themeMode != null;

  /// Returns a copy with the given fields replaced.
  AdConfigData copyWith({
    AdThemeMode? themeMode,
    AdFlag? adFlag,
    AdPreloadConfig? preloadConfig,
  }) {
    return AdConfigData(
      adIDs: adIDs,
      adCounter: adCounter,
      adFlag: adFlag ?? this.adFlag,
      nativeADLayout: nativeADLayout,
      bannerADLayout: bannerADLayout,
      themeMode: themeMode ?? this.themeMode,
      requireConsent: requireConsent,
      consentRequestParameters: consentRequestParameters,
      preloadConfig: preloadConfig ?? this.preloadConfig,
    );
  }
}

/// Configuration for the layout of banner ads.
class BannerADLayout {
  /// The decoration of the container surrounding the banner ad in Light Mode.
  BoxDecoration? lightDecoration;

  /// Legacy alias getter for [lightDecoration] for backward compatibility.
  BoxDecoration? get decoration => lightDecoration;

  /// Legacy alias setter for [lightDecoration] for backward compatibility.
  set decoration(BoxDecoration? value) => lightDecoration = value;

  /// The decoration of the container surrounding the banner ad in Dark Mode.
  BoxDecoration? darkDecoration;

  /// The padding of the container surrounding the banner ad.
  EdgeInsets? padding;

  /// The margin of the container surrounding the banner ad.
  EdgeInsets? margin;

  /// The size of the banner ad. If null, dynamic adaptive size is calculated automatically.
  AdSize? adSize;

  /// Constructor for [BannerADLayout] with Light Mode and Dark Mode decoration options.
  BannerADLayout({
    BoxDecoration? lightDecoration,
    BoxDecoration? decoration,
    this.darkDecoration,
    this.padding,
    this.margin,
    this.adSize,
  }) : lightDecoration = lightDecoration ?? decoration;
}

/// Contains Ad Unit IDs for different ad types.
class AdIDS {
  /// App open ad ID.
  final String? appOpenId;

  /// Banner ad ID.
  final String? bannerId;

  /// Native ad ID.
  final String? nativeId;

  /// Interstitial ad ID.
  final String? interstitialId;

  /// Rewarded ad ID.
  final String? rewardedId;

  /// Rewarded Interstitial ad ID.
  final String? rewardedInterstitialId;

  /// Constructor for [AdIDS].
  AdIDS({
    this.appOpenId,
    this.bannerId,
    this.nativeId,
    this.interstitialId,
    this.rewardedId,
    this.rewardedInterstitialId,
  });
}

/// Controls the display frequency of ads using counters.
class AdCounter {
  /// Number of times to show interstitial ads.
  final int? interstitialCounter;

  /// Number of times to show rewarded ads.
  final int? rewardedCounter;

  /// Number of times to show rewarded interstitial ads.
  final int? rewardedInterstitialCounter;

  /// Number of times to show native ads.
  final int? nativeCounter;

  /// Constructor for [AdCounter].
  AdCounter({
    this.interstitialCounter,
    this.rewardedCounter,
    this.rewardedInterstitialCounter,
    this.nativeCounter,
  });
}

/// Flags to enable/disable various ad types.
class AdFlag {
  /// Master flag to show/hide all ads.
  final bool? showAd;

  /// Show banner ads.
  final bool? showBanner;

  /// Show interstitial ads.
  final bool? showInterstitial;

  /// Show native ads.
  final bool? showNative;

  /// Show open app ad.
  final bool? showAppOpen;

  /// Show rewarded ad.
  final bool? showRewarded;

  /// Show rewarded interstitial ad.
  final bool? showRewardedInterstitial;

  /// Constructor for [AdFlag].
  AdFlag({
    this.showAd,
    this.showBanner,
    this.showInterstitial,
    this.showNative,
    this.showAppOpen,
    this.showRewarded,
    this.showRewardedInterstitial,
  });
}

/// Configuration for the layout of native ads.
class NativeADLayout {
  /// The type of layout to use (Flutter or native).
  final AdLayout adLayout;

  /// Custom styling settings for native platform layouts in Light Mode.
  final CustomNativeADStyle? customNativeADStyle;

  /// Alias for [customNativeADStyle].
  CustomNativeADStyle? get lightCustomNativeADStyle => customNativeADStyle;

  /// Custom styling settings for native platform layouts in Dark Mode.
  final CustomNativeADStyle? darkCustomNativeADStyle;

  /// Styling settings for Flutter-based native ad templates in Light Mode.
  final FlutterNativeADStyle? flutterNativeADStyle;

  /// Styling settings for Flutter-based native ad templates in Dark Mode.
  final FlutterNativeADStyle? darkFlutterNativeADStyle;

  /// The decoration of the container surrounding the native ad in Light Mode.
  BoxDecoration lightDecoration;

  /// Legacy alias getter for [lightDecoration] for backward compatibility.
  BoxDecoration get decoration => lightDecoration;

  /// Legacy alias setter for [lightDecoration] for backward compatibility.
  set decoration(BoxDecoration value) => lightDecoration = value;

  /// The decoration of the container surrounding the native ad in Dark Mode.
  BoxDecoration? darkDecoration;

  /// The padding of the container surrounding the native ad.
  EdgeInsets padding;

  /// The margin of the container surrounding the native ad.
  EdgeInsets margin;

  /// Constructor for [NativeADLayout] with Light Mode and Dark Mode decoration options.
  NativeADLayout({
    AdLayout? adLayout,
    CustomNativeADStyle? customNativeADStyle,
    CustomNativeADStyle? lightCustomNativeADStyle,
    this.darkCustomNativeADStyle,
    this.flutterNativeADStyle,
    this.darkFlutterNativeADStyle,
    EdgeInsets? padding,
    EdgeInsets? margin,
    BoxDecoration? lightDecoration,
    BoxDecoration? decoration,
    this.darkDecoration,
  })  : customNativeADStyle = customNativeADStyle ?? lightCustomNativeADStyle,
        adLayout = adLayout ?? AdLayout.nativeLayout,
        lightDecoration = lightDecoration ??
            decoration ??
            BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(5),
            ),
        padding = padding ?? const EdgeInsets.all(5),
        margin = margin ?? const EdgeInsets.all(5);
}

/// Styling configuration for ad components.
class CustomNativeADStyle {
  /// Color of the ad title text.
  Color titleColor;

  /// Color of the ad body text.
  Color bodyColor;

  /// Background color of ad tags.
  Color tagBackground;

  /// Foreground color (text/icon) of ad tags.
  Color tagForeground;

  /// Background color of ad buttons.
  Color buttonBackground;

  /// Foreground color (text/icon) of ad buttons.
  Color buttonForeground;

  /// Border radius for ad buttons.
  int buttonRadius;

  /// Border radius for ad tags.
  int tagRadius;

  /// Optional gradient colors for ad buttons.
  List<Color> buttonGradients;

  /// The constraints for medium-sized native ads.
  BoxConstraints mediumBoxConstrain;

  /// The constraints for small-sized native ads.
  BoxConstraints smallBoxConstrain;

  /// Default Light Mode Constructor.
  CustomNativeADStyle({
    this.titleColor = const Color(0xFF000000),
    this.bodyColor = const Color(0xFF808080),
    this.tagBackground = const Color(0xFFF19938),
    this.tagForeground = const Color(0xFFFFFFFF),
    this.buttonBackground = const Color(0xFF2196F3),
    this.buttonForeground = const Color(0xFFFFFFFF),
    this.buttonRadius = 5,
    this.tagRadius = 5,
    List<Color>? buttonGradients,
    BoxConstraints? mediumBoxConstrain,
    BoxConstraints? smallBoxConstrain,
  })  : buttonGradients = buttonGradients ?? [],
        mediumBoxConstrain = mediumBoxConstrain ?? BoxConstraints(
          minWidth: 320,
          minHeight: 210,
          maxWidth: 400,
          maxHeight: 265,
        ),
        smallBoxConstrain = smallBoxConstrain ?? BoxConstraints(
          minWidth: 320,
          minHeight: 57,
          maxWidth: 400,
          maxHeight: 135,
        );

  /// Factory constructor for Dark Mode presets.
  factory CustomNativeADStyle.dark({
    Color titleColor = const Color(0xFFF8FAFC),
    Color bodyColor = const Color(0xFF94A3B8),
    Color tagBackground = const Color(0xFFF19938),
    Color tagForeground = const Color(0xFFFFFFFF),
    Color buttonBackground = const Color(0xFF6366F1),
    Color buttonForeground = const Color(0xFFFFFFFF),
    int buttonRadius = 5,
    int tagRadius = 5,
    List<Color>? buttonGradients,
    BoxConstraints? mediumBoxConstrain,
    BoxConstraints? smallBoxConstrain,
  }) {
    return CustomNativeADStyle(
      titleColor: titleColor,
      bodyColor: bodyColor,
      tagBackground: tagBackground,
      tagForeground: tagForeground,
      buttonBackground: buttonBackground,
      buttonForeground: buttonForeground,
      buttonRadius: buttonRadius,
      tagRadius: tagRadius,
      buttonGradients: buttonGradients,
      mediumBoxConstrain: mediumBoxConstrain,
      smallBoxConstrain: smallBoxConstrain,
    );
  }
}

/// Styling configuration for Flutter native ad templates.
class FlutterNativeADStyle {
  /// Text style for the call-to-action button (e.g., "Install", "Learn More").
  NativeTemplateTextStyle? callToActionTextStyle;

  /// Text style for the primary title or headline of the ad.
  NativeTemplateTextStyle? primaryTextStyle;

  /// Text style for the secondary text (typically body or rating info).
  NativeTemplateTextStyle? secondaryTextStyle;

  /// Text style for tertiary text (e.g., store name or additional info).
  NativeTemplateTextStyle? tertiaryTextStyle;

  /// Background color for the entire ad template.
  Color? mainBackgroundColor;

  /// Corner radius for call-to-action and icon elements (iOS only).
  double? cornerRadius;

  /// The constraints for medium-sized native ads in the Flutter template.
  BoxConstraints mediumBoxConstrain;

  /// The constraints for small-sized native ads in the Flutter template.
  BoxConstraints smallBoxConstrain;

  /// Default Light Mode Constructor.
  FlutterNativeADStyle({
    NativeTemplateTextStyle? callToActionTextStyle,
    NativeTemplateTextStyle? primaryTextStyle,
    NativeTemplateTextStyle? secondaryTextStyle,
    NativeTemplateTextStyle? tertiaryTextStyle,
    Color? mainBackgroundColor,
    double? cornerRadius,
    BoxConstraints? mediumBoxConstrain,
    BoxConstraints? smallBoxConstrain,
  })  : callToActionTextStyle = callToActionTextStyle ??
            NativeTemplateTextStyle(
              textColor: Colors.white,
              backgroundColor: Colors.blue,
              style: NativeTemplateFontStyle.bold,
              size: 14.0,
            ),
        primaryTextStyle = primaryTextStyle ??
            NativeTemplateTextStyle(
              textColor: Colors.black,
              style: NativeTemplateFontStyle.normal,
              size: 16.0,
            ),
        secondaryTextStyle = secondaryTextStyle ??
            NativeTemplateTextStyle(
              textColor: Colors.grey,
              style: NativeTemplateFontStyle.normal,
              size: 14.0,
            ),
        tertiaryTextStyle = tertiaryTextStyle ??
            NativeTemplateTextStyle(
              textColor: Colors.grey,
              style: NativeTemplateFontStyle.normal,
              size: 12.0,
            ),
        mainBackgroundColor = mainBackgroundColor ?? Colors.white,
        cornerRadius = cornerRadius ?? 5.0,
        mediumBoxConstrain = mediumBoxConstrain ?? BoxConstraints(
          minWidth: 320,
          minHeight: 280,
          maxWidth: 400,
          maxHeight: 365,
        ),
        smallBoxConstrain = smallBoxConstrain ?? BoxConstraints(
          minWidth: 320,
          minHeight: 88,
          maxWidth: 400,
          maxHeight: 120,
        );

  /// Factory constructor for Dark Mode presets.
  factory FlutterNativeADStyle.dark({
    NativeTemplateTextStyle? callToActionTextStyle,
    NativeTemplateTextStyle? primaryTextStyle,
    NativeTemplateTextStyle? secondaryTextStyle,
    NativeTemplateTextStyle? tertiaryTextStyle,
    Color mainBackgroundColor = const Color(0xFF1E293B),
    double cornerRadius = 5.0,
    BoxConstraints? mediumBoxConstrain,
    BoxConstraints? smallBoxConstrain,
  }) {
    return FlutterNativeADStyle(
      callToActionTextStyle: callToActionTextStyle ??
          NativeTemplateTextStyle(
            textColor: Colors.white,
            backgroundColor: const Color(0xFF6366F1),
            style: NativeTemplateFontStyle.bold,
            size: 14.0,
          ),
      primaryTextStyle: primaryTextStyle ??
          NativeTemplateTextStyle(
            textColor: const Color(0xFFF8FAFC),
            style: NativeTemplateFontStyle.normal,
            size: 16.0,
          ),
      secondaryTextStyle: secondaryTextStyle ??
          NativeTemplateTextStyle(
            textColor: const Color(0xFF94A3B8),
            style: NativeTemplateFontStyle.normal,
            size: 14.0,
          ),
      tertiaryTextStyle: tertiaryTextStyle ??
          NativeTemplateTextStyle(
            textColor: const Color(0xFF64748B),
            style: NativeTemplateFontStyle.normal,
            size: 12.0,
          ),
      mainBackgroundColor: mainBackgroundColor,
      cornerRadius: cornerRadius,
      mediumBoxConstrain: mediumBoxConstrain,
      smallBoxConstrain: smallBoxConstrain,
    );
  }
}
