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
                            .font(.footnote)
                            .opacity(0.8)
                        
                        Text(targetDate, style: .timer)
                            .font(.headline.bold().monospacedDigit())
                            .foregroundColor(.blue)
                    }
                }

                // 第二行：课程名
                Text(course.course)
                    .font(.headline)
                    .lineLimit(1)

                // 第三行：地点
                Text(course.location)
                    .font(.footnote)
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
                        .font(.headline)
                }
                Text("今日课程已全部结束")
                    .font(.footnote)
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
        if #available(iOS 16.0, watchOS 9.0, *) {
            content
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var content: some View {
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
                            .font(.title3.bold().monospacedDigit())
                        Text("分钟")
                            .font(.caption2)
                            .opacity(0.7)
                    }
                }
                .widgetLabel {
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        ProgressView(value: entry.progress)
                            .tint(.green)
                    }
                }
            } else {
                // 即将上课：显示开始时间
                ZStack {
                    AccessoryWidgetBackground()

                    VStack(spacing: 0) {
                        Image(systemName: "book.fill")
                            .font(.caption2)
                            .opacity(0.7)
                        Text(course.start_time)
                            .font(.footnote.bold().monospacedDigit())
                    }
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "moon.fill")
                        .font(.footnote)
                    Text("无课")
                        .font(.caption2.weight(.medium))
                }
            }
        }
    }
}

// MARK: - 内联小组件视图 (accessoryInline)

struct WatchInlineView: View {
    let entry: WatchCourseEntry

    var body: some View {
        if #available(iOS 14.0, watchOS 7.0, *) {
            content
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var content: some View {
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
        #if os(watchOS)
        if #available(watchOS 9.0, *) {
            content
        } else {
            EmptyView()
        }
        #else
        EmptyView()
        #endif
    }

    #if os(watchOS)
    @ViewBuilder
    private var content: some View {
        if let course = entry.topCourse {
            if entry.isOngoing {
                // 进行中：显示进度 gauge
                let nowMin = Calendar.current.component(.hour, from: entry.date) * 60
                    + Calendar.current.component(.minute, from: entry.date)
                let remaining = max(course.endMin - nowMin, 0)

                Text("\(remaining)'")
                    .font(.headline.bold().monospacedDigit())
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
                    .font(.footnote.bold().monospacedDigit())
                    .widgetCurvesContent()
                    .widgetLabel {
                        Text("📖 \(course.course)")
                    }
            }
        } else {
            Image(systemName: "moon.fill")
                .font(.headline)
                .widgetCurvesContent()
                .widgetLabel {
                    Text("无课程")
                }
        }
    }
    #endif
}
