import SwiftUI

struct CourseRowView: View {
    let course: WatchCourseInstance
    let status: WatchCourseStatus
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 8) {
                // 左侧状态 + 颜色条
                statusIndicator

                // 课程信息 (3行布局)
                VStack(alignment: .leading, spacing: 1) {
                    Text(course.course)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(statusTextColor)

                    Text(course.locationWithTeacher)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                    
                    Text("\(course.start_time) - \(course.end_time)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            CourseDetailView(course: course, status: status)
        }
    }

    // MARK: - 状态指示器

    private var statusIndicator: some View {
        VStack(spacing: 0) {
            switch status {
            case .ongoing:
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

// MARK: - 课程详情视图

struct CourseDetailView: View {
    let course: WatchCourseInstance
    let status: WatchCourseStatus

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 状态标签
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.footnote.weight(.medium))
                        .foregroundColor(statusColor)
                }
                .padding(.top, 4)

                // 课程名
                Text(course.course)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                Divider()

                // 详细信息
                VStack(spacing: 10) {
                    detailRow(icon: "clock.fill", color: .purple, label: "时间", value: course.timeRange)
                    detailRow(icon: "mappin.circle.fill", color: .blue, label: "地点", value: course.location)

                    if let teacher = course.teacher, !teacher.isEmpty {
                        detailRow(icon: "person.fill", color: .orange, label: "教师", value: teacher)
                    }

                    detailRow(icon: "tag.fill", color: .pink, label: "类型", value: course.type)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func detailRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundColor(color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.15))
        )
    }

    private var statusColor: Color {
        switch status {
        case .ongoing: return .green
        case .upcoming: return .orange
        case .finished: return .gray
        }
    }

    private var statusText: String {
        switch status {
        case .ongoing: return "进行中"
        case .upcoming: return "即将开始"
        case .finished: return "已结束"
        }
    }
}
