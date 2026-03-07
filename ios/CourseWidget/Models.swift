import Foundation

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
    
    // 辅助计算属性：将时间转换为当天的分钟数，方便排序和比较
    var startMin: Int {
        let parts = start_time.split(separator: ":")
        return (Int(parts.first ?? "0") ?? 0) * 60 + (Int(parts.last ?? "0") ?? 0)
    }
    var endMin: Int {
        let parts = end_time.split(separator: ":")
        return (Int(parts.first ?? "0") ?? 0) * 60 + (Int(parts.last ?? "0") ?? 0)
    }
}

struct ScheduleResponse: Codable {
    let week_1_monday: String
    let instances: [CourseInstance]
}