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
        courseInfoSection(course: course, isOngoing: isOngoing, schedule: schedule, now: now)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.13))
            )
    }

    // MARK: - 进行中小进度环

    @ViewBuilder
    private func ongoingSmallRingView(course: WatchCourseInstance, now: Date) -> some View {
        let progress = course.progress(at: now)

        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.green, .mint]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 22, height: 22)
    }

    @ViewBuilder
    private func countdownBadgeView(course: WatchCourseInstance, isOngoing: Bool, schedule: WatchScheduleResponse, now: Date) -> some View {
        if let target = SharedDataProvider.countdownTarget(for: course, isOngoing: isOngoing, at: now, response: schedule) {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let diff = Int(target.timeIntervalSince(context.date))
                let color: Color = isOngoing ? .green : .orange
                if diff > 0 {
                    let h = diff / 3600
                    let m = (diff % 3600) / 60
                    let s = diff % 60
                    
                    Text(String(format: "%02d:%02d:%02d", h, m, s))
                        .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(color)
                } else {
                    // 时间已到或即将开始
                    Text("00:00:00")
                        .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(color)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill((isOngoing ? Color.green : Color.orange).opacity(0.15))
            )
        }
    }

    // MARK: - 右侧课程信息

    private func courseInfoSection(course: WatchCourseInstance, isOngoing: Bool, schedule: WatchScheduleResponse, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 状态标签
            HStack(spacing: 4) {
                Circle()
                    .fill(isOngoing ? Color.green : Color.orange)
                    .frame(width: 5, height: 5)
                Text(isOngoing ? "进行中" : "即将开始")
                    .font(.caption.weight(.medium))
                    .foregroundColor(isOngoing ? .green : .orange)
                
                // 进行中和未开始都有倒计时徽章
                Spacer()
                countdownBadgeView(course: course, isOngoing: isOngoing, schedule: schedule, now: now)
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
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

                    // 时间 (统一水平格式)
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(isOngoing ? .green : .orange)
                        Text("\(course.start_time) - \(course.end_time)")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                
                if isOngoing {
                    Spacer()
                    ongoingSmallRingView(course: course, now: now)
                }
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
