import SwiftUI

struct CurrentCourseView: View {
    @EnvironmentObject var viewModel: WatchScheduleViewModel
    @State private var showTopDetail = false
    @State private var showNextDetail = false

    var body: some View {
        let now = viewModel.now

        if let schedule = viewModel.schedule,
           let topCourse = SharedDataProvider.topCourse(from: schedule, at: now) {
            let status = SharedDataProvider.courseStatus(course: topCourse, at: now, response: schedule)
            let isOngoing = status == .ongoing
            let nextCourse = SharedDataProvider.courseAfter(topCourse, isOngoing: isOngoing, from: schedule, at: now)

            ScrollView {
                VStack(spacing: 8) {
                    // MARK: - 主面板：左倒计时 + 右课程信息
                    mainCourseCard(course: topCourse, isOngoing: isOngoing, schedule: schedule, now: now)
                        .onTapGesture { showTopDetail = true }
                        .sheet(isPresented: $showTopDetail) {
                            CourseDetailView(course: topCourse, status: status)
                        }

                    // MARK: - 下节课预览（可点击）
                    if let next = nextCourse {
                        let nextStatus = SharedDataProvider.courseStatus(course: next, at: now, response: schedule)
                        nextCourseCard(next: next)
                            .onTapGesture { showNextDetail = true }
                            .sheet(isPresented: $showNextDetail) {
                                CourseDetailView(course: next, status: nextStatus)
                            }
                    }
                }
                .padding(.horizontal, 2)
            }
        } else {
            emptyCourseView
        }
    }

    // MARK: - 主课程卡片（左右布局）

    @ViewBuilder
    private func mainCourseCard(course: WatchCourseInstance, isOngoing: Bool, schedule: WatchScheduleResponse, now: Date) -> some View {
        HStack(spacing: 10) {
            // 左侧：倒计时 / 进度环
            countdownSection(course: course, isOngoing: isOngoing, schedule: schedule, now: now)

            // 右侧：课程信息
            courseInfoSection(course: course, isOngoing: isOngoing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.13))
        )
    }

    // MARK: - 左侧倒计时

    @ViewBuilder
    private func countdownSection(course: WatchCourseInstance, isOngoing: Bool, schedule: WatchScheduleResponse, now: Date) -> some View {
        if isOngoing {
            // 正在上课：环形进度
            let progress = course.progress(at: now)
            let remaining = course.endMin - (Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now))

            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.green, .mint]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(max(remaining, 0))")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(.green)
                    Text("分钟")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 60, height: 60)
        } else {
            // 即将上课：倒计时数字
            if let target = SharedDataProvider.countdownTarget(for: course, isOngoing: false, at: now, response: schedule) {
                VStack(spacing: 2) {
                    Image(systemName: "clock.badge")
                        .font(.footnote)
                        .foregroundColor(.orange)

                    Text(target, style: .timer)
                        .font(.headline.bold().monospacedDigit())
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                }
                .frame(width: 60, height: 60)
            } else {
                Spacer()
                    .frame(width: 60, height: 60)
            }
        }
    }

    // MARK: - 右侧课程信息

    private func courseInfoSection(course: WatchCourseInstance, isOngoing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 状态标签
            HStack(spacing: 4) {
                Circle()
                    .fill(isOngoing ? Color.green : Color.orange)
                    .frame(width: 5, height: 5)
                Text(isOngoing ? "进行中" : "即将开始")
                    .font(.caption.weight(.medium))
                    .foregroundColor(isOngoing ? .green : .orange)
            }

            // 课程名称
            Text(course.course)
                .font(.headline)
                .lineLimit(2)

            // 地点
            HStack(spacing: 3) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Text(course.location)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }

            // 时间 (Timeline 风格)
            HStack(spacing: 6) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(isOngoing ? Color.green : Color.purple)
                        .frame(width: 4, height: 4)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 1, height: 10)
                    Circle()
                        .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                        .frame(width: 4, height: 4)
                }
                .padding(.vertical, 2)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(course.start_time)
                        .font(.caption2.monospacedDigit())
                    Text(course.end_time)
                        .font(.caption2.monospacedDigit())
                }
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 接下来课程卡片（可点击跳转详情）

    private func nextCourseCard(next: WatchCourseInstance) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("接下来")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cyan)
                    .frame(width: 3, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(next.course)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(next.start_time)
                            .font(.footnote.bold().monospacedDigit())
                            .foregroundColor(.cyan)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(next.location)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.11))
            )
        }
        .padding(.top, 2)
    }

    // MARK: - 空状态

    private var emptyCourseView: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("近期无课程")
                .font(.headline)

            Text("好好休息吧 🎉")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
