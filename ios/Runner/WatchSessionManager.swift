import Foundation
import WatchConnectivity

/// iPhone 端 WatchConnectivity 管理器
/// 负责将课表数据从 iPhone 发送到 Apple Watch
/// 自动监听 UserDefaults 变化，当 Flutter 写入新数据时自动同步
class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private let appGroupId = "group.top.met6.cquptscheduleios"
    private let dataKey = "full_schedule_json"
    private var lastSyncedHash: Int = 0

    private override init() {
        super.init()
    }

    // MARK: - 激活 Session

    func startSession() {
        guard WCSession.isSupported() else {
            print("[WatchSync] WCSession not supported on this device")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        print("[WatchSync] WCSession activating...")

        // 每 3 秒检查 UserDefaults 是否有变化
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkAndSync()
        }
    }

    // MARK: - 检查并同步

    private func checkAndSync() {
        let prefs = UserDefaults(suiteName: appGroupId)
        let currentData = prefs?.string(forKey: dataKey) ?? ""

        guard !currentData.isEmpty else { return }

        let currentHash = currentData.hashValue
        guard currentHash != lastSyncedHash else { return }

        lastSyncedHash = currentHash
        print("[WatchSync] UserDefaults data changed, syncing to Watch...")
        syncScheduleToWatch()
    }

    // MARK: - 发送数据到 Watch

    func syncScheduleToWatch() {
        guard WCSession.default.activationState == .activated else {
            print("[WatchSync] Session not activated, skipping sync")
            return
        }

        guard WCSession.default.isPaired else {
            print("[WatchSync] No paired Watch, skipping sync")
            return
        }

        guard WCSession.default.isWatchAppInstalled else {
            print("[WatchSync] Watch app not installed, skipping sync")
            return
        }

        let prefs = UserDefaults(suiteName: appGroupId)
        guard let jsonString = prefs?.string(forKey: dataKey) else {
            print("[WatchSync] No schedule data in UserDefaults")
            return
        }

        let payload: [String: Any] = [
            "full_schedule_json": jsonString,
            "timestamp": Date().timeIntervalSince1970
        ]

        // 1. 总是更新 applicationContext（Watch App 下次启动时能读到最新数据）
        do {
            try WCSession.default.updateApplicationContext(payload)
            print("[WatchSync] applicationContext updated")
        } catch {
            print("[WatchSync] applicationContext failed: \(error.localizedDescription)")
        }

        // 2. 如果 Watch App 当前可达，用 sendMessage 实时推送
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: { reply in
                print("[WatchSync] sendMessage succeeded, reply: \(reply)")
            }, errorHandler: { error in
                print("[WatchSync] sendMessage failed: \(error.localizedDescription)")
            })
        } else {
            print("[WatchSync] Watch not reachable, relying on applicationContext")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("[WatchSync] Activation failed: \(error.localizedDescription)")
            return
        }
        print("[WatchSync] Session activated: \(activationState.rawValue)")
        DispatchQueue.main.async {
            self.syncScheduleToWatch()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[WatchSync] Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("[WatchSync] Session deactivated, reactivating...")
        WCSession.default.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        print("[WatchSync] Watch state changed - paired: \(session.isPaired), installed: \(session.isWatchAppInstalled)")
        if session.isPaired && session.isWatchAppInstalled {
            syncScheduleToWatch()
        }
    }
}
