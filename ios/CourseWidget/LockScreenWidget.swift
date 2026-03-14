import SwiftUI
import WidgetKit

struct LockScreenWidgetView: View {
    var entry: CourseEntry

    var body: some View {
        // 获取当前分钟数
        let nowMin =
            Calendar.current.component(.hour, from: entry.date) * 60
            + Calendar.current.component(.minute, from: entry.date)

        // 筛选出当前或接下来的一节课
        if let course = entry.courses.first(where: { $0.endMin > nowMin }) {
            let isOngoing = course.startMin <= nowMin
            let targetMin = isOngoing ? course.endMin : course.startMin
            let remaining = targetMin - nowMin
            let timeStr = String(format: "%02d:%02d", remaining / 60, remaining % 60)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(isOngoing ? "还剩 \(timeStr) 下课" : "还剩 \(timeStr) 上课")
                        .font(.system(size: 14, weight: .bold))
                    Text(course.course)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(course.location)
                        .font(.system(14))
                        .lineLimit(1)
                }

                // 如果是进行中，显示进度环
                if isOngoing {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: CGFloat(course.progress(at: entry.date)))
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 20, height: 20)
                }
            }
        } else {
            Text("当前无课").font(.subheadline)
        }
    }
}

// 锁屏组件定义
struct LockScreenWidget: Widget {
    let kind: String = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("锁屏课表")
        .description("显示课程进度与倒计时")
        .supportedFamilies([.accessoryRectangular])  // 仅支持锁屏矩形
    }
}
