import SwiftUI


struct CourseBlock: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let course: CourseInstance
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let isExam = course.type.contains("考试")
        
        let backgroundColor: Color = {
            if isExam {
                return colorScheme == .dark ? .white : .black
            } else {
                // 使用优化过的排序索引颜色，避免刷新变色
                let colorIndex = viewModel.courseColorMap[course.course] ?? 0
                return Color.dynamicCourseColor(index: colorIndex)
            }
        }()

        let textColor: Color = isExam ? (colorScheme == .dark ? .black : .white) : .white

        VStack(spacing: 2) {
            Spacer(minLength: 1)
            Text(course.course)
                .font(.system(size: 14, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            
            Text(course.location)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .opacity(0.9)
            
            if course.type != "常规" {
                Image(systemName: isExam ? "pencil.and.outline" : "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(isExam ? .orange : .yellow)
            }
            Spacer(minLength: 1)
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .foregroundColor(textColor)
        .cornerRadius(6)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}