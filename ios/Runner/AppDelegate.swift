import Flutter
import UIKit
import SwiftUI
import AlarmKit
import ActivityKit

// MARK: - Alarm 元数据和按钮拖展
// 注意：SimpleAlarmMetadata 同时定义在 CourseWidget/WidgetBundle.swift 中
// 两处的类型必须完全相同才能让 AlarmKit 正确关联 Live Activity
// 目前两处独立定义，属于不同 Module，待通过 Xcode 添加 Local Package 解决

@available(iOS 26.0, *)
struct SimpleAlarmMetadata: AlarmMetadata {
    var appName: String = "cqupt_schedule_app"
    /// 稍后提醒时长（分钟），供 Widget 平钺计算进度环比例
    var snoozeMinutes: Int = 9
    var alarmId: String = ""
}

@available(iOS 26.0, *)
struct CourseAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var courseName: String
        var classroom: String
        var startTime: Date
        var endTime: Date
        var leadMinutes: Int
    }
}

@available(iOS 26.0, *)
extension AlarmButton {
    static var stopButton: Self {
        AlarmButton(
            text: LocalizedStringResource(String.LocalizationValue("我知道了")),
            textColor: .white,
            systemImageName: "stop.circle"
        )
    }
    static var pauseButton: Self {
        AlarmButton(
            text: LocalizedStringResource(String.LocalizationValue("暂停")),
            textColor: .white,
            systemImageName: "pause.fill"
        )
    }
    static var resumeButton: Self {
        AlarmButton(
            text: LocalizedStringResource(String.LocalizationValue("继续")),
            textColor: .white,
            systemImageName: "play.fill"
        )
    }
    static var snoozeButton: Self {
        AlarmButton(
            text: LocalizedStringResource(String.LocalizationValue("稍后提醒")),
            textColor: .white,
            systemImageName: "repeat.circle"
        )
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
            } else if call.method == "checkOSVersionSupport" {
                result(true)
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
                                  let title = alarmDict["title"] as? String else {
                                continue
                            }
                            
                            let timeInMillisRaw = alarmDict["timeInMillis"]
                            var timeInMillis: Double = 0
                            if let val = timeInMillisRaw as? Double {
                                timeInMillis = val
                            } else if let val = timeInMillisRaw as? Int64 {
                                timeInMillis = Double(val)
                            } else if let val = timeInMillisRaw as? Int {
                                timeInMillis = Double(val)
                            } else if let val = timeInMillisRaw as? NSNumber {
                                timeInMillis = val.doubleValue
                            } else {
                                continue
                            }
                            
                            // 解析稍后提醒分钟数（默认 9 分钟）
                            let snoozeMinutesRaw = alarmDict["snoozeMinutes"]
                            var snoozeMinutes = 9
                            if let val = snoozeMinutesRaw as? Int {
                                snoozeMinutes = val
                            } else if let val = snoozeMinutesRaw as? Int64 {
                                snoozeMinutes = Int(val)
                            } else if let val = snoozeMinutesRaw as? Double {
                                snoozeMinutes = Int(val)
                            } else if let val = snoozeMinutesRaw as? NSNumber {
                                snoozeMinutes = val.intValue
                            }
                            
                            let uuid = UUID.deterministic(from: idStr)
                            let date = Date(timeIntervalSince1970: timeInMillis / 1000.0)
                            
                            // Alert 主视图：带停止按钮 + 稍后提醒 secondaryButton
                            // iOS 26.1+ 废弃了 stopButton（系统自动管理），需做版本区分
                            let alertContent: AlarmPresentation.Alert
                            if #available(iOS 26.1, *) {
                                alertContent = AlarmPresentation.Alert(
                                    title: LocalizedStringResource(String.LocalizationValue(title)),
                                    secondaryButton: .snoozeButton,
                                    secondaryButtonBehavior: .countdown
                                )
                            } else {
                                alertContent = AlarmPresentation.Alert(
                                    title: LocalizedStringResource(String.LocalizationValue(title)),
                                    stopButton: .stopButton,
                                    secondaryButton: .snoozeButton,
                                    secondaryButtonBehavior: .countdown
                                )
                            }
                            
                            // Countdown 倒计时视图（稍后提醒进行中时显示）
                            let countdownContent = AlarmPresentation.Countdown(
                                title: LocalizedStringResource(String.LocalizationValue(title))
                            )
                            
                            // Paused 暂停视图（用户暂停倒计时时显示）
                            let pausedContent = AlarmPresentation.Paused(
                                title: LocalizedStringResource(String.LocalizationValue("已暂停")),
                                resumeButton: .resumeButton
                            )
                            
                            let attributes = AlarmAttributes<SimpleAlarmMetadata>(
                                presentation: AlarmPresentation(
                                    alert: alertContent,
                                    countdown: countdownContent,
                                    paused: pausedContent
                                ),
                                metadata: SimpleAlarmMetadata(snoozeMinutes: snoozeMinutes, alarmId: uuid.uuidString),
                                tintColor: Color.blue
                            )
                            
                            // postAlert = 用户点击"稍后提醒"后的倒计时时长（snooze 时长）
                            // preAlert = 闹铃前的倒计时；设为 1 秒（不可为 0，否则系统校验失败）
                            let countdownDuration = Alarm.CountdownDuration(
                                preAlert: 1,
                                postAlert: TimeInterval(snoozeMinutes * 60)
                            )
                            
                            let alarmConfiguration = AlarmManager.AlarmConfiguration<SimpleAlarmMetadata>(
                                countdownDuration: countdownDuration,
                                schedule: .fixed(date),
                                attributes: attributes
                            )
                            
                            _ = try await alarmManager.schedule(id: uuid, configuration: alarmConfiguration)
                        }
                        DispatchQueue.main.async {
                            result(true)
                        }
                    } catch {
                        print("[AlarmKit] schedule failed with error: \(error)")
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
            } else if call.method == "startCourseLiveActivity" {
                guard let args = call.arguments as? [String: Any],
                      args["courseId"] is String,
                      let courseName = args["courseName"] as? String,
                      let classroom = args["classroom"] as? String,
                      let startTimeRaw = args["startTimeInMillis"],
                      let endTimeRaw = args["endTimeInMillis"] else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
                    return
                }
                
                let startTimeMillis = (startTimeRaw as? NSNumber)?.int64Value ?? 0
                let endTimeMillis = (endTimeRaw as? NSNumber)?.int64Value ?? 0
                let leadMinutes = args["leadMinutes"] as? Int ?? 15
                
                let startDate = Date(timeIntervalSince1970: Double(startTimeMillis) / 1000.0)
                let endDate = Date(timeIntervalSince1970: Double(endTimeMillis) / 1000.0)
                
                Task {
                    // 先停止之前的所有课程 Live Activity，保证只有一个活跃
                    for activity in Activity<CourseAttributes>.activities {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    }
                    
                    let attributes = CourseAttributes()
                    let contentState = CourseAttributes.ContentState(
                        courseName: courseName,
                        classroom: classroom,
                        startTime: startDate,
                        endTime: endDate,
                        leadMinutes: leadMinutes
                    )
                    
                    do {
                        _ = try Activity<CourseAttributes>.request(
                            attributes: attributes,
                            content: ActivityContent(state: contentState, staleDate: nil),
                            pushType: nil
                        )
                        DispatchQueue.main.async {
                            result(true)
                        }
                    } catch {
                        print("Failed to start Course Live Activity: \(error)")
                        DispatchQueue.main.async {
                            result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: nil))
                        }
                    }
                }
            } else if call.method == "stopCourseLiveActivity" {
                Task {
                    for activity in Activity<CourseAttributes>.activities {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    }
                    DispatchQueue.main.async {
                        result(true)
                    }
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        } else {
            // iOS 26.0 以下不支持 AlarmKit / Course Live Activity，直接返回优雅的处理结果
            if call.method == "requestPermission" {
                result(false)
            } else if call.method == "checkOSVersionSupport" {
                result(false)
            } else if call.method == "scheduleAlarms" {
                result(FlutterError(code: "UNSUPPORTED_OS_VERSION", message: "AlarmKit requires iOS 26.0 or newer", details: nil))
            } else if call.method == "cancelAlarm" || call.method == "clearAllAlarms" {
                result(true)
            } else if call.method == "startCourseLiveActivity" {
                result(false)
            } else if call.method == "stopCourseLiveActivity" {
                result(true)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
  }
}
