import WidgetKit
import SwiftUI

struct CourseEntry: TimelineEntry {
    let date: Date
    let courses: [CourseInstance]
    let todayWeekInfo: String
    let tomorrowWeekInfo: String
    let todayDateStr: String
    let tomorrowDateStr: String
    let todayCourseCount: Int
    let tomorrowCourseCount: Int
}


struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> CourseEntry {
        CourseEntry(date: Date(), courses: [], todayWeekInfo: "第 - 周", tomorrowWeekInfo: "第 - 周", todayDateStr: "00/00", tomorrowDateStr: "00/00", todayCourseCount: 0, tomorrowCourseCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (CourseEntry) -> Void) {
        completion(loadData())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<CourseEntry>) -> Void) {
        let entry = loadData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadData() -> CourseEntry {
        let prefs = UserDefaults(suiteName: "group.top.met6.cquptscheduleios")
        let now = Date()
        let calendar = Calendar.current
        
        guard let jsonString = prefs?.string(forKey: "full_schedule_json"),
              let data = jsonString.data(using: .utf8),
              let response = try? JSONDecoder().decode(ScheduleResponse.self, from: data) else {
            return CourseEntry(date: now, courses: [], todayWeekInfo: "-", tomorrowWeekInfo: "-", todayDateStr: "-", tomorrowDateStr: "-", todayCourseCount: 0, tomorrowCourseCount: 0)
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let firstMonday = df.date(from: String(response.week_1_monday.prefix(10))) ?? now
        
        // 计算周次
        func getWeek(for date: Date) -> Int {
            let diff = calendar.dateComponents([.day], from: firstMonday, to: date).day ?? 0
            return (diff / 7) + 1
        }
        
        let weekday = calendar.component(.weekday, from: now)
        let currentDay = (weekday == 1) ? 7 : (weekday - 1)
        
        func formatDate(_ date: Date, offset: Int) -> (String, Int) {
            let targetDate = calendar.date(byAdding: .day, value: offset, to: date)!
            let dayNames = ["", "一", "二", "三", "四", "五", "六", "日"]
            let dayIdx = (calendar.component(.weekday, from: targetDate) == 1) ? 7 : (calendar.component(.weekday, from: targetDate) - 1)
            df.dateFormat = "MM/dd"
            return ("\(df.string(from: targetDate)) 星期\(dayNames[dayIdx])", dayIdx)
        }

        let (todayStr, _) = formatDate(now, offset: 0)
        let (tomorrowStr, _) = formatDate(now, offset: 1)

        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        
        let todayCourses = response.instances.filter { $0.week == getWeek(for: now) && $0.day == currentDay && timeToMin($0.end_time) > nowMinutes }
        let tomorrowTargetDay = (currentDay == 7) ? 1 : currentDay + 1
        let tomorrowTargetWeek = (currentDay == 7) ? getWeek(for: now) + 1 : getWeek(for: now)
        let tomorrowCourses = response.instances.filter { $0.week == tomorrowTargetWeek && $0.day == tomorrowTargetDay }

        return CourseEntry(
            date: now,
            courses: todayCourses + tomorrowCourses,
            todayWeekInfo: "第 \(getWeek(for: now)) 周",
            tomorrowWeekInfo: "第 \(tomorrowTargetWeek) 周",
            todayDateStr: todayStr,
            tomorrowDateStr: tomorrowStr,
            todayCourseCount: todayCourses.count,
            tomorrowCourseCount: tomorrowCourses.count
        )
    }

    private func timeToMin(_ t: String) -> Int {
        let parts = t.split(separator: ":")
        return (Int(parts.first ?? "0") ?? 0) * 60 + (Int(parts.last ?? "0") ?? 0)
    }
}
