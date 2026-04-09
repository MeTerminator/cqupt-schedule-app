import Foundation
import Combine

/// Watch 端课表数据 ViewModel
/// 响应式更新 —— 当 iPhone 同步新数据时自动刷新 UI
class WatchScheduleViewModel: ObservableObject {
    static let shared = WatchScheduleViewModel()

    /// 当前时间，每 30 秒自动刷新（让进度/倒计时保持准确）
    @Published var now: Date = Date()

    /// 课表数据，变更时自动触发 UI 刷新
    @Published var schedule: WatchScheduleResponse?

    private var timerCancellable: AnyCancellable?
    private var notificationObserver: Any?

    private init() {
        // 初始加载
        schedule = SharedDataProvider.loadSchedule()

        // 监听来自 WatchConnectivityDelegate 的数据更新通知
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .watchScheduleDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadData()
        }

        // 每 30 秒刷新一次时间（课程进度、倒计时精度足够）
        timerCancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.now = date
            }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// 重新从 UserDefaults 加载课表数据
    func reloadData() {
        let newSchedule = SharedDataProvider.loadSchedule()
        DispatchQueue.main.async {
            self.schedule = newSchedule
            self.now = Date()
        }
        print("[WatchVM] Schedule data reloaded, instances: \(newSchedule?.instances.count ?? 0)")
    }
}

// MARK: - 通知名

extension Notification.Name {
    /// WatchConnectivityDelegate 收到新数据后发送此通知
    static let watchScheduleDataDidUpdate = Notification.Name("watchScheduleDataDidUpdate")
}
