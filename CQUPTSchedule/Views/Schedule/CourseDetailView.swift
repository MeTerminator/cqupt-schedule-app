import SwiftUI

struct CourseDetailView: View {
    let course: CourseInstance
    let courseDate: String
    @Environment(\.presentationMode) var presentationMode
    // 引入 viewModel 以计算持续周数
    @ObservedObject var viewModel: ScheduleViewModel
    
    // 计算该课程的持续周数 (例如 1-16周)
    private var durationWeeks: String {
        // 获取所有课表中名称相同的实例
        let allInstances = (viewModel.scheduleData?.instances ?? []) + viewModel.customCourses.map { $0.toInstance() }
        let relatedCourses = allInstances.filter { $0.course == course.course }
        
        let weeks = relatedCourses.map { $0.week }
        if let minWeek = weeks.min(), let maxWeek = weeks.max() {
            return minWeek == maxWeek ? "第 \(minWeek) 周" : "\(minWeek) - \(maxWeek) 周"
        }
        return "第 \(course.week) 周"
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("基本信息")) {
                    DetailRow(label: "课程名称", value: course.course)
                    
                    // 核心修复：检查 teacher 是否赋值且不为空
                    if let teacher = course.teacher, !teacher.isEmpty, teacher != "无" {
                        DetailRow(label: "上课教师", value: teacher)
                    }
                    
                    DetailRow(label: "上课地点", value: course.location)
                    
                    // 新增：持续周数显示
                    DetailRow(label: "持续周数", value: durationWeeks)
                    
                    if let credit = course.credit, !credit.isEmpty {
                        DetailRow(label: "学分", value: "\(credit)")
                    }
                    
                    if let cType = course.courseType, !cType.isEmpty {
                        DetailRow(label: "课程性质", value: cType)
                    }
                }
                
                Section(header: Text("时间安排")) {
                    DetailRow(label: "上课日期", value: courseDate)
                    DetailRow(label: "当前周/星期", value: "第\(course.week)周 星期\(getChineseDay(course.day))")
                    DetailRow(label: "具体时间", value: "\(course.startTime) - \(course.endTime)")
                    DetailRow(label: "上课节数", value: course.periods.map{String($0)}.joined(separator: ", "))
                    DetailRow(label: "形式", value: course.type)
                }
                
                if let desc = course.description, !desc.isEmpty {
                    Section(header: Text("备注")) {
                        // 将字面量 "\n" 替换为真正的换行符
                        let formattedDesc = desc.replacingOccurrences(of: "\\n", with: "\n")
                        
                        Text(formattedDesc)
                            .font(.subheadline)
                            .lineSpacing(4)
                            .padding(.vertical, 4)
                            // 确保 Text 能够渲染多行
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .navigationTitle("课程详情")
            .navigationBarItems(trailing: Button("完成") { presentationMode.wrappedValue.dismiss() })
        }
    }
    
    private func getChineseDay(_ day: Int) -> String {
        let days = ["一", "二", "三", "四", "五", "六", "日"]
        return (day >= 1 && day <= 7) ? days[day - 1] : ""
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).bold()
                .multilineTextAlignment(.trailing) // 防止长文字重叠
        }
    }
}
