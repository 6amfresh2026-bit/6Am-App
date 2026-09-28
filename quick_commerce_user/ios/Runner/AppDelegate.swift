import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureGoogleMaps()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// The key reaches here from `config/keys.env` → `ios/Flutter/Keys.xcconfig`
  /// → `Info.plist ($(MAPS_API_KEY))`. It is never written in source, so there
  /// is exactly one place to rotate it.
  private func configureGoogleMaps() {
    guard
      let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
      !key.isEmpty,
      key != "YOUR_GOOGLE_MAPS_API_KEY_HERE"
    else {
      // A missing key renders a blank grey map with no other clue, so say so.
      NSLog(
        "[Suvio] MAPS_API_KEY missing. Set it in config/keys.env and run "
          + "tool/generate_ios_keys.sh — maps will not render until then."
      )
      return
    }
    GMSServices.provideAPIKey(key)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
