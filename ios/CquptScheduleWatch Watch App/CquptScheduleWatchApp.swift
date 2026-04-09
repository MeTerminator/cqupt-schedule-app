import SwiftUI
import WatchConnectivity

@main
struct CquptScheduleWatchApp: App {
    @StateObject private var viewModel = WatchScheduleViewModel.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 启动 WatchConnectivity 接收 iPhone 同步的数据
        WatchConnectivityDelegate.shared.startSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                print("[WatchApp] Scene became active, checking for updates...")
                // 1. 主动检查是否有尚未处理的 applicationContext
                let session = WCSession.default
                if session.activationState == .activated {
                    let context = session.receivedApplicationContext
                    if let jsonString = context["full_schedule_json"] as? String {
                        let prefs = UserDefaults(suiteName: WatchConnectivityDelegate.watchAppGroupId)
                        let localData = prefs?.string(forKey: WatchConnectivityDelegate.dataKey) ?? ""
                        // 只在数据有变化时更新
                        if jsonString != localData {
                            print("[WatchApp] Found newer applicationContext data, updating...")
                            prefs?.set(jsonString, forKey: WatchConnectivityDelegate.dataKey)
                            prefs?.synchronize()
                            WatchConnectivityDelegate.shared.lastSyncTime = Date()
                        }
                    }
                }
                // 2. 总是重新从 UserDefaults 加载（确保 UI 与本地数据一致）
                viewModel.reloadData()
            }
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
