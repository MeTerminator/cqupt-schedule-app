import Foundation
import WatchConnectivity
import WidgetKit

/// Watch 端 WatchConnectivity 委托
/// 接收 iPhone 端发送的课表数据，存入 Watch 本地 UserDefaults
class WatchConnectivityDelegate: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityDelegate()

    /// Watch 端本地存储的 App Group ID（Watch App 和 Watch Widget Extension 共享）
    static let watchAppGroupId = "group.top.met6.cquptscheduleios"
    static let dataKey = "full_schedule_json"

    var lastSyncTime: Date?

    private override init() {
        super.init()
    }

    // MARK: - 激活 Session

    func startSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("[WatchReceiver] Activation error: \(error.localizedDescription)")
            return
        }
        print("[WatchReceiver] Session activated: \(activationState.rawValue)")

        // 激活后立刻检查已收到的 applicationContext（可能在 App 未运行时发送的）
        let context = session.receivedApplicationContext
        if !context.isEmpty {
            print("[WatchReceiver] Found existing applicationContext, processing...")
            handleReceivedData(context)
        }
    }

    /// 接收 applicationContext（最新数据，App 未运行时也能收到）
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        print("[WatchReceiver] Received applicationContext")
        handleReceivedData(applicationContext)
    }

    /// 接收 transferUserInfo（保证到达的降级方案）
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        print("[WatchReceiver] Received userInfo")
        handleReceivedData(userInfo)
    }

    /// 接收实时 message（Watch App 在前台时的即时同步）
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("[WatchReceiver] Received message")
        handleReceivedData(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("[WatchReceiver] Received message with reply")
        handleReceivedData(message)
        replyHandler(["status": "ok"])
    }

    // MARK: - 数据处理

    private func handleReceivedData(_ data: [String: Any]) {
        guard let jsonString = data["full_schedule_json"] as? String else {
            print("[WatchReceiver] No schedule JSON in received data")
            return
        }

        // 存入 Watch 本地 UserDefaults (App Group，让 Watch Widget 也能读取)
        let prefs = UserDefaults(suiteName: Self.watchAppGroupId)
        prefs?.set(jsonString, forKey: Self.dataKey)
        prefs?.synchronize()

        self.lastSyncTime = Date()

        print("[WatchReceiver] Schedule data saved to Watch local storage (\(jsonString.count) bytes)")

        // 通知 SwiftUI ViewModel 数据已更新，触发 UI 刷新
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .watchScheduleDataDidUpdate, object: nil)
        }

        // 刷新 Watch Complications
        WidgetCenter.shared.reloadAllTimelines()
        print("[WatchReceiver] Widget timelines reloaded")
    }

    // MARK: - 调试：检查本地数据

    /// 检查 Watch 本地是否有课表数据
    func hasLocalData() -> Bool {
        let prefs = UserDefaults(suiteName: Self.watchAppGroupId)
        return prefs?.string(forKey: Self.dataKey) != nil
    }
}
