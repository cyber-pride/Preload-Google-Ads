import '../ad_internal.dart';

/// A widget that determines which type of native ad (small or medium) to show
/// based on the `nativeADType` and the counter logic.
///
/// The counter decision is made once per placement (when the widget is first
/// inserted), so ordinary rebuilds (theme changes, parent setState, scrolling)
/// never make an ad disappear or count as an extra placement.
class ShowNative extends StatefulWidget {
  /// The type of native ad to display.
  final NativeADType nativeADType;

  /// Constructor for [ShowNative].
  const ShowNative({super.key, required this.nativeADType});

  @override
  State<ShowNative> createState() => _ShowNativeState();
}

class _ShowNativeState extends State<ShowNative> {
  late final bool _showAd;

  @override
  void initState() {
    super.initState();
    final isSmall = widget.nativeADType == NativeADType.small;
    final loader = isSmall ? LoadSmallNative.instance : LoadMediumNative.instance;

    if (loader.counter >= getNativeCounter) {
      loader.resetCounter();
      _showAd = shouldShowNativeAd;
    } else {
      loader.incrementCounter();
      _showAd = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showAd) return const SizedBox.shrink();
    return widget.nativeADType == NativeADType.small
        ? const NativeSmall()
        : const MediumNative();
  }
}

/// A internal helper widget to manage common state for native ad views.
abstract class _NativeAdViewState<T extends StatefulWidget> extends State<T> {
  final BaseNativeAdLoader loader;
  final BoxConstraints constraints;
  NativeAd? _ad;

  _NativeAdViewState({required this.loader, required this.constraints});

  @override
  void initState() {
    super.initState();
    _ad = loader.takeAd();
    if (_ad == null) {
      // No preloaded ad yet: wait for the in-flight load and show it as soon as it arrives.
      loader.adAvailable.addListener(_onAdAvailable);
    }
  }

  void _onAdAvailable() {
    if (!mounted || _ad != null) return;
    final ad = loader.takeAd();
    if (ad == null) return;
    loader.adAvailable.removeListener(_onAdAvailable);
    setState(() => _ad = ad);
  }

  @override
  void dispose() {
    loader.adAvailable.removeListener(_onAdAvailable);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ad == null) return const SizedBox.shrink();

    final isDark = NativeADStyle.instance.isDarkMode(context: context);
    final decoration = (isDark && NativeADStyle.instance.darkDecoration != null)
        ? NativeADStyle.instance.darkDecoration
        : NativeADStyle.instance.lightDecoration;

    try {
      return Container(
        decoration: decoration,
        constraints: constraints,
        margin: NativeADStyle.instance.margin,
        padding: NativeADStyle.instance.padding,
        child: Center(child: AdWidget(ad: _ad!)),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}

/// A widget that displays a medium-sized native ad.
class MediumNative extends StatefulWidget {
  /// Constructor for [MediumNative].
  const MediumNative({super.key});

  @override
  State<MediumNative> createState() => _MediumNativeState();
}

class _MediumNativeState extends _NativeAdViewState<MediumNative> {
  _MediumNativeState()
      : super(
          loader: LoadMediumNative.instance,
          constraints: NativeADStyle.instance.mediumConstraintsSize,
        );
}

/// A widget that displays a small-sized native ad.
class NativeSmall extends StatefulWidget {
  /// Constructor for [NativeSmall].
  const NativeSmall({super.key});

  @override
  State<NativeSmall> createState() => _NativeSmallState();
}

class _NativeSmallState extends _NativeAdViewState<NativeSmall> {
  _NativeSmallState()
      : super(
          loader: LoadSmallNative.instance,
          constraints: NativeADStyle.instance.smallConstraintsSize,
        );
}
