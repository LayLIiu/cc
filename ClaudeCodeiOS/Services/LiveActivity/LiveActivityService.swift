// 灵动岛管理服务 - 多会话聚合状态 + 实时活动内容

import ActivityKit
import Foundation
import QuartzCore

/// 灵动岛服务
class LiveActivityService {
    static let shared = LiveActivityService()

    private(set) var currentActivity: Activity<ClaudeActivityAttributes>?
    private var animationTimer: Timer?
    private var animationFrame: Int = 0
    private var tickCount: Int = 0

    /// 活跃会话状态追踪
    private var activeSessions: [String: SessionWorkState] = [:]

    /// 当前显示的会话 ID（用于轮换）
    private var currentDisplaySessionId: String?

    /// 待更新的内容
    private var pendingUpdateWorkItem: DispatchWorkItem?

    /// 最近完成的会话
    private var recentlyCompletedSession: String?
    private var completionDisplayTime: Date?

    /// 上次更新时间（用于限流）
    private var lastUpdateTime: Date?
    /// 最小更新间隔（秒）
    private let minUpdateInterval: TimeInterval = 0.25

    var currentStatus: ClaudeWorkStatus? {
        return currentActivity?.content.state.status
    }

    private init() {}

    // MARK: - 辅助方法

    /// 清理文本：移除换行符，限制长度
    private func cleanText(_ text: String, maxLength: Int = 60) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > maxLength {
            return String(cleaned.prefix(maxLength)) + "..."
        }
        return cleaned
    }

    // MARK: - 会话状态管理

    func sessionStartedWorking(sessionId: String, sessionTitle: String) {
        activeSessions[sessionId] = SessionWorkState(
            title: cleanText(sessionTitle, maxLength: 30),
            status: .working,
            startTime: Date()
        )
        // 如果没有当前显示的会话，设置为这个
        if currentDisplaySessionId == nil {
            currentDisplaySessionId = sessionId
        }
        scheduleThrottledUpdate()
    }

    func sessionCompleted(sessionId: String, lastMessage: String) {
        if var session = activeSessions[sessionId] {
            session.status = .completed
            session.completionTime = Date()
            session.content = lastMessage.isEmpty ? "已完成" : cleanText(lastMessage)
            session.activityType = .completed
            activeSessions[sessionId] = session
        }

        recentlyCompletedSession = sessionId
        completionDisplayTime = Date()
        scheduleThrottledUpdate()
    }

    func sessionBecameIdle(sessionId: String) {
        activeSessions.removeValue(forKey: sessionId)

        // 如果当前显示的是这个会话，切换到另一个
        if currentDisplaySessionId == sessionId {
            currentDisplaySessionId = activeSessions.keys.first
        }

        if recentlyCompletedSession == sessionId {
            recentlyCompletedSession = nil
            completionDisplayTime = nil
        }

        if activeSessions.isEmpty {
            stopActivity()
        } else {
            scheduleThrottledUpdate()
        }
    }

    func clearAllSessions() {
        activeSessions.removeAll()
        currentDisplaySessionId = nil
        recentlyCompletedSession = nil
        completionDisplayTime = nil
        stopActivity()
    }


    // MARK: - 启动灵动岛（应用启动时调用）

    func startActivityIfIdle() {
        if currentActivity == nil {
            performUpdate()
        }
    }
    // MARK: - 实时活动内容更新

    func updateThinkingContent(_ content: String, sessionId: String) {
        guard var session = activeSessions[sessionId] else { return }
        session.content = cleanText(content)
        session.activityType = .thinking
        session.toolName = ""
        activeSessions[sessionId] = session
        // 更新当前显示为这个会话
        currentDisplaySessionId = sessionId
        scheduleThrottledUpdate()
    }

    func updateToolUse(toolName: String, toolInput: String?, sessionId: String) {
        guard var session = activeSessions[sessionId] else { return }
        session.toolName = toolName
        session.content = toolInput.map { cleanText($0) } ?? ""
        session.activityType = .toolUse
        activeSessions[sessionId] = session
        // 更新当前显示为这个会话
        currentDisplaySessionId = sessionId
        scheduleThrottledUpdate()
    }

    func updateStreamingContent(_ content: String, sessionId: String) {
        guard var session = activeSessions[sessionId] else { return }
        session.content = cleanText(content)
        session.activityType = .streaming
        session.toolName = ""
        activeSessions[sessionId] = session
        // 更新当前显示为这个会话
        currentDisplaySessionId = sessionId
        scheduleThrottledUpdate()
    }

    // MARK: - 节流更新

    private func scheduleThrottledUpdate() {
        pendingUpdateWorkItem?.cancel()

        // 检查是否需要立即更新还是延迟
        let now = Date()
        if let lastUpdate = lastUpdateTime {
            let elapsed = now.timeIntervalSince(lastUpdate)
            if elapsed < minUpdateInterval {
                // 延迟更新
                let delay = minUpdateInterval - elapsed
                let workItem = DispatchWorkItem { [weak self] in
                    self?.performUpdate()
                }
                pendingUpdateWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
                return
            }
        }

        // 立即更新
        performUpdate()
    }

    private func performUpdate() {
        lastUpdateTime = Date()

        let workingCount = activeSessions.values.filter { $0.status == .working }.count
        let totalCount = activeSessions.count

        let displayStatus: ClaudeWorkStatus
        let displayText: String

        if let completionTime = completionDisplayTime,
           Date().timeIntervalSince(completionTime) < 1.0,
           workingCount > 0 {
            displayStatus = .completed
            displayText = "任务完成"
        } else if workingCount == 0 && totalCount == 0 {
            displayStatus = .idle
            displayText = "空闲中"

        } else if workingCount == 0 && totalCount > 0 {
            displayStatus = .completed
            displayText = "全部完成"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.clearAllSessions()
            }
        } else {
            displayStatus = .working
            displayText = "工作中"
        }

        if let completionTime = completionDisplayTime,
           Date().timeIntervalSince(completionTime) >= 1.0 {
            recentlyCompletedSession = nil
            completionDisplayTime = nil
        }

        // 获取当前显示的会话
        let currentSession: SessionWorkState?
        if let sid = currentDisplaySessionId, let session = activeSessions[sid] {
            currentSession = session
        } else {
            // 没有指定会话，取第一个工作中的
            currentSession = activeSessions.values.first { $0.status == .working }
                ?? activeSessions.values.first
        }

        let sessionTitle = currentSession?.title ?? "Claude Code"
        let toolName = currentSession?.toolName ?? ""
        let activityContent = currentSession?.content ?? ""
        let activityType = currentSession?.activityType ?? .idle

        if currentActivity == nil {
            startNewActivity(
                sessionTitle: sessionTitle,
                status: displayStatus,
                statusText: displayText,
                toolName: toolName,
                activityContent: activityContent,
                activityType: activityType,
                activeSessions: workingCount,
                totalSessions: totalCount
            )
        } else {
            updateActivity(
                status: displayStatus,
                statusText: displayText,
                sessionTitle: sessionTitle,
                toolName: toolName,
                activityContent: activityContent,
                activityType: activityType,
                activeSessions: workingCount,
                totalSessions: totalCount
            )
        }
    }

    // MARK: - 灵动岛更新

    private func startNewActivity(
        sessionTitle: String,
        status: ClaudeWorkStatus,
        statusText: String,
        toolName: String,
        activityContent: String,
        activityType: ActivityType,
        activeSessions: Int,
        totalSessions: Int
    ) {
        let attributes = ClaudeActivityAttributes(
            sessionId: "aggregated",
            mascotColorHex: "E86B4A"
        )

        let initialState = ClaudeActivityAttributes.ContentState(
            status: status,
            statusText: statusText,
            toolName: toolName,
            activityContent: activityContent,
            activityType: activityType,
            sessionTitle: sessionTitle,
            elapsedSeconds: 0,
            activeSessions: activeSessions,
            totalSessions: totalSessions,
            animationTimestamp: CACurrentMediaTime(),
            sessionSummaries: []
        )

        do {
            let activity = try Activity<ClaudeActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            startAnimationTimer()
            print("[LiveActivity] ✅ Started: \(sessionTitle) - \(toolName) \(activityContent)")
        } catch {
            print("[LiveActivity] ❌ Failed to start: \(error)")
        }
    }

    private func updateActivity(
        status: ClaudeWorkStatus,
        statusText: String,
        sessionTitle: String,
        toolName: String,
        activityContent: String,
        activityType: ActivityType,
        activeSessions: Int,
        totalSessions: Int
    ) {
        guard let activity = currentActivity else { return }

        let state = ClaudeActivityAttributes.ContentState(
            status: status,
            statusText: statusText,
            toolName: toolName,
            activityContent: activityContent,
            activityType: activityType,
            sessionTitle: sessionTitle,
            elapsedSeconds: animationFrame,
            activeSessions: activeSessions,
            totalSessions: totalSessions,
            animationTimestamp: CACurrentMediaTime(),
            sessionSummaries: []
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    // MARK: - 动画定时器

    private func startAnimationTimer() {
        animationFrame = 0
        DispatchQueue.main.async { [weak self] in
            self?.animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.tickAnimation()
            }
        }
    }

    private func stopAnimationTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.animationTimer?.invalidate()
            self?.animationTimer = nil
        }
    }
    private func tickAnimation() {
        guard currentActivity != nil else { return }
        animationFrame += 1
        tickCount += 1

        // 每 5 次 tick（0.5 秒）触发一次更新，保持灵动岛内容持续刷新
        if tickCount >= 5 {
            tickCount = 0
            performUpdate()
        }

        if let completionTime = completionDisplayTime,
           Date().timeIntervalSince(completionTime) >= 1.0 {
            recentlyCompletedSession = nil
            completionDisplayTime = nil
            performUpdate()
        }
    }

    func stopActivity() {
        stopAnimationTimer()
        Task {
            if let activity = currentActivity {
                await activity.end(nil, dismissalPolicy: .default)
            }
            currentActivity = nil
        }
    }
}

// MARK: - 会话工作状态

struct SessionWorkState {
    let title: String
    var status: WorkStatus
    let startTime: Date
    var completionTime: Date?
    var content: String = ""
    var toolName: String = ""
    var activityType: ActivityType = .idle

    enum WorkStatus {
        case working
        case completed
    }
}

// MARK: - SessionStatus 扩展

extension SessionStatus {
    var isWorking: Bool {
        switch self {
        case .thinking, .streaming, .toolExecuting, .permissionPending, .questionPending:
            return true
        case .idle, .completed:
            return false
        }
    }
}
