// 会话状态管理

import SwiftUI
import Combine

class SessionStore: ObservableObject {
    // 会话列表
    @Published var sessions: [Session] = []
    @Published var currentSessionId: String?

    // 消息存储
    @Published var messages: [String: [Message]] = [:]

    // 会话状态
    @Published var sessionStatuses: [String: SessionStatus] = [:]
    @Published var contextUsages: [String: Int] = [:]

    // 加载状态
    @Published var isLoading: Bool = false
    @Published var isCreating: Bool = false
    @Published var error: String?

    // 最近项目
    @Published var recentProjects: [RecentProject] = []

    // 当前会话
    var currentSession: Session? {
        guard let id = currentSessionId else { return nil }
        return sessions.first { $0.id == id }
    }

    // 按日期分组的会话
    var groupedSessions: [(title: String, sessions: [Session])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: today)!)
        let lastWeek = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: today)!)

        var groups: [(String, [Session])] = [
            ("今天", []),
            ("昨天", []),
            ("最近7天", []),
            ("更早", [])
        ]

        let sortedSessions = sessions.sorted { $0.modifiedAt > $1.modifiedAt }

        for session in sortedSessions {
            let sessionDay = calendar.startOfDay(for: session.modifiedAt)
            if sessionDay >= today {
                groups[0].1.append(session)
            } else if sessionDay >= yesterday {
                groups[1].1.append(session)
            } else if sessionDay >= lastWeek {
                groups[2].1.append(session)
            } else {
                groups[3].1.append(session)
            }
        }

        return groups.filter { !$0.1.isEmpty }
    }

    init() {
        // 加载保存的会话数据
        loadSavedData()
    }

    private func loadSavedData() {
        // 从 UserDefaults 或文件加载会话数据
        if let data = UserDefaults.standard.data(forKey: "sessions"),
           let saved = try? JSONDecoder().decode([Session].self, from: data) {
            self.sessions = saved
        } else {
            // 首次启动，加载示例数据
            loadMockData()
        }
    }

    private func loadMockData() {
        let calendar = Calendar.current
        let now = Date()

        // 今天的会话
        let today1 = Session(
            id: "session-1",
            title: "修复登录页面样式问题",
            projectPath: "~/projects/my-app",
            createdAt: calendar.date(byAdding: .hour, value: -2, to: now)!,
            modifiedAt: calendar.date(byAdding: .minute, value: -30, to: now)!,
            messageCount: 15
        )

        let today2 = Session(
            id: "session-2",
            title: "添加用户认证功能",
            projectPath: "~/projects/backend-api",
            createdAt: calendar.date(byAdding: .hour, value: -5, to: now)!,
            modifiedAt: calendar.date(byAdding: .hour, value: -1, to: now)!,
            messageCount: 28
        )

        // 昨天的会话
        let yesterday1 = Session(
            id: "session-3",
            title: "优化数据库查询性能",
            projectPath: "~/projects/data-service",
            createdAt: calendar.date(byAdding: .day, value: -1, to: now)!,
            modifiedAt: calendar.date(byAdding: .day, value: -1, to: now)!,
            messageCount: 42
        )

        let yesterday2 = Session(
            id: "session-4",
            title: "实现文件上传功能",
            projectPath: "~/projects/storage-module",
            createdAt: calendar.date(byAdding: .hour, value: -30, to: now)!,
            modifiedAt: calendar.date(byAdding: .hour, value: -28, to: now)!,
            messageCount: 19
        )

        // 前天的会话
        let dayBefore1 = Session(
            id: "session-5",
            title: "重构 API 响应处理",
            projectPath: "~/projects/api-gateway",
            createdAt: calendar.date(byAdding: .day, value: -2, to: now)!,
            modifiedAt: calendar.date(byAdding: .day, value: -2, to: now)!,
            messageCount: 33
        )

        let dayBefore2 = Session(
            id: "session-6",
            title: "添加单元测试覆盖",
            projectPath: "~/projects/core-lib",
            createdAt: calendar.date(byAdding: .hour, value: -60, to: now)!,
            modifiedAt: calendar.date(byAdding: .hour, value: -55, to: now)!,
            messageCount: 12
        )

        let dayBefore3 = Session(
            id: "session-7",
            title: "修复内存泄漏问题",
            projectPath: "~/projects/mobile-app",
            createdAt: calendar.date(byAdding: .hour, value: -58, to: now)!,
            modifiedAt: calendar.date(byAdding: .hour, value: -56, to: now)!,
            messageCount: 8
        )

        sessions = [today1, today2, yesterday1, yesterday2, dayBefore1, dayBefore2, dayBefore3]

        // 添加示例消息
        messages["session-1"] = [
            Message(id: "m1", type: .userText, content: "帮我修复登录页面的样式问题，按钮在深色模式下显示不正确", timestamp: Date()),
            Message(id: "m2", type: .assistantText, content: "我来帮你检查登录页面的样式问题。让我先看一下相关的代码文件。", timestamp: Date()),
            Message(id: "m3", type: .toolUse, content: "", timestamp: Date(), toolName: "Read", toolStatus: .completed),
            Message(id: "m4", type: .assistantText, content: "我发现了问题所在。在 `LoginView.swift` 中，按钮颜色使用了固定的浅色值，没有根据颜色模式动态调整。\n\n建议修改如下：\n\n```swift\nButton {\n    login()\n} label: {\n    Text(\"登录\")\n        .foregroundColor(.white)\n        .frame(maxWidth: .infinity)\n        .padding()\n        .background(Color.adaptivePrimary) // 使用动态颜色\n        .cornerRadius(12)\n}\n```\n\n这样按钮在深色模式下也会正确显示。", timestamp: Date()),
        ]

        messages["session-2"] = [
            Message(id: "m5", type: .userText, content: "我需要添加 JWT 认证功能，包括登录、注册和 token 刷新", timestamp: Date()),
            Message(id: "m6", type: .assistantText, content: "好的，我来帮你实现 JWT 认证系统。需要以下步骤：\n\n1. 安装必要的依赖\n2. 创建认证中间件\n3. 实现登录/注册接口\n4. 添加 token 刷新机制\n\n让我先检查一下项目的当前结构。", timestamp: Date()),
            Message(id: "m7", type: .toolUse, content: "", timestamp: Date(), toolName: "Glob", toolStatus: .completed),
        ]

        messages["session-3"] = [
            Message(id: "m8", type: .userText, content: "数据库查询太慢了，需要优化", timestamp: Date()),
            Message(id: "m9", type: .thinking, content: "分析当前查询结构，检查索引配置...", timestamp: Date()),
            Message(id: "m10", type: .assistantText, content: "我分析了你的查询，发现以下问题：\n\n1. `users` 表缺少 `email` 字段的索引\n2. 订单查询没有使用复合索引\n3. 存在 N+1 查询问题\n\n建议添加以下索引：\n\n```sql\nCREATE INDEX idx_users_email ON users(email);\nCREATE INDEX idx_orders_user_status ON orders(user_id, status);\n```", timestamp: Date()),
        ]

        // 添加状态和上下文使用率
        sessionStatuses["session-1"] = .completed
        sessionStatuses["session-2"] = .completed
        sessionStatuses["session-3"] = .completed
        sessionStatuses["session-4"] = .thinking  // 工作中

        contextUsages["session-1"] = 35
        contextUsages["session-2"] = 68
        contextUsages["session-3"] = 82
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "sessions")
        }
    }

    // MARK: - API 操作

    @MainActor
    func fetchSessions() async {
        isLoading = true
        error = nil

        do {
            // TODO: 调用 API 获取会话列表
            // let fetched = try await APIService.shared.getSessions()
            // sessions = fetched

            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    @MainActor
    func createSession(projectPath: String? = nil) async -> String? {
        isCreating = true

        do {
            // TODO: 调用 API 创建会话
            // let newSession = try await APIService.shared.createSession(projectPath: projectPath)
            // sessions.insert(newSession, at: 0)
            // saveSessions()
            // return newSession.id

            isCreating = false
            return nil
        } catch {
            self.error = error.localizedDescription
            isCreating = false
            return nil
        }
    }

    @MainActor
    func deleteSession(_ sessionId: String) async {
        do {
            // TODO: 调用 API 删除会话
            sessions.removeAll { $0.id == sessionId }
            messages.removeValue(forKey: sessionId)
            sessionStatuses.removeValue(forKey: sessionId)
            contextUsages.removeValue(forKey: sessionId)
            saveSessions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func fetchMessages(_ sessionId: String) async {
        do {
            // TODO: 调用 API 获取消息
            // let fetched = try await APIService.shared.getMessages(sessionId)
            // messages[sessionId] = fetched
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setCurrentSession(_ id: String?) {
        currentSessionId = id
    }

    func addMessage(_ sessionId: String, _ message: Message) {
        if messages[sessionId] == nil {
            messages[sessionId] = []
        }
        messages[sessionId]?.append(message)
    }

    func updateMessage(_ sessionId: String, _ messageId: String, updates: PartialMessage) {
        guard var sessionMessages = messages[sessionId],
              let index = sessionMessages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        var message = sessionMessages[index]

        if let content = updates.content {
            message = Message(
                id: message.id,
                type: message.type,
                content: content,
                timestamp: message.timestamp,
                toolName: message.toolName,
                toolInput: message.toolInput,
                toolResult: message.toolResult ?? updates.toolResult,
                toolStatus: message.toolStatus ?? updates.toolStatus,
                isStreaming: message.isStreaming
            )
        }

        if let toolResult = updates.toolResult {
            message = Message(
                id: message.id,
                type: message.type,
                content: message.content,
                timestamp: message.timestamp,
                toolName: message.toolName,
                toolInput: message.toolInput,
                toolResult: toolResult,
                toolStatus: message.toolStatus ?? updates.toolStatus,
                isStreaming: message.isStreaming
            )
        }

        if let toolStatus = updates.toolStatus {
            message = Message(
                id: message.id,
                type: message.type,
                content: message.content,
                timestamp: message.timestamp,
                toolName: message.toolName,
                toolInput: message.toolInput,
                toolResult: message.toolResult,
                toolStatus: toolStatus,
                isStreaming: message.isStreaming
            )
        }

        sessionMessages[index] = message
        messages[sessionId] = sessionMessages
    }

    func updateSessionStatus(_ sessionId: String, _ status: SessionStatus) {
        sessionStatuses[sessionId] = status
    }

    func updateSessionTitle(_ sessionId: String, _ title: String) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index] = Session(
                id: sessions[index].id,
                title: title,
                projectPath: sessions[index].projectPath,
                createdAt: sessions[index].createdAt,
                modifiedAt: Date(),
                messageCount: sessions[index].messageCount
            )
            saveSessions()
        }
    }

    func setContextUsage(_ sessionId: String, _ usage: Int) {
        contextUsages[sessionId] = usage
    }

    func fetchRecentProjects() async {
        // TODO: 调用 API 获取最近项目
    }
}

// 消息部分更新结构体
struct PartialMessage {
    var content: String?
    var toolResult: String?
    var toolStatus: ToolStatus?
}
