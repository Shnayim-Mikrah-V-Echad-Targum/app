import AVFoundation
import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets reading reminders appear while the app is open, and taps reach Flutter.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Plugins used from notification callbacks need registering too.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerAudioSessionChannel(engineBridge.pluginRegistry)
  }

  // Ends the audio session that Listen sets, when speech stops part-way
  // (lib/services/tts.dart). flutter_tts ends it only when speech finishes,
  // so music it ducked would stay quiet, and a podcast it interrupted would
  // never resume.
  private func registerAudioSessionChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "ShnayimMikraAudioSession") else { return }
    let channel = FlutterMethodChannel(name: "shnayim_mikra/audio_session", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "deactivate" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        result(true)
      } catch {
        result(false)
      }
    }
  }
}
