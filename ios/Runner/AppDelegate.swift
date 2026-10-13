import AVFoundation
import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Tells Dart of interruptions to Listen's audio session.
  private var audioInterruptionObserver: NSObjectProtocol?

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
  //
  // And tells Dart when a call, an alarm or another app's audio interrupts
  // the session, so that Listen pauses at its verse rather than wait,
  // silent, for an engine the system has paused.
  private func registerAudioSessionChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "ShnayimMikrahAudioSession") else { return }
    let channel = FlutterMethodChannel(name: "shnayim_mikrah/audio_session", binaryMessenger: registrar.messenger())
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
    if let observer = audioInterruptionObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    audioInterruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { notification in
      guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
        AVAudioSession.InterruptionType(rawValue: type) == .began
      else { return }
      channel.invokeMethod("focusLost", arguments: nil)
    }
  }
}
