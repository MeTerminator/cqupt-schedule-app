import WidgetKit
import SwiftUI

// MARK: - 数据模型
struct CourseInstance: Codable, Identifiable {
    var id: String { "\(course)_\(week)_\(day)_\(start_time)" }
    let course: String
    let teacher: String?
    let week: Int
    let day: Int
    let start_time: String
    let end_time: String
    let location: String
    let type: String
}

struct ScheduleResponse: Codable {
    let week_1_monday: String
    let instances: [CourseInstance]
}

// MARK: - Entry
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

// MARK: - 数据提供者
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

// MARK: - UI 布局
struct CourseWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        // 根据组件大小分配可展示的最大行数
        let maxLines = (family == .systemLarge) ? 6 : 2
        
        // 1. 计算显示数量
        let todayLimit = min(entry.todayCourseCount, maxLines)
        let remainingSpace = maxLines - todayLimit
        let tomorrowLimit = min(entry.tomorrowCourseCount, remainingSpace)
        
        // 2. 计算未显示的课程数量
        let unshownCount = (entry.todayCourseCount - todayLimit) + (entry.tomorrowCourseCount - tomorrowLimit)

        // 使用顶部的对齐方式，并移除顶部的 Spacer
        VStack(alignment: .leading, spacing: 6) {
            // 头部：今日信息
            if entry.todayCourseCount > 0 {
                HeaderView(dateStr: entry.todayDateStr, count: entry.todayCourseCount, weekInfo: entry.todayWeekInfo)
                .padding(.vertical, 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                if entry.courses.isEmpty {
                    Text("近期无课程")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    // 显示今天课程
                    ForEach(Array(entry.courses.prefix(todayLimit))) { course in
                        CourseRow(course: course)
                        .padding(.vertical, 1)
                    }
                    
                    // 显示明天课程（如果有空间）
                    if remainingSpace > 0 && entry.tomorrowCourseCount > 0 {
                        // 明天课程的分割标题
                        HeaderView(dateStr: entry.tomorrowDateStr, count: entry.tomorrowCourseCount, weekInfo: entry.tomorrowWeekInfo)
                            .padding(.vertical, 2) // 增加一点间距区分日期
                        
                        ForEach(Array(entry.courses.dropFirst(entry.todayCourseCount).prefix(tomorrowLimit))) { course in
                            CourseRow(course: course)
                            .padding(.vertical, 1)
                        }
                    }
                    
                    // 底部居中提示文本
                    if unshownCount > 0 {
                        Text("还有 \(unshownCount) 节课未显示")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            
            // 这个最后的 Spacer 会将上方所有的内容“顶”到屏幕最上方
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10) // 微调上下边距，使顶部对齐看起来更自然
    }
}

struct HeaderView: View {
    let dateStr: String
    let count: Int
    let weekInfo: String
    
    var body: some View {
        HStack {
            Text("\(dateStr) · \(count) 节课")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            Text(weekInfo)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.blue)
        }
    }
}

struct CourseRow: View {
    let course: CourseInstance
    var body: some View {
        HStack(spacing: 8) {
            // 1. 左侧彩色条
            Capsule()
                .fill(colorFor(course.course))
                .frame(width: 4, height: 34)

            // 2. 课程与地点
            VStack(alignment: .leading, spacing: 1) {
                Text(course.course)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text(course.location)
                    .font(.system(size: 14))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 3. 时间
            VStack(alignment: .trailing, spacing: 0) {
                Text(course.start_time)
                    .font(.system(size: 13, weight: .medium))
                Text(course.end_time)
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func colorFor(_ name: String) -> Color {
        let colors: [Color] = [.orange, .blue, .green, .purple, .pink, .red, .cyan]
        return colors[abs(name.hashValue) % colors.count]
    }
}

struct CourseWidget: Widget {
    let kind: String = "CourseWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CourseWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("今日课程")
        .description("按照时间顺序显示今天和明天的课程。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
