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

    // WebSocket 服务
    private var webSocketService = WebSocketService.shared
    private var cancellables = Set<AnyCancellable>()

    // 本地存储目录
    private let messagesDirectory: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let messagesDir = paths[0].appendingPathComponent("messages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: messagesDir.path) {
            try? FileManager.default.createDirectory(at: messagesDir, withIntermediateDirectories: true)
        }
        return messagesDir
    }()

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

        // 解析时间戳并排序
        let sortedSessions = sessions.sorted { s1, s2 in
            let date1 = parseTimestamp(s1.modifiedAt)
            let date2 = parseTimestamp(s2.modifiedAt)
            return date1 > date2
        }

        for session in sortedSessions {
            let sessionDate = parseTimestamp(session.modifiedAt)
            let sessionDay = calendar.startOfDay(for: sessionDate)
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

    private func parseTimestamp(_ timestamp: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: timestamp) ?? Date.distantPast
    }

    init() {
        // 加载保存的会话数据
        loadSavedData()

        // 监听 WebSocket 消息 - 实时推送到对应会话
        webSocketService.$lastMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let message = message else { return }
                self?.handleWebSocketMessage(message)
            }
            .store(in: &cancellables)
    }

    private func loadSavedData() {
        // 从 UserDefaults 加载会话数据
        if let data = UserDefaults.standard.data(forKey: "sessions"),
           let saved = try? JSONDecoder().decode([Session].self, from: data) {
            self.sessions = saved

            // 预加载所有会话的本地消息到内存
            for session in saved {
                if let localMessages = loadMessagesFromLocal(session.id) {
                    messages[session.id] = localMessages
                }
            }
            print("[SessionStore] ✅ Preloaded messages for \(saved.count) sessions")
        }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "sessions")
        }
    }

    // MARK: - 本地消息存储

    private func messagesFilePath(for sessionId: String) -> URL {
        return messagesDirectory.appendingPathComponent("\(sessionId).json")
    }

    func saveMessagesToLocal(_ sessionId: String) {
        guard let sessionMessages = messages[sessionId], !sessionMessages.isEmpty else { return }
        let url = messagesFilePath(for: sessionId)
        if let data = try? JSONEncoder().encode(sessionMessages) {
            try? data.write(to: url)
            print("[SessionStore] Saved \(sessionMessages.count) messages to local for session \(sessionId)")
        }
    }

    func loadMessagesFromLocal(_ sessionId: String) -> [Message]? {
        let url = messagesFilePath(for: sessionId)
        guard let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode([Message].self, from: data) else {
            return nil
        }
        print("[SessionStore] Loaded \(saved.count) messages from local for session \(sessionId)")
        return saved
    }

    // MARK: - WebSocket 消息处理 - 实时推送到对应会话

    private func handleWebSocketMessage(_ wsMessage: WSMessage) {
        // 使用消息中的 sessionId，如果没有则使用当前会话
        let targetSessionId = wsMessage.sessionId ?? currentSessionId

        print("[SessionStore] 📩 WS msg: \(wsMessage.type), sessionId in msg: \(wsMessage.sessionId ?? "nil"), currentSessionId: \(currentSessionId ?? "nil"), target: \(targetSessionId ?? "nil")")

        guard let sessionId = targetSessionId else {
            print("[SessionStore] ⚠️ No session ID for message, skipping")
            return
        }

        switch wsMessage.type {
        case .contentStart:
            print("[SessionStore] ▶️ Content start, blockType: \(wsMessage.blockType ?? "nil")")
            // 如果是助手消息开始，先清理流式状态
            if wsMessage.blockType == "text" || wsMessage.blockType == nil {
                sessionStatuses[sessionId] = .streaming
            }

        case .contentDelta:
            if let text = wsMessage.text {
                print("[SessionStore] 📝 Content delta: \(text.prefix(30))...")
                appendStreamingText(sessionId, text)
            }

        case .thinking:
            if let text = wsMessage.text {
                print("[SessionStore] 🧠 Thinking: \(text.prefix(30))...")
                updateThinkingContent(sessionId, text)
            }

        case .toolUseComplete:
            if let toolName = wsMessage.toolName {
                print("[SessionStore] 🔧 Tool complete: \(toolName)")
                addToolUseMessage(sessionId, toolName, wsMessage.toolUseId, wsMessage.input, .completed)
            }

        case .toolResult:
            if let toolUseId = wsMessage.toolUseId,
               let content = wsMessage.content {
                print("[SessionStore] 🔧 Tool result for: \(toolUseId)")
                updateToolResult(sessionId, toolUseId, content)
            }

        case .messageComplete:
            print("[SessionStore] ✅ Message complete for session \(sessionId)")
            sessionStatuses[sessionId] = .completed
            // 消息完成时保存到本地
            saveMessagesToLocal(sessionId)

        case .status:
            if let state = wsMessage.state {
                print("[SessionStore] 📊 Status: \(state) for session \(sessionId)")
                updateSessionStatusFromState(sessionId, state)
            }

        case .permissionRequest:
            if let requestId = wsMessage.requestId {
                print("[SessionStore] 🔐 Permission request: \(wsMessage.toolName ?? "unknown")")
                addPermissionRequestMessage(sessionId, requestId, wsMessage.toolName ?? "", wsMessage.description)
            }

        case .question:
            if let questionId = wsMessage.questionId {
                print("[SessionStore] ❓ Question: \(wsMessage.questionText ?? "")")
                addQuestionMessage(sessionId, questionId, wsMessage.questionText ?? "", wsMessage.options ?? [])
            }

        case .error:
            if let text = wsMessage.text {
                print("[SessionStore] ❌ Error: \(text)")
                self.error = text
            }

        case .tokenUsage:
            if let percentage = wsMessage.percentage {
                contextUsages[sessionId] = Int(percentage * 100)
            }

        case .sessionTitleUpdated:
            if let title = wsMessage.title {
                updateSessionTitle(sessionId, title)
            }

        case .connected:
            print("[SessionStore] 🔗 WebSocket connected")

        case .userMessageEcho:
            // 用户消息回显 - 添加到对应会话
            if let contentValue = wsMessage.content?.value {
                let contentString: String
                if let str = contentValue as? String {
                    contentString = str
                } else {
                    contentString = String(describing: contentValue)
                }
                print("[SessionStore] 👤 User message echo: \(contentString.prefix(50))")
                let userMessage = Message(
                    id: wsMessage.id ?? "user-\(UUID().uuidString)",
                    type: .userText,
                    content: contentString,
                    timestamp: wsMessage.timestamp ?? ISO8601DateFormatter().string(from: Date())
                )
                addMessage(sessionId, userMessage)
                saveMessagesToLocal(sessionId)
            }
        }
    }

    private func appendStreamingText(_ sessionId: String, _ text: String) {
        var sessionMessages = messages[sessionId] ?? []

        // 查找最后一条助手消息
        if let lastIndex = sessionMessages.indices.last,
           sessionMessages[lastIndex].type == .assistantText {

            let msg = sessionMessages[lastIndex]
            let updatedMsg = Message(
                id: msg.id,
                type: msg.type,
                content: msg.content + text,
                timestamp: msg.timestamp,
                toolName: msg.toolName,
                toolInput: msg.toolInput,
                toolResult: msg.toolResult,
                toolStatus: msg.toolStatus
            )
            sessionMessages[lastIndex] = updatedMsg
        } else {
            // 创建新的助手消息
            let newMessage = Message(
                id: "assistant-\(UUID().uuidString)",
                type: .assistantText,
                content: text,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            sessionMessages.append(newMessage)
        }

        // 强制触发 UI 更新
        messages[sessionId] = sessionMessages
    }

    private func updateThinkingContent(_ sessionId: String, _ text: String) {
        var sessionMessages = messages[sessionId] ?? []

        // 查找最后一条思考消息
        if let lastIndex = sessionMessages.indices.last,
           sessionMessages[lastIndex].type == .thinking {

            let msg = sessionMessages[lastIndex]
            let updatedMsg = Message(
                id: msg.id,
                type: msg.type,
                content: msg.content + text,
                timestamp: msg.timestamp,
                toolName: msg.toolName,
                toolInput: msg.toolInput,
                toolResult: msg.toolResult,
                toolStatus: msg.toolStatus
            )
            sessionMessages[lastIndex] = updatedMsg
        } else {
            // 创建新的思考消息
            let newMessage = Message(
                id: "thinking-\(UUID().uuidString)",
                type: .thinking,
                content: text,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            sessionMessages.append(newMessage)
        }

        // 强制触发 UI 更新
        messages[sessionId] = sessionMessages
    }

    private func addToolUseMessage(_ sessionId: String, _ toolName: String, _ toolUseId: String?, _ input: [String: AnyCodable]?, _ status: ToolStatus) {
        let message = Message(
            id: toolUseId ?? UUID().uuidString,
            type: .toolUse,
            content: "",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            toolName: toolName,
            toolInput: input,
            toolResult: nil,
            toolStatus: status
        )

        var sessionMessages = messages[sessionId] ?? []
        sessionMessages.append(message)
        messages[sessionId] = sessionMessages
    }

    private func updateToolResult(_ sessionId: String, _ toolUseId: String, _ content: AnyCodable) {
        var sessionMessages = messages[sessionId] ?? []
        guard let index = sessionMessages.firstIndex(where: { $0.id == toolUseId }) else { return }

        let msg = sessionMessages[index]
        let resultString: String
        if let str = content.value as? String {
            resultString = str
        } else if let data = try? JSONEncoder().encode(AnyCodable(value: content.value)),
                  let str = String(data: data, encoding: .utf8) {
            resultString = str
        } else {
            resultString = String(describing: content.value)
        }

        let updatedMsg = Message(
            id: msg.id,
            type: msg.type,
            content: msg.content,
            timestamp: msg.timestamp,
            toolName: msg.toolName,
            toolInput: msg.toolInput,
            toolResult: resultString,
            toolStatus: .completed
        )
        sessionMessages[index] = updatedMsg
        messages[sessionId] = sessionMessages
    }

    private func updateSessionStatusFromState(_ sessionId: String, _ state: String) {
        switch state {
        case "idle":
            sessionStatuses[sessionId] = .idle
        case "thinking":
            sessionStatuses[sessionId] = .thinking
        case "streaming":
            sessionStatuses[sessionId] = .streaming
        case "tool_executing":
            sessionStatuses[sessionId] = .toolExecuting
        case "permission_pending":
            sessionStatuses[sessionId] = .permissionPending
        case "question_pending":
            sessionStatuses[sessionId] = .questionPending
        case "completed":
            sessionStatuses[sessionId] = .completed
        default:
            break
        }
    }

    private func addPermissionRequestMessage(_ sessionId: String, _ requestId: String, _ toolName: String, _ description: String?) {
        let message = Message(
            id: "permission-\(requestId)",
            type: .userText,
            content: description ?? "权限请求: \(toolName)",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            toolName: toolName,
            permissionId: requestId,
            permissionDescription: description
        )
        addMessage(sessionId, message)
        sessionStatuses[sessionId] = .permissionPending
    }

    private func addQuestionMessage(_ sessionId: String, _ questionId: String, _ questionText: String, _ options: [String]) {
        let message = Message(
            id: "question-\(questionId)",
            type: .userText,
            content: questionText,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            questionId: questionId,
            options: options
        )
        addMessage(sessionId, message)
        sessionStatuses[sessionId] = .questionPending
    }

    // MARK: - API 操作

    @MainActor
    func fetchSessions() async {
        isLoading = true
        error = nil

        do {
            let fetched = try await APIService.shared.getSessions()
            sessions = fetched
            saveSessions()
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
            let response = try await APIService.shared.createSession(workDir: projectPath)
            await fetchSessions()
            isCreating = false
            return response.sessionId
        } catch {
            self.error = error.localizedDescription
            isCreating = false
            return nil
        }
    }

    @MainActor
    func deleteSession(_ sessionId: String) async {
        do {
            try await APIService.shared.deleteSession(sessionId)
            sessions.removeAll { $0.id == sessionId }
            messages.removeValue(forKey: sessionId)
            sessionStatuses.removeValue(forKey: sessionId)
            contextUsages.removeValue(forKey: sessionId)
            saveSessions()
            // 删除本地消息文件
            let url = messagesFilePath(for: sessionId)
            try? FileManager.default.removeItem(at: url)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // 后台加载会话消息（不阻塞 UI）
    func loadSessionMessagesBackground(_ sessionId: String) {
        Task {
            // 1. 加载本地缓存
            if let localMessages = loadMessagesFromLocal(sessionId) {
                await MainActor.run {
                    messages[sessionId] = localMessages
                }
            }

            // 2. 后台同步服务器
            do {
                let fetched = try await APIService.shared.getMessages(sessionId)
                await MainActor.run {
                    var existingIds = Set(self.messages[sessionId]?.map { $0.id } ?? [])
                    var mergedMessages = self.messages[sessionId] ?? []

                    for msg in fetched {
                        if !existingIds.contains(msg.id) {
                            mergedMessages.append(msg)
                            existingIds.insert(msg.id)
                        }
                    }

                    mergedMessages.sort { $0.timestamp < $1.timestamp }
                    messages[sessionId] = mergedMessages
                }
                saveMessagesToLocal(sessionId)
            } catch {
                print("[SessionStore] ❌ Background sync failed: \(error)")
            }
        }
    }

    // 加载会话消息 - 先显示本地缓存，后台静默同步
    @MainActor
    func loadSessionMessages(_ sessionId: String) async {
        // 1. 先加载本地缓存（立即显示，不阻塞）
        if let localMessages = loadMessagesFromLocal(sessionId) {
            // 直接赋值触发 UI 更新
            messages[sessionId] = localMessages
            print("[SessionStore] ✅ Loaded \(localMessages.count) messages from cache for \(sessionId)")
        } else {
            print("[SessionStore] ⚠️ No local cache for \(sessionId)")
        }

        // 2. 后台静默同步服务器消息（不阻塞 UI）
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let fetched = try await APIService.shared.getMessages(sessionId)
                print("[SessionStore] 🔄 Fetched \(fetched.count) messages from server")

                await MainActor.run {
                    // 合并消息（去重）
                    var existingIds = Set(self.messages[sessionId]?.map { $0.id } ?? [])
                    var mergedMessages = self.messages[sessionId] ?? []

                    for msg in fetched {
                        if !existingIds.contains(msg.id) {
                            mergedMessages.append(msg)
                            existingIds.insert(msg.id)
                        }
                    }

                    // 按时间戳排序
                    mergedMessages.sort { $0.timestamp < $1.timestamp }

                    // 强制触发 UI 更新
                    self.messages[sessionId] = nil
                    self.messages[sessionId] = mergedMessages
                    print("[SessionStore] ✅ Synced, total: \(mergedMessages.count)")
                }

                // 保存到本地
                self.saveMessagesToLocal(sessionId)
            } catch {
                print("[SessionStore] ❌ Failed to sync messages: \(error)")
            }
        }
    }

    func setCurrentSession(_ id: String?) {
        currentSessionId = id
    }

    func addMessage(_ sessionId: String, _ message: Message) {
        var sessionMessages = messages[sessionId] ?? []
        sessionMessages.append(message)
        messages[sessionId] = sessionMessages
    }

    func updateSessionStatus(_ sessionId: String, _ status: SessionStatus) {
        sessionStatuses[sessionId] = status
    }

    func updateSessionTitle(_ sessionId: String, _ title: String) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            let old = sessions[index]
            sessions[index] = Session(
                id: old.id,
                title: title,
                projectPath: old.projectPath,
                workDir: old.workDir,
                workDirExists: old.workDirExists,
                createdAt: old.createdAt,
                modifiedAt: ISO8601DateFormatter().string(from: Date()),
                messageCount: old.messageCount
            )
            saveSessions()
        }
    }

    func setContextUsage(_ sessionId: String, _ usage: Int) {
        contextUsages[sessionId] = usage
    }

    func fetchRecentProjects() async {
        do {
            let projects = try await APIService.shared.getRecentProjects()
            recentProjects = projects
        } catch {
            // 忽略错误
        }
    }

    // MARK: - WebSocket 连接

    func connectWebSocket(serverUrl: String, sessionId: String) {
        // 确保 currentSessionId 在连接前设置，用于消息路由
        currentSessionId = sessionId
        webSocketService.connect(serverUrl: serverUrl, sessionId: sessionId)
    }

    func disconnectWebSocket() {
        webSocketService.disconnect()
    }

    func sendMessage(_ content: String) {
        let message = OutgoingMessage.userMessage(content)
        webSocketService.send(message)
    }

    func sendPermissionResponse(requestId: String, allowed: Bool, always: Bool = false) {
        let message = OutgoingMessage.permissionResponse(requestId: requestId, allowed: allowed, always: always)
        webSocketService.send(message)
    }

    func sendQuestionResponse(questionId: String, answer: String) {
        let message = OutgoingMessage.questionResponse(questionId: questionId, answer: answer)
        webSocketService.send(message)
    }

    func stopGeneration() {
        let message = OutgoingMessage.stop()
        webSocketService.send(message)
    }
}
