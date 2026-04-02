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

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let storageChannel = FlutterMethodChannel(
      name: "com.example.bavi/storage",
      binaryMessenger: controller.binaryMessenger
    )
    storageChannel.setMethodCallHandler { (call, result) in
      if call.method == "getPhysicalMemoryBytes" {
        result(Int64(bitPattern: UInt64(ProcessInfo.processInfo.physicalMemory)))
      } else if call.method == "getAvailableBytes" {
        do {
          let attrs = try FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
          )
          if let freeSize = attrs[.systemFreeSize] as? Int64 {
            result(freeSize)
          } else {
            result(FlutterError(code: "UNAVAILABLE", message: "Could not read free size", details: nil))
          }
        } catch {
          result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
