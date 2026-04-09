import Foundation

// MARK: - 共享数据提供者

/// 从 App Group UserDefaults 中读取 iPhone 端同步的课表数据
struct SharedDataProvider {
    static let appGroupId = "group.top.met6.cquptscheduleios"
    static let dataKey = "full_schedule_json"

    // MARK: - 数据加载

    /// 从 App Group UserDefaults 加载完整的课表数据
    static func loadSchedule() -> WatchScheduleResponse? {
        let prefs = UserDefaults(suiteName: appGroupId)
        guard let jsonString = prefs?.string(forKey: dataKey),
              let data = jsonString.data(using: .utf8),
              let response = try? JSONDecoder().decode(WatchScheduleResponse.self, from: data)
        else { return nil }
        return response
    }

    // MARK: - 周次计算

    /// 计算指定日期对应的教学周
    static func getWeek(for date: Date, firstMonday: Date) -> Int {
        let calendar = Calendar.current
        let diff = calendar.dateComponents([.day], from: firstMonday, to: date).day ?? 0
        return (diff / 7) + 1
    }

    /// 解析第一周周一的日期
    static func parseFirstMonday(from response: WatchScheduleResponse) -> Date? {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: String(response.week_1_monday.prefix(10)))
    }

    // MARK: - 星期计算

    /// 获取 iOS weekday (1=Sun) 转换为课表的 day (1=Mon...7=Sun)
    static func courseDay(from date: Date) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date)
        return (weekday == 1) ? 7 : (weekday - 1)
    }

    // MARK: - 课程过滤

    /// 获取今天剩余的课程（尚未结束的）
    static func todayRemainingCourses(from response: WatchScheduleResponse, at date: Date) -> [WatchCourseInstance] {
        guard let firstMonday = parseFirstMonday(from: response) else { return [] }

        let calendar = Calendar.current
        let currentWeek = getWeek(for: date, firstMonday: firstMonday)
        let currentDay = courseDay(from: date)
        let nowMin = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        return response.instances
            .filter { $0.week == currentWeek && $0.day == currentDay && $0.endMin > nowMin }
            .sorted { $0.startMin < $1.startMin }
    }

    /// 获取今天全部课程
    static func todayAllCourses(from response: WatchScheduleResponse, at date: Date) -> [WatchCourseInstance] {
        guard let firstMonday = parseFirstMonday(from: response) else { return [] }

        let currentWeek = getWeek(for: date, firstMonday: firstMonday)
        let currentDay = courseDay(from: date)

        return response.instances
            .filter { $0.week == currentWeek && $0.day == currentDay }
            .sorted { $0.startMin < $1.startMin }
    }

    /// 获取明天全部课程
    static func tomorrowAllCourses(from response: WatchScheduleResponse, at date: Date) -> [WatchCourseInstance] {
        guard let firstMonday = parseFirstMonday(from: response) else { return [] }

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)!
        let tomorrowWeek = getWeek(for: tomorrow, firstMonday: firstMonday)
        let tomorrowDay = courseDay(from: tomorrow)

        return response.instances
            .filter { $0.week == tomorrowWeek && $0.day == tomorrowDay }
            .sorted { $0.startMin < $1.startMin }
    }

    /// 获取当前正在进行的课程
    static func ongoingCourse(from response: WatchScheduleResponse, at date: Date) -> WatchCourseInstance? {
        let calendar = Calendar.current
        let nowMin = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        return todayRemainingCourses(from: response, at: date)
            .first { $0.startMin <= nowMin && $0.endMin > nowMin }
    }

    /// 获取下一节课（今天即将开始的，或明天第一节）
    static func nextUpcomingCourse(from response: WatchScheduleResponse, at date: Date) -> WatchCourseInstance? {
        let calendar = Calendar.current
        let nowMin = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        // 先查今天还没开始的
        let todayUpcoming = todayRemainingCourses(from: response, at: date)
            .first { $0.startMin > nowMin }

        if let course = todayUpcoming { return course }

        // 查明天第一节课
        return tomorrowAllCourses(from: response, at: date).first
    }

    /// 获取"当前最重要的课程"：正在上的 > 今天下一节 > 明天第一节
    static func topCourse(from response: WatchScheduleResponse, at date: Date) -> WatchCourseInstance? {
        if let ongoing = ongoingCourse(from: response, at: date) {
            return ongoing
        }
        return nextUpcomingCourse(from: response, at: date)
    }

    /// 判断课程在指定时刻的状态
    static func courseStatus(course: WatchCourseInstance, at date: Date, response: WatchScheduleResponse) -> WatchCourseStatus {
        guard let firstMonday = parseFirstMonday(from: response) else { return .upcoming }

        let calendar = Calendar.current
        let currentWeek = getWeek(for: date, firstMonday: firstMonday)
        let currentDay = courseDay(from: date)
        let nowMin = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        let isToday = course.week == currentWeek && course.day == currentDay

        if isToday {
            if course.startMin <= nowMin && course.endMin > nowMin {
                return .ongoing
            } else if course.startMin > nowMin {
                return .upcoming
            } else {
                return .finished
            }
        }
        return .upcoming
    }

    // MARK: - 倒计时

    /// 计算距离课程开始/结束的倒计时目标 Date
    static func countdownTarget(for course: WatchCourseInstance, isOngoing: Bool, at date: Date, response: WatchScheduleResponse) -> Date? {
        guard let firstMonday = parseFirstMonday(from: response) else { return nil }

        let calendar = Calendar.current
        let currentWeek = getWeek(for: date, firstMonday: firstMonday)
        let currentDay = courseDay(from: date)
        let isToday = course.week == currentWeek && course.day == currentDay

        let timeStr = isOngoing ? course.end_time : course.start_time
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = h
        components.minute = m
        components.second = 0

        var targetDate = calendar.date(from: components)
        if !isToday, let t = targetDate {
            targetDate = calendar.date(byAdding: .day, value: 1, to: t)
        }
        return targetDate
    }

    // MARK: - 格式化

    /// 格式化日期信息
    static func formatDateInfo(for date: Date) -> String {
        let dayNames = ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let day = courseDay(from: date)
        let df = DateFormatter()
        df.dateFormat = "M/d"
        return "\(df.string(from: date)) \(dayNames[day])"
    }

    /// 生成课程的颜色 hue 值（0-360），与 Flutter 端一致的黄金角分配
    static func colorHue(for courseName: String, allCourseNames: [String]) -> Double {
        guard let index = allCourseNames.firstIndex(of: courseName) else {
            return Double(abs(courseName.hashValue) % 360)
        }
        return Double(index) * 137.5.truncatingRemainder(dividingBy: 360)
    }
}
