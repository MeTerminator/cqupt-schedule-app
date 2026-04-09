import SwiftUI
import WidgetKit

// MARK: - 矩形小组件视图 (accessoryRectangular)

struct WatchRectangularView: View {
    let entry: WatchCourseEntry

    var body: some View {
        if let course = entry.topCourse {
            VStack(alignment: .leading, spacing: 2) {
                // 第一行：倒计时
                if let targetDate = entry.isOngoing ? course.endDate(on: entry.date) : course.startDate(on: entry.date) {
                    HStack(spacing: 4) {
                        Text(entry.isOngoing ? "离下课" : "离上课")
                            .font(.system(size: 15))
                            .opacity(0.8)
                        
                        Text(targetDate, style: .timer)
                            .font(.system(size: 16, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.blue)
                    }
                }

                // 第二行：课程名
                Text(course.course)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)

                // 第三行：地点
                Text(course.location)
                    .font(.system(size: 15))
                    .lineLimit(1)
                    .opacity(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("近期无课程")
                        .font(.system(size: 16, weight: .bold))
                }
                Text("今日课程已全部结束")
                    .font(.system(size: 14))
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 圆形小组件视图 (accessoryCircular)

struct WatchCircularView: View {
    let entry: WatchCourseEntry

    var body: some View {
        if let course = entry.topCourse {
            if entry.isOngoing {
                // 进行中：环形进度 + 剩余分钟
                let nowMin = Calendar.current.component(.hour, from: entry.date) * 60
                    + Calendar.current.component(.minute, from: entry.date)
                let remaining = max(course.endMin - nowMin, 0)

                ZStack {
                    AccessoryWidgetBackground()

                    VStack(spacing: 0) {
                        Text("\(remaining)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("分钟")
                            .font(.system(size: 8))
                            .opacity(0.7)
                    }
                }
                .widgetLabel {
                    ProgressView(value: entry.progress)
                        .tint(.green)
                }
            } else {
                // 即将上课：显示开始时间
                ZStack {
                    AccessoryWidgetBackground()

                    VStack(spacing: 0) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 10))
                            .opacity(0.7)
                        Text(course.start_time)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 14))
                    Text("无课")
                        .font(.system(size: 10, weight: .medium))
                }
            }
        }
    }
}

// MARK: - 内联小组件视图 (accessoryInline)

struct WatchInlineView: View {
    let entry: WatchCourseEntry

    var body: some View {
        if let course = entry.topCourse {
            if entry.isOngoing {
                let nowMin = Calendar.current.component(.hour, from: entry.date) * 60
                    + Calendar.current.component(.minute, from: entry.date)
                let remaining = max(course.endMin - nowMin, 0)

                Label {
                    Text("\(course.course) · 还剩\(remaining)分钟")
                } icon: {
                    Image(systemName: "book.fill")
                }
            } else {
                Label {
                    Text("\(course.course) · \(course.start_time)")
                } icon: {
                    Image(systemName: "clock.fill")
                }
            }
        } else {
            Label {
                Text("今日无更多课程")
            } icon: {
                Image(systemName: "checkmark.circle")
            }
        }
    }
}

// MARK: - 角落小组件视图 (accessoryCorner)

struct WatchCornerView: View {
    let entry: WatchCourseEntry

    var body: some View {
        if let course = entry.topCourse {
            if entry.isOngoing {
                // 进行中：显示进度 gauge
                let nowMin = Calendar.current.component(.hour, from: entry.date) * 60
                    + Calendar.current.component(.minute, from: entry.date)
                let remaining = max(course.endMin - nowMin, 0)

                Text("\(remaining)'")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .widgetCurvesContent()
                    .widgetLabel {
                        Gauge(value: entry.progress) {
                            Text(course.course)
                        }
                        .gaugeStyle(.linearCapacity)
                        .tint(.green)
                    }
            } else {
                // 即将上课：显示时间
                Text(course.start_time)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .widgetCurvesContent()
                    .widgetLabel {
                        Text("📖 \(course.course)")
                    }
            }
        } else {
            Image(systemName: "moon.fill")
                .font(.system(size: 18))
                .widgetCurvesContent()
                .widgetLabel {
                    Text("无课程")
                }
        }
    }
}
