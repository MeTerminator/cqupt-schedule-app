import SwiftUI

@main
struct CquptScheduleWatchApp: App {
    init() {
        // 启动 WatchConnectivity 接收 iPhone 同步的数据
        WatchConnectivityDelegate.shared.startSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            CurrentCourseView()
            CourseListView()
        }
        .tabViewStyle(.verticalPage)
    }
}

