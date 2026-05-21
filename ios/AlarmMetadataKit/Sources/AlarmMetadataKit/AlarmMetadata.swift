import AlarmKit
import SwiftUI

// MARK: - SimpleAlarmMetadata
// 定义在独立的 Swift Package 中，使 Runner 和 CourseWidget 两个 Target
// 引用的是完全相同的 Swift 模块类型（AlarmMetadataKit.SimpleAlarmMetadata）
// 这是让 AlarmKit Live Activity 正确跨进程类型匹配的唯一可靠方案

@available(iOS 26.0, *)
public struct SimpleAlarmMetadata: AlarmMetadata {
    public var appName: String
    
    public init(appName: String = "cqupt_schedule_app") {
        self.appName = appName
    }
}

// MARK: - AlarmButton 便利扩展
@available(iOS 26.0, *)
extension AlarmButton {
    /// 主停止按钮（"我知道了"）
    public static var stopButton: Self {
        AlarmButton(
            text: LocalizedStringResource(String.LocalizationValue("我知道了")),
            textColor: .white,
            systemImageName: "stop.circle"
        )
    }
    /// 暂停倒计时按钮
    public static var pauseButton: Self {
        AlarmButton(
            text: LocalizedStringResource(String.LocalizationValue("暂停")),
            textColor: .white,
            systemImageName: "pause.fill"
        )
    }
    /// 继续倒计时按钮
    public static var resumeButton: Self {
        AlarmButton(
            text: LocalizedStringResource(String.LocalizationValue("继续")),
            textColor: .white,
            systemImageName: "play.fill"
        )
    }
    /// 稍后提醒按钮（snooze）
    public static var snoozeButton: Self {
        AlarmButton(
            text: LocalizedStringResource(String.LocalizationValue("稍后提醒")),
            textColor: .white,
            systemImageName: "repeat.circle"
        )
    }
}
