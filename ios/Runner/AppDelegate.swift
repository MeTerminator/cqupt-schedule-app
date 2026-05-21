import Flutter
import UIKit
import SwiftUI
import AlarmKit

@available(iOS 26.0, *)
struct SimpleAlarmMetadata: AlarmMetadata {
    var appName: String = "cqupt_schedule_app"
}

@available(iOS 26.0, *)
extension AlarmButton {
    static var stopButton: Self {
        AlarmButton(text: "我知道了", textColor: .white, systemImageName: "stop.circle")
    }
}

extension UUID {
    static func deterministic(from string: String) -> UUID {
        var hash = string.hashValue
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8(hash & 0xFF)
            hash >>= 8
        }
        var hash2 = string.reversed().map { String($0) }.joined().hashValue
        for i in 8..<16 {
            bytes[i] = UInt8(hash2 & 0xFF)
            hash2 >>= 8
        }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 启动 WatchConnectivity（会自动监听 UserDefaults 变化并同步到 Watch）
    WatchSessionManager.shared.startSession()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let alarmChannel = FlutterMethodChannel(name: "top.met6.cquptschedule/alarm", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    
    alarmChannel.setMethodCallHandler { (call, result) in
        if #available(iOS 26.0, *) {
            if call.method == "requestPermission" {
                Task {
                    let alarmManager = AlarmManager.shared
                    switch alarmManager.authorizationState {
                    case .authorized:
                        DispatchQueue.main.async { result(true) }
                    case .denied:
                        DispatchQueue.main.async { result(false) }
                    case .notDetermined:
                        do {
                            let state = try await alarmManager.requestAuthorization()
                            DispatchQueue.main.async { result(state == .authorized) }
                        } catch {
                            DispatchQueue.main.async { result(false) }
                        }
                    @unknown default:
                        DispatchQueue.main.async { result(false) }
                    }
                }
            } else if call.method == "scheduleAlarms" {
                guard let arguments = call.arguments as? [[String: Any]] else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments must be a list of maps", details: nil))
                    return
                }
                
                Task {
                    let alarmManager = AlarmManager.shared
                    do {
                        for alarmDict in arguments {
                            guard let idStr = alarmDict["id"] as? String,
                                  let title = alarmDict["title"] as? String,
                                  let timeInMillis = alarmDict["timeInMillis"] as? Double else {
                                continue
                            }
                            
                            let uuid = UUID.deterministic(from: idStr)
                            let date = Date(timeIntervalSince1970: timeInMillis / 1000.0)
                            
                            let alertContent = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title), stopButton: .stopButton)
                            let attributes = AlarmAttributes<SimpleAlarmMetadata>(
                                presentation: AlarmPresentation(alert: alertContent),
                                tintColor: Color.blue
                            )
                            
                            let alarmConfiguration = AlarmManager.AlarmConfiguration<SimpleAlarmMetadata>(
                                schedule: .fixed(date),
                                attributes: attributes
                            )
                            
                            try await alarmManager.schedule(id: uuid, configuration: alarmConfiguration)
                        }
                        DispatchQueue.main.async {
                            result(true)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "SCHEDULE_ERROR", message: error.localizedDescription, details: nil))
                        }
                    }
                }
            } else if call.method == "cancelAlarm" {
                guard let idStr = call.arguments as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Argument must be a string", details: nil))
                    return
                }
                let uuid = UUID.deterministic(from: idStr)
                try? AlarmManager.shared.cancel(id: uuid)
                result(true)
            } else if call.method == "clearAllAlarms" {
                do {
                    let remoteAlarms = try AlarmManager.shared.alarms
                    for alarm in remoteAlarms {
                        try? AlarmManager.shared.cancel(id: alarm.id)
                    }
                    result(true)
                } catch {
                    result(FlutterError(code: "CLEAR_ERROR", message: error.localizedDescription, details: nil))
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        } else {
            // iOS 26.0 以下不支持 AlarmKit，直接返回优雅的处理结果
            if call.method == "requestPermission" {
                result(false)
            } else if call.method == "scheduleAlarms" {
                result(FlutterError(code: "UNSUPPORTED_OS_VERSION", message: "AlarmKit requires iOS 26.0 or newer", details: nil))
            } else if call.method == "cancelAlarm" || call.method == "clearAllAlarms" {
                result(true)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
  }
}
