import SwiftUI
import WidgetKit
import AlarmKit
import ActivityKit
import AppIntents

// MARK: - Shared Types（与 AppDelegate.swift 定义完全一致）

@available(iOS 26.0, *)
struct SimpleAlarmMetadata: AlarmMetadata {
    var appName: String = "cqupt_schedule_app"
    var snoozeMinutes: Int = 9
    var alarmId: String = ""
}

@available(iOS 26.0, *)
extension AlarmButton {
    static var stopButton: Self {
        AlarmButton(text: LocalizedStringResource(String.LocalizationValue("我知道了")),
                    textColor: .white, systemImageName: "stop.circle")
    }
    static var pauseButton: Self {
        AlarmButton(text: LocalizedStringResource(String.LocalizationValue("暂停")),
                    textColor: .white, systemImageName: "pause.fill")
    }
    static var resumeButton: Self {
        AlarmButton(text: LocalizedStringResource(String.LocalizationValue("继续")),
                    textColor: .white, systemImageName: "play.fill")
    }
    static var snoozeButton: Self {
        AlarmButton(text: LocalizedStringResource(String.LocalizationValue("稍后提醒")),
                    textColor: .white, systemImageName: "repeat.circle")
    }
}

// MARK: - CancelAlarmIntent

@available(iOS 26.0, *)
struct CancelAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "取消闹钟"
    
    @Parameter(title: "Alarm ID")
    var alarmId: String
    
    init() {
        self.alarmId = ""
    }
    
    init(alarmId: String) {
        self.alarmId = alarmId
    }
    
    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmId) {
            try? AlarmManager.shared.cancel(id: uuid)
        }
        return .result()
    }
}

// MARK: - 锁屏实时活动卡片

@available(iOS 26.0, *)
struct AlarmLockScreenCard: View {
    let context: ActivityViewContext<AlarmAttributes<SimpleAlarmMetadata>>

    private var subtitleText: String {
        switch context.state.mode {
        case .countdown:
            return "稍后提醒倒计时中"
        case .paused:
            return "已暂停"
        default:
            return "课程提醒"
        }
    }

    var body: some View {
        HStack {
            // 左侧标题/副标题
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.presentation.alert.title)
                    .font(.headline)
                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 右侧倒计时
            timerLabel
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
    }

    // 右侧计时数字
    @ViewBuilder
    private var timerLabel: some View {
        if case let .countdown(cd) = context.state.mode {
            Text(timerInterval: Date.now...cd.fireDate, countsDown: true)
                .font(.title.bold())
                .foregroundColor(.orange)
        } else if case let .paused(ps) = context.state.mode {
            let remaining = ps.totalCountdownDuration - ps.previouslyElapsedDuration
            let m = Int(remaining) / 60
            let s = Int(remaining) % 60
            Text(String(format: "%d:%02d", m, s))
                .font(.title.bold())
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - AlarmLiveActivity

@available(iOS 26.0, *)
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<SimpleAlarmMetadata>.self) { context in
            // 锁屏 / 通知横幅卡片
            AlarmLockScreenCard(context: context)

        } dynamicIsland: { context in
            DynamicIsland {
                // ── 展开态 ──
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        if case let .countdown(cd) = context.state.mode {
                            Text(timerInterval: Date.now...cd.fireDate, countsDown: true)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.orange)
                        } else if case let .paused(ps) = context.state.mode {
                            let remaining = ps.totalCountdownDuration - ps.previouslyElapsedDuration
                            let m = Int(remaining) / 60
                            let s = Int(remaining) % 60
                            Text(String(format: "%d:%02d", m, s))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(context.attributes.presentation.alert.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.leading, 12)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    let alarmId = context.attributes.metadata?.alarmId ?? ""
                    Button(intent: CancelAlarmIntent(alarmId: alarmId)) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }

            } compactLeading: {
                // 紧凑态 Leading：渐变图标
                Image(systemName: "alarm.fill")
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow],
                                      startPoint: .top, endPoint: .bottom)
                    )
                    .font(.system(size: 14, weight: .bold))

            } compactTrailing: {
                // 紧凑态 Trailing：倒计时数字 / 暂停点 / 响铃点
                if case let .countdown(cd) = context.state.mode {
                    Text(timerInterval: Date.now...cd.fireDate, countsDown: true)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                } else if case .paused = context.state.mode {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                } else {
                    // alert 模式：橙色圆点
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }

            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow],
                                      startPoint: .top, endPoint: .bottom)
                    )
            }
        }
    }
}

// MARK: - Course Live Activity Attributes

@available(iOS 26.0, *)
struct CourseAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var courseName: String
        var classroom: String
        var startTime: Date
        var endTime: Date
    }
}

// MARK: - 课程锁屏/通知中心实时活动卡片

@available(iOS 26.0, *)
struct CourseLockScreenCard: View {
    let context: ActivityViewContext<CourseAttributes>
    
    var body: some View {
        TimelineView(.explicit([context.state.startTime])) { timelineContext in
            let isBeforeClass = timelineContext.date < context.state.startTime
            
            HStack {
                // 左侧课程名与教室
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.courseName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(context.state.classroom)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 右侧倒计时
                if isBeforeClass {
                    // 课前倒计时：00:00 样式
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("即将上课")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(timerInterval: Date.now...context.state.startTime, countsDown: true)
                            .font(.title2.bold().monospacedDigit())
                            .foregroundColor(.blue)
                    }
                } else {
                    // 上课中倒计时：下课时间与进度环
                    HStack(spacing: 8) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("下课倒计时")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundColor(.green)
                        }
                        
                        ProgressView(timerInterval: context.state.startTime...context.state.endTime, countsDown: true)
                            .progressViewStyle(.circular)
                            .tint(.green)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - CourseLiveActivity Widget

@available(iOS 26.0, *)
struct CourseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CourseAttributes.self) { context in
            CourseLockScreenCard(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // ── 灵动岛展开态 ──
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.courseName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(context.state.classroom)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    TimelineView(.explicit([context.state.startTime])) { timelineContext in
                        let isBeforeClass = timelineContext.date < context.state.startTime
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            if isBeforeClass {
                                Text("即将上课")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(timerInterval: Date.now...context.state.startTime, countsDown: true)
                                    .font(.title3.bold().monospacedDigit())
                                    .foregroundColor(.blue)
                            } else {
                                HStack(spacing: 6) {
                                    Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                                        .font(.caption.bold().monospacedDigit())
                                        .foregroundColor(.green)
                                    ProgressView(timerInterval: context.state.startTime...context.state.endTime, countsDown: true)
                                        .progressViewStyle(.circular)
                                        .tint(.green)
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .padding(.trailing, 8)
                    }
                }
                
            } compactLeading: {
                TimelineView(.explicit([context.state.startTime])) { timelineContext in
                    let isBeforeClass = timelineContext.date < context.state.startTime
                    Image(systemName: isBeforeClass ? "book.closed.fill" : "book.fill")
                        .foregroundStyle(isBeforeClass ? Color.blue : Color.green)
                        .font(.system(size: 13))
                }
            } compactTrailing: {
                TimelineView(.explicit([context.state.startTime])) { timelineContext in
                    let isBeforeClass = timelineContext.date < context.state.startTime
                    
                    if isBeforeClass {
                        Text(timerInterval: Date.now...context.state.startTime, countsDown: true)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue)
                            .monospacedDigit()
                    } else {
                        Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                            .monospacedDigit()
                    }
                }
            } minimal: {
                TimelineView(.explicit([context.state.startTime])) { timelineContext in
                    let isBeforeClass = timelineContext.date < context.state.startTime
                    Image(systemName: "book.fill")
                        .foregroundColor(isBeforeClass ? .blue : .green)
                }
            }
        }
    }
}

// MARK: - Widget Bundle

@main
struct CquptScheduleWidgetBundle: WidgetBundle {
    var body: some Widget {
        widgets
    }

    @WidgetBundleBuilder
    var widgets: some Widget {
        UpcomingCourseWidget()
        TodayCourseWidget()
        LockScreenWidget()
        if #available(iOS 26.0, *) {
            AlarmLiveActivity()
            CourseLiveActivity()
        }
    }
}
