import Foundation

// MARK: - API 数据模型（Watch App + Watch Widget 共享）

struct WatchCourseInstance: Codable, Identifiable {
    var id: String { "\(course)_\(week)_\(day)_\(start_time)" }
    let course: String
    let teacher: String?
    let week: Int
    let day: Int
    let start_time: String
    let end_time: String
    let location: String
    let type: String

    /// 开始时间转换为当天分钟数
    var startMin: Int {
        timeToMin(start_time)
    }

    /// 结束时间转换为当天分钟数
    var endMin: Int {
        timeToMin(end_time)
    }

    /// 课程时长（分钟）
    var durationMin: Int {
        endMin - startMin
    }

    /// 计算指定时刻的课程进度 (0.0 ~ 1.0)
    func progress(at date: Date) -> Double {
        let calendar = Calendar.current
        let nowMin = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let total = Double(endMin - startMin)
        if total <= 0 { return 1.0 }
        let passed = Double(nowMin - startMin)
        return max(0, min(1, passed / total))
    }

    /// 格式化的时间范围
    var timeRange: String {
        "\(start_time) - \(end_time)"
    }

    private func timeToMin(_ t: String) -> Int {
        let parts = t.split(separator: ":")
        return (Int(parts.first ?? "0") ?? 0) * 60 + (Int(parts.last ?? "0") ?? 0)
    }
}

struct WatchScheduleResponse: Codable {
    let week_1_monday: String
    let instances: [WatchCourseInstance]
}

// MARK: - 课程状态

enum WatchCourseStatus {
    case ongoing    // 正在上课
    case upcoming   // 即将上课
    case finished   // 已结束
}

// MARK: - 辅助扩展

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
