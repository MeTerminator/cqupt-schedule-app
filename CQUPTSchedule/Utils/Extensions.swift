import SwiftUI


extension Color {
    // 接受当前索引和总课程数来均分色环
    static func dynamicCourseColor(index: Int, total: Int) -> Color {
        guard total > 0 else { return .blue }
        
        // 使用质数步长跳跃选色，避免色环上相邻的颜色太像
        let step = 7
        let steppedIndex = (index * step) % total
        let hue = Double(steppedIndex) / Double(total)
        
        // 亮度 0.6 确保白色文字清晰
        return Color(hue: hue, saturation: 0.7, brightness: 0.6)
    }
    
    static func dynamicCourseColor(index: Int) -> Color {
        let goldenRatio = 0.618033988749895
        let hue = (Double(index) * goldenRatio).truncatingRemainder(dividingBy: 1.0)
        return Color(hue: hue, saturation: 0.65, brightness: 0.75)
    }
}

extension Date {
    func formatToSchedule() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy/M/d"; return f.string(from: self)
    }
}
