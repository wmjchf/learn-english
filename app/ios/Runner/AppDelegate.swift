import AudioToolbox
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    // AudioToolbox Taptic：不依赖「系统触感反馈」开关（对齐 collection-app）
    // 1519 peek / 1520 pop / 1521 三重
    let haptics = FlutterMethodChannel(
      name: "wordx/haptics",
      binaryMessenger: messenger
    )
    haptics.setMethodCallHandler { call, result in
      guard call.method == "taptic" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let style = (call.arguments as? [String: Any])?["style"] as? String
      let id: SystemSoundID
      switch style {
      case "heavy":
        id = 1521
      case "medium":
        id = 1520
      default:
        id = 1519
      }
      AudioServicesPlaySystemSound(id)
      result(nil)
    }
  }
}
