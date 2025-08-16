import UIKit
import Flutter
import GoogleMaps // <--- MAKE SURE THIS LINE IS HERE

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // MAKE SURE THIS LINE IS HERE AND HAS YOUR REAL KEY
    GMSServices.provideAPIKey("AIzaSyA48RTqeXV5d_GOUbgQGjGhFuCxn1hgnmI") 

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}