// 灵动岛管理服务

import ActivityKit
import Foundation

/// 灵动岛服务
class LiveActivityService {
    static let shared = LiveActivityService()

    private(set) var currentActivity: Activity<ClaudeActivityAttributes>?
    private var updateTimer: Timer?
    private var elapsedSeconds: Int = 0
    private var currentSessionTitle: String = ""
    private var completedTasks: Int = 0
    private var totalTasks: Int = 1

    /// 同步获取当前状态（用于判断是否需要重启）
    var currentStatus: ClaudeWorkStatus? {
        return currentActivity?.content.state.status
    }

    private init() {}

    // MARK: - 公开方法

    /// 开始工作状态灵动岛
    func startActivity(
        sessionId: String,
        sessionTitle: String,
        mascotColorHex: String = "E86B4A",
        totalTasks: Int = 1,
        initialStatus: ClaudeWorkStatus = .working,
        initialStatusText: String? = nil
    ) {
        let authInfo = ActivityAuthorizationInfo()
        print("[LiveActivity] 📱 Authorization check:")
        print("[LiveActivity]   - areActivitiesEnabled: \(authInfo.areActivitiesEnabled)")

        guard authInfo.areActivitiesEnabled else {
            print("[LiveActivity] ❌ Live Activities not enabled!")
            return
        }

        // 同步停止旧活动
        stopTimer()
        if let oldActivity = currentActivity {
            Task {
                await oldActivity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil

        // 重置所有状态
        currentSessionTitle = sessionTitle
        self.totalTasks = totalTasks
        self.completedTasks = 0
        elapsedSeconds = 0

        let attributes = ClaudeActivityAttributes(
            sessionId: sessionId,
            mascotColorHex: mascotColorHex
        )

        let statusText = initialStatusText ?? initialStatus.displayText
        let initialState = ClaudeActivityAttributes.ContentState(
            status: initialStatus,
            statusText: statusText,
            lastMessage: "",
            sessionTitle: sessionTitle,
            elapsedSeconds: 0,
            completedTasks: 0,
            totalTasks: totalTasks
        )

        do {
            let activity = try Activity<ClaudeActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            startTimer()
            print("[LiveActivity] ✅ Started for: \(sessionTitle), status: \(initialStatus.rawValue)")
        } catch {
            print("[LiveActivity] ❌ Failed: \(error)")
        }
    }

    /// 更新工作状态
    func updateStatus(
        status: ClaudeWorkStatus,
        statusText: String? = nil,
        lastMessage: String? = nil
    ) {
        guard let activity = currentActivity else { return }

        let state = ClaudeActivityAttributes.ContentState(
            status: status,
            statusText: statusText ?? status.displayText,
            lastMessage: lastMessage ?? "",
            sessionTitle: currentSessionTitle,
            elapsedSeconds: elapsedSeconds,
            completedTasks: completedTasks,
            totalTasks: totalTasks
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
            print("[LiveActivity] 📝 Updated status to: \(status.rawValue), elapsed: \(self.elapsedSeconds)")
        }
    }

    /// 更新任务进度
    func updateTaskProgress(completed: Int, total: Int) {
        self.completedTasks = completed
        self.totalTasks = total

        guard let activity = currentActivity else { return }

        let state = ClaudeActivityAttributes.ContentState(
            status: activity.content.state.status,
            statusText: activity.content.state.statusText,
            lastMessage: activity.content.state.lastMessage,
            sessionTitle: currentSessionTitle,
            elapsedSeconds: elapsedSeconds,
            completedTasks: completed,
            totalTasks: total
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// 完成工作
    func completeWork(lastMessage: String) {
        completedTasks += 1

        updateStatus(
            status: .completed,
            statusText: "已完成",
            lastMessage: lastMessage
        )

        stopTimer()
        print("[LiveActivity] ✅ Work completed")
    }

    /// 停止灵动岛
    func stopActivity() {
        stopTimer()

        Task {
            if let activity = currentActivity {
                await activity.end(nil, dismissalPolicy: .default)
            }
            currentActivity = nil
            print("[LiveActivity] Stopped")
        }
    }

    // MARK: - 私有方法

    private func startTimer() {
        // 确保在主线程运行
        DispatchQueue.main.async { [weak self] in
            self?.updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.elapsedSeconds += 1
                self?.updateElapsed()
            }
            print("[LiveActivity] ⏰ Timer started")
        }
    }

    private func stopTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.updateTimer?.invalidate()
            self?.updateTimer = nil
            print("[LiveActivity] ⏰ Timer stopped")
        }
    }

    private func updateElapsed() {
        guard let activity = currentActivity else { return }

        print("[LiveActivity] 🔄 Tick: \(elapsedSeconds)")

        let state = ClaudeActivityAttributes.ContentState(
            status: activity.content.state.status,
            statusText: activity.content.state.statusText,
            lastMessage: activity.content.state.lastMessage,
            sessionTitle: currentSessionTitle,
            elapsedSeconds: elapsedSeconds,
            completedTasks: completedTasks,
            totalTasks: totalTasks
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }
}

// MARK: - SessionStatus 扩展

extension SessionStatus {
    var liveActivityStatus: ClaudeWorkStatus {
        switch self {
        case .idle, .completed:
            return .idle
        case .thinking, .streaming, .toolExecuting, .permissionPending, .questionPending:
            return .working
        }
    }
}
