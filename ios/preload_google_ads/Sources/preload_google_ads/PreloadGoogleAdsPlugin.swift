import Flutter
import UIKit
import google_mobile_ads

public class PreloadGoogleAdsPlugin: NSObject, FlutterPlugin {
  static var channel: FlutterMethodChannel?
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(name: "com.plug.preload/adButtonStyle", binaryMessenger: registrar.messenger())
    let instance = PreloadGoogleAdsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel!)

    // Avoid a hard crash when the app delegate is not a FlutterPluginRegistry
    // (e.g. add-to-app or custom delegates); native layouts are then unavailable.
    guard let registry = UIApplication.shared.delegate as? FlutterPluginRegistry else {
      NSLog("PreloadGoogleAds: AppDelegate is not a FlutterPluginRegistry; native ad factories not registered.")
      return
    }

    let mediumFactory = NativeAdFactoryMedium(styleMap: [:])
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(registry, factoryId: "medium_native", nativeAdFactory: mediumFactory)

    let smallFactory = NativeAdFactorySmall(styleMap: [:])
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(registry, factoryId: "small_native", nativeAdFactory: smallFactory)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setAdStyle":
      if let arguments = call.arguments as? [String: Any] {
        // Each native ad factory observes this notification and uses the new
        // style for every ad view it creates from now on.
        NotificationCenter.default.post(name: NSNotification.Name("PreloadGoogleAds_UpdateStyle"), object: nil, userInfo: arguments)
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected a style map", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
