import SwiftUI
import WidgetKit

// MARK: - 矩形小组件视图 (accessoryRectangular)

struct WatchRectangularView: View {
    let entry: WatchCourseEntry

    var body: some View {
        if let course = entry.topCourse {
            HStack(alignment: .center, spacing: 6) {
                // 左侧状态指示
                VStack(spacing: 0) {
                    if entry.isOngoing {
                        // 进行中：微型进度条
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                                .frame(width: 14, height: 14)
                            Circle()
                                .trim(from: 0, to: CGFloat(entry.progress))
                                .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 14, height: 14)
                                .rotationEffect(.degrees(-90))
                        }
                    } else {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                    }
                }

                // 右侧课程信息
                VStack(alignment: .leading, spacing: 1) {
                    // 第一行：状态 + 课程名
                    HStack(spacing: 3) {
                        Text(entry.isOngoing ? "正在上" : "下节课")
                            .font(.system(size: 10))
                            .opacity(0.7)
                    }

                    Text(course.course)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)

                    // 地点 + 时间
                    HStack(spacing: 4) {
                        Text(course.location)
                            .lineLimit(1)
                        Text("·")
                        Text(course.timeRange)
                    }
                    .font(.system(size: 11))
                    .opacity(0.8)
                }

                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text("近期无课程")
                        .font(.system(size: 14, weight: .semibold))
                    Text("今日课程已结束")
                        .font(.system(size: 11))
                        .opacity(0.7)
                }
                Spacer(minLength: 0)
            }
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
