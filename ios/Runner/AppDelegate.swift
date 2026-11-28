import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let fileChannelName = "com.chefandcost.app/file_intent"
  private static let urlChannelName = "com.chefandcost.app/url"

  private var fileChannel: FlutterMethodChannel?
  private var initialFileData: [String: String]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      initialFileData = Self.readChefyFile(from: url)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupChannels(messenger: engineBridge.applicationRegistrar.messenger())
  }

  func setupChannels(messenger: FlutterBinaryMessenger) {
    let fChannel = FlutterMethodChannel(name: Self.fileChannelName, binaryMessenger: messenger)
    fChannel.setMethodCallHandler { [weak self] call, result in
      if call.method == "getInitialFile" {
        result(self?.initialFileData)
        self?.initialFileData = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    self.fileChannel = fChannel

    let uChannel = FlutterMethodChannel(name: Self.urlChannelName, binaryMessenger: messenger)
    uChannel.setMethodCallHandler { call, result in
      guard call.method == "openUrl",
            let args = call.arguments as? [String: Any],
            let urlStr = args["url"] as? String,
            let url = URL(string: urlStr) else {
        result(false)
        return
      }
      DispatchQueue.main.async {
        UIApplication.shared.open(url, options: [:]) { success in
          result(success)
        }
      }
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    handleIncomingFileURL(url)
    return true
  }

  func handleIncomingFileURL(_ url: URL) {
    guard let payload = Self.readChefyFile(from: url) else { return }
    if let channel = fileChannel {
      DispatchQueue.main.async {
        channel.invokeMethod("onFileReceived", arguments: payload)
      }
    } else {
      initialFileData = payload
    }
  }

  static func readChefyFile(from url: URL) -> [String: String]? {
    let needsSecurityScope = url.startAccessingSecurityScopedResource()
    defer {
      if needsSecurityScope {
        url.stopAccessingSecurityScopedResource()
      }
    }
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
      return nil
    }
    return [
      "content": content,
      "fileName": url.lastPathComponent,
    ]
  }
}
