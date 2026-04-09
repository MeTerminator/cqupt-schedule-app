import SwiftUI

struct CurrentCourseView: View {
    let now = Date()

    var body: some View {
        let schedule = SharedDataProvider.loadSchedule()

        if let schedule = schedule,
           let topCourse = SharedDataProvider.topCourse(from: schedule, at: now) {
            let status = SharedDataProvider.courseStatus(course: topCourse, at: now, response: schedule)
            let isOngoing = status == .ongoing

            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - 进度环 / 倒计时
                    headerSection(course: topCourse, isOngoing: isOngoing, schedule: schedule)
                        .padding(.bottom, 8)

                    // MARK: - 课程信息
                    courseInfoSection(course: topCourse, isOngoing: isOngoing)

                    // MARK: - 下节课预览
                    nextCoursePreview(schedule: schedule)
                }
                .padding(.horizontal, 4)
            }
        } else {
            emptyCourseView
        }
    }

    // MARK: - 进度环区域

    @ViewBuilder
    private func headerSection(course: WatchCourseInstance, isOngoing: Bool, schedule: WatchScheduleResponse) -> some View {
        if isOngoing {
            // 正在上课：显示环形进度
            let progress = course.progress(at: now)
            let remaining = course.endMin - (Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now))

            ZStack {
                // 背景环
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 6)

                // 进度环
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.green, .mint]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("剩余")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(max(remaining, 0))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("分钟")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)
        } else {
            // 即将上课：显示倒计时
            if let target = SharedDataProvider.countdownTarget(for: course, isOngoing: false, at: now, response: schedule) {
                VStack(spacing: 4) {
                    Text("距离上课")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(target, style: .timer)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - 课程信息区域

    private func courseInfoSection(course: WatchCourseInstance, isOngoing: Bool) -> some View {
        VStack(spacing: 6) {
            // 状态标签
            HStack(spacing: 4) {
                Circle()
                    .fill(isOngoing ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(isOngoing ? "进行中" : "即将开始")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isOngoing ? .green : .orange)
            }

            // 课程名称
            Text(course.course)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // 地点
            HStack(spacing: 3) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                Text(course.location)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }

            // 时间
            HStack(spacing: 3) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.purple)
                Text(course.timeRange)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.15))
        )
    }

    // MARK: - 下节课预览

    @ViewBuilder
    private func nextCoursePreview(schedule: WatchScheduleResponse) -> some View {
        let nextCourse: WatchCourseInstance? = {
            let calendar = Calendar.current
            let nowMin = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
            let remaining = SharedDataProvider.todayRemainingCourses(from: schedule, at: now)
            // 跳过正在上的或第一个（topCourse），找下一个
            let upcoming = remaining.filter { $0.startMin > nowMin }
            return upcoming.count > 1 ? upcoming[1] : upcoming.first
        }()

        if let next = nextCourse {
            VStack(spacing: 4) {
                HStack {
                    Text("接下来")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.cyan)
                        .frame(width: 3, height: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(next.course)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text("\(next.start_time) · \(next.location)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.12))
                )
            }
            .padding(.top, 8)
        }
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
                .font(.system(size: 16, weight: .semibold))

            Text("好好休息吧 🎉")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
