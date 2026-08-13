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
    let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "EnfermiCambioLauncherIcon"
    )
    let channel = FlutterMethodChannel(
      name: "enfermicambio/launcher_icon",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setLauncherIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let logoId = arguments?["logoId"] as? String ?? "default"
      let iconName: String?
      switch logoId {
      case "red-transparent":
        iconName = "AppIconRedTransparent"
      case "red-cropped":
        iconName = "AppIconRedCropped"
      case "medical-cropped":
        iconName = "AppIconMedicalCropped"
      default:
        iconName = nil
      }
      DispatchQueue.main.async {
        guard UIApplication.shared.supportsAlternateIcons else {
          result(FlutterError(
            code: "not_supported",
            message: "Este iPhone no permite iconos alternativos.",
            details: nil
          ))
          return
        }
        UIApplication.shared.setAlternateIconName(iconName) { error in
          if let error = error {
            result(FlutterError(
              code: "icon_change_failed",
              message: error.localizedDescription,
              details: nil
            ))
            return
          }
          result([
            "changed": true,
            "message": "El icono de inicio se actualizó."
          ])
        }
      }
    }
  }
}
