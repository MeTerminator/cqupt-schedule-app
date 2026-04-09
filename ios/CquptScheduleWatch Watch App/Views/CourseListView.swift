import SwiftUI

struct CourseListView: View {
    @EnvironmentObject var viewModel: WatchScheduleViewModel

    var body: some View {
        let now = viewModel.now

        NavigationStack {
            if let schedule = viewModel.schedule {
                let todayCourses = SharedDataProvider.todayAllCourses(from: schedule, at: now)
                let tomorrowCourses = SharedDataProvider.tomorrowAllCourses(from: schedule, at: now)

                let firstMonday = SharedDataProvider.parseFirstMonday(from: schedule)
                let currentWeek = firstMonday.map { SharedDataProvider.getWeek(for: now, firstMonday: $0) } ?? 0

                if todayCourses.isEmpty && tomorrowCourses.isEmpty {
                    emptyView
                } else {
                    List {
                        // MARK: - 今日课程
                        if !todayCourses.isEmpty {
                            Section {
                                ForEach(todayCourses) { course in
                                    CourseRowView(
                                        course: course,
                                        status: SharedDataProvider.courseStatus(course: course, at: now, response: schedule)
                                    )
                                    .listRowBackground(Color.clear)
                                }
                            } header: {
                                sectionHeader(
                                    title: "今天",
                                    dateStr: SharedDataProvider.formatDateInfo(for: now),
                                    count: todayCourses.count,
                                    week: currentWeek
                                )
                            }
                        }

                        // MARK: - 明日课程
                        if !tomorrowCourses.isEmpty {
                            Section {
                                ForEach(tomorrowCourses) { course in
                                    CourseRowView(
                                        course: course,
                                        status: .upcoming
                                    )
                                    .listRowBackground(Color.clear)
                                }
                            } header: {
                                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
                                let tomorrowWeek = firstMonday.map { SharedDataProvider.getWeek(for: tomorrow, firstMonday: $0) } ?? currentWeek
                                sectionHeader(
                                    title: "明天",
                                    dateStr: SharedDataProvider.formatDateInfo(for: tomorrow),
                                    count: tomorrowCourses.count,
                                    week: tomorrowWeek
                                )
                            }
                        }
                    }
                    .listStyle(.carousel)
                    .navigationTitle("课程表")
                    .navigationBarTitleDisplayMode(.inline)
                }
            } else {
                noDataView
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, dateStr: String, count: Int, week: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Text("第\(week)周")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
            }
            HStack {
                Text(dateStr)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(count)节课")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 2)
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 32))
                .foregroundColor(.yellow)
            Text("今日已无课程")
                .font(.system(size: 15, weight: .semibold))
            Text("享受自由时光 🎉")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noDataView: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 28))
                .foregroundColor(.gray)
            Text("暂无课表数据")
                .font(.system(size: 14, weight: .semibold))
            Text("请在 iPhone 上\n打开重邮课表同步数据")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
