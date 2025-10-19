import Flutter
import GoogleMaps
import FirebaseCore
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool { if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String {
    GMSServices.provideAPIKey(key)
    FirebaseApp.configure()
    // Ensure the app registers for APNs. FlutterFire will swizzle and forward the device token to FCM.
    UIApplication.shared.registerForRemoteNotifications()
  }
      
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
