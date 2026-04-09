import SwiftUI

struct CourseRowView: View {
    let course: WatchCourseInstance
    let status: WatchCourseStatus

    var body: some View {
        HStack(spacing: 8) {
            // 左侧状态 + 颜色条
            statusIndicator

            // 课程信息
            VStack(alignment: .leading, spacing: 2) {
                Text(course.course)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                    .foregroundColor(statusTextColor)

                HStack(spacing: 3) {
                    Image(systemName: "mappin")
                        .font(.system(size: 9))
                    Text(course.location)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            // 右侧时间
            VStack(alignment: .trailing, spacing: 1) {
                Text(course.start_time)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                Text(course.end_time)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
    }

    // MARK: - 状态指示器

    private var statusIndicator: some View {
        VStack(spacing: 0) {
            switch status {
            case .ongoing:
                // 进行中：绿色脉冲点
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green)
                    .frame(width: 3, height: 20)
            case .upcoming:
                Circle()
                    .fill(Color.orange.opacity(0.6))
                    .frame(width: 6, height: 6)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.orange.opacity(0.4))
                    .frame(width: 3, height: 20)
            case .finished:
                Circle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 6, height: 6)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 3, height: 20)
            }
        }
    }

    private var statusTextColor: Color {
        switch status {
        case .ongoing: return .green
        case .upcoming: return .primary
        case .finished: return .secondary
        }
    }
}
