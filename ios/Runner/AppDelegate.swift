import UIKit
import Flutter
import NaverThirdPartyLogin
import GoogleMaps
import SceneKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var arModelChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let mapsKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !mapsKey.isEmpty,
       !mapsKey.hasPrefix("$(") {
      GMSServices.provideAPIKey(mapsKey)
    }
    GeneratedPluginRegistrant.register(with: self)
    configureARModelChannel()

    let instance = NaverThirdPartyLoginConnection.getSharedInstance()
    let naverKey = Bundle.main.object(forInfoDictionaryKey: "naverConsumerKey") as? String ?? ""
    let naverSecret = Bundle.main.object(forInfoDictionaryKey: "naverConsumerSecret") as? String ?? ""
    if !naverKey.isEmpty, !naverSecret.isEmpty, !naverKey.hasPrefix("$(") {
      instance?.isInAppOauthEnable = true
      instance?.serviceUrlScheme = "naver\(naverKey)"
      instance?.consumerKey = naverKey
      instance?.consumerSecret = naverSecret
      instance?.appName = "bang9"
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureARModelChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "bang9/ar_model",
      binaryMessenger: controller.binaryMessenger
    )
    arModelChannel = channel

    channel.setMethodCallHandler { call, result in
      guard call.method == "validateModel",
            let arguments = call.arguments as? [String: Any],
            let path = arguments["path"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let url = Bundle.main.url(forResource: path, withExtension: nil) else {
        result(FlutterError(
          code: "MODEL_NOT_FOUND",
          message: "앱에 3D 모델 파일이 포함되지 않았습니다: \(path)",
          details: nil
        ))
        return
      }

      guard let node = SCNReferenceNode(url: url) else {
        result(FlutterError(
          code: "MODEL_LOAD_FAILED",
          message: "3D 모델을 SceneKit으로 불러오지 못했습니다: \(path)",
          details: nil
        ))
        return
      }

      node.load()

      var geometryCount = node.geometry == nil ? 0 : 1
      node.enumerateChildNodes { child, _ in
        if child.geometry != nil {
          geometryCount += 1
        }
      }

      guard geometryCount > 0 else {
        result(FlutterError(
          code: "MODEL_EMPTY",
          message: "3D 모델에 표시할 형상이 없습니다: \(path)",
          details: nil
        ))
        return
      }

      result(["ok": true, "geometryCount": geometryCount])
    }
  }

  // ✅ URL 처리 메서드는 반드시 클래스 내부에 있어야 함!
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if NaverThirdPartyLoginConnection
      .getSharedInstance()
      .application(app, open: url, options: options) {
        return true
    }
    return super.application(app, open: url, options: options)
  }
}
