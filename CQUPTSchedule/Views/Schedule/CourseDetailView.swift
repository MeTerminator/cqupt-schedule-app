import SwiftUI


struct CourseDetailView: View {
    let course: CourseInstance
    let courseDate: String  // 新增：用于接收计算好的具体日期
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("基本信息")) {
                    DetailRow(label: "课程名称", value: course.course)
                    DetailRow(label: "上课教师", value: course.teacher)
                    DetailRow(label: "上课地点", value: course.location)
                }
                Section(header: Text("时间安排")) {
                    // 添加这一行显示具体日期
                    DetailRow(label: "上课日期", value: courseDate)
                    
                    DetailRow(label: "周数/星期", value: "第\(course.week)周 星期\(getChineseDay(course.day))")
                    DetailRow(label: "具体时间", value: "\(course.startTime) - \(course.endTime)")
                    DetailRow(label: "上课节数", value: course.periods.map{String($0)}.joined(separator: ", "))
                    DetailRow(label: "课程类型", value: course.type)
                }
            }
            .navigationTitle("课程详情")
            .navigationBarItems(trailing: Button("关闭") { presentationMode.wrappedValue.dismiss() })
        }
    }
    
    // 辅助函数：数字转中文星期
    private func getChineseDay(_ day: Int) -> String {
        let days = ["一", "二", "三", "四", "五", "六", "日"]
        return (day >= 1 && day <= 7) ? days[day - 1] : ""
    }
}

struct DetailRow: View {
    let label: String; let value: String
    var body: some View { HStack { Text(label).foregroundColor(.secondary); Spacer(); Text(value).bold() } }
}
