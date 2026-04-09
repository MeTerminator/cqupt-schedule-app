import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

@available(iOS 14.0, watchOS 7.0, *)
struct WatchCourseEntry: TimelineEntry {
    let date: Date
    let topCourse: WatchCourseInstance?
    let nextCourse: WatchCourseInstance?
    let isOngoing: Bool
    let progress: Double
    let todayCourseCount: Int
    let currentWeek: Int
}

// MARK: - Timeline Provider

@available(iOS 14.0, watchOS 7.0, *)
struct WatchCourseProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchCourseEntry {
        WatchCourseEntry(
            date: Date(),
            topCourse: nil,
            nextCourse: nil,
            isOngoing: false,
            progress: 0,
            todayCourseCount: 0,
            currentWeek: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (WatchCourseEntry) -> Void) {
        completion(buildEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<WatchCourseEntry>) -> Void) {
        let now = Date()
        let currentEntry = buildEntry(for: now)
        var entries: [WatchCourseEntry] = [currentEntry]

        // 为课程的关键时间点生成额外 entry
        if let schedule = SharedDataProvider.loadSchedule() {
            let todayCourses = SharedDataProvider.todayRemainingCourses(from: schedule, at: now)
            var refreshDates = Set<Date>()

            for course in todayCourses {
                if let start = combine(date: now, timeStr: course.start_time) {
                    refreshDates.insert(start)
                }
                if let end = combine(date: now, timeStr: course.end_time) {
                    refreshDates.insert(end)
                }
            }

            let futureDates = refreshDates.filter { $0 > now }.sorted()
            for date in futureDates {
                entries.append(buildEntry(for: date))
            }
        }

        // 设置刷新策略
        let calendar = Calendar.current
        let nextUpdate: Date
        if let schedule = SharedDataProvider.loadSchedule() {
            let todayCourses = SharedDataProvider.todayRemainingCourses(from: schedule, at: now)
            let futureTimes = todayCourses.compactMap { combine(date: now, timeStr: $0.start_time) }
                .filter { $0 > now }
                .sorted()

            if let nextTime = futureTimes.first {
                nextUpdate = nextTime
            } else {
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
                nextUpdate = calendar.startOfDay(for: tomorrow)
            }
        } else {
            // 无数据时 15 分钟后再试
            nextUpdate = calendar.date(byAdding: .minute, value: 15, to: now)!
        }

        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - 构建 Entry

    private func buildEntry(for date: Date) -> WatchCourseEntry {
        guard let schedule = SharedDataProvider.loadSchedule() else {
            return WatchCourseEntry(
                date: date, topCourse: nil, nextCourse: nil,
                isOngoing: false, progress: 0,
                todayCourseCount: 0, currentWeek: 0
            )
        }

        let top = SharedDataProvider.topCourse(from: schedule, at: date)
        let next = SharedDataProvider.nextUpcomingCourse(from: schedule, at: date)
        let todayCount = SharedDataProvider.todayAllCourses(from: schedule, at: date).count

        var isOngoing = false
        var progress = 0.0

        if let top = top {
            let status = SharedDataProvider.courseStatus(course: top, at: date, response: schedule)
            isOngoing = status == .ongoing
            if isOngoing {
                progress = top.progress(at: date)
            }
        }

        let firstMonday = SharedDataProvider.parseFirstMonday(from: schedule)
        let currentWeek = firstMonday.map { SharedDataProvider.getWeek(for: date, firstMonday: $0) } ?? 0

        // 如果 top 就是 next，则 next 取后续的
        var actualNext = next
        if let t = top, let n = next, t.id == n.id {
            let calendar = Calendar.current
            let nowMin = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
            let remaining = SharedDataProvider.todayRemainingCourses(from: schedule, at: date)
            actualNext = remaining.first { $0.startMin > nowMin && $0.id != t.id }
        }

        return WatchCourseEntry(
            date: date,
            topCourse: top,
            nextCourse: actualNext,
            isOngoing: isOngoing,
            progress: progress,
            todayCourseCount: todayCount,
            currentWeek: currentWeek
        )
    }

    private func combine(date: Date, timeStr: String) -> Date? {
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: date)
    }
}

// MARK: - Widget 定义

/// 矩形小组件 (accessoryRectangular)
struct WatchRectangularWidget: Widget {
    let kind: String = "WatchRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchCourseProvider()) { entry in
            content(entry: entry)
        }
        .configurationDisplayName("课程信息")
        .description("显示当前或下一节课的详细信息")
        .supportedFamilies([.accessoryRectangular])
    }
    
    @ViewBuilder
    private func content(entry: WatchCourseEntry) -> some View {
        if #available(iOS 17.0, watchOS 10.0, *) {
            WatchRectangularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        } else {
            WatchRectangularView(entry: entry)
        }
    }
}

/// 圆形小组件 (accessoryCircular)
struct WatchCircularWidget: Widget {
    let kind: String = "WatchCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchCourseProvider()) { entry in
            content(entry: entry)
        }
        .configurationDisplayName("课程进度")
        .description("环形显示课程进度或剩余时间")
        .supportedFamilies([.accessoryCircular])
    }
    
    @ViewBuilder
    private func content(entry: WatchCourseEntry) -> some View {
        if #available(iOS 17.0, watchOS 10.0, *) {
            WatchCircularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        } else {
            WatchCircularView(entry: entry)
        }
    }
}

/// 内联小组件 (accessoryInline)
struct WatchInlineWidget: Widget {
    let kind: String = "WatchInlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchCourseProvider()) { entry in
            content(entry: entry)
        }
        .configurationDisplayName("课程概览")
        .description("单行显示课程名和时间")
        .supportedFamilies([.accessoryInline])
    }
    
    @ViewBuilder
    private func content(entry: WatchCourseEntry) -> some View {
        if #available(iOS 17.0, watchOS 10.0, *) {
            WatchInlineView(entry: entry)
                .containerBackground(.clear, for: .widget)
        } else {
            WatchInlineView(entry: entry)
        }
    }
}

#if os(watchOS)
/// 角落小组件 (accessoryCorner)
struct WatchCornerWidget: Widget {
    let kind: String = "WatchCornerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchCourseProvider()) { entry in
            content(entry: entry)
        }
        .configurationDisplayName("课程角标")
        .description("在表盘角落显示课程倒计时")
        .supportedFamilies([.accessoryCorner])
    }
    
    @ViewBuilder
    private func content(entry: WatchCourseEntry) -> some View {
        if #available(watchOS 10.0, *) {
            WatchCornerView(entry: entry)
                .containerBackground(.clear, for: .widget)
        } else {
            WatchCornerView(entry: entry)
        }
    }
}
#endif
