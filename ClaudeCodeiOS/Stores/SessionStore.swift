// 会话状态管理

import SwiftUI
import Combine

// 复用 DateFormatter，避免重复创建
private let sharedDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

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
    var webSocketService = WebSocketService.shared
    private var cancellables = Set<AnyCancellable>()
    private var webSocketTaskSessionId: String?
    private var globalWSSubscribed = false

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

    // 静态 DateFormatter 实例，避免重复创建
    private static let timestampFormatters: [ISO8601DateFormatter] = {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]

        let f3 = ISO8601DateFormatter()
        f3.formatOptions = [.withFullDate, .withFullTime, .withFractionalSeconds]

        let f4 = ISO8601DateFormatter()
        f4.formatOptions = [.withFullDate, .withFullTime]

        return [f1, f2, f3, f4]
    }()

    private static let fallbackFormatter1: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return f
    }()

    private static let fallbackFormatter2: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f
    }()

    private func parseTimestamp(_ timestamp: String) -> Date {
        for formatter in Self.timestampFormatters {
            if let date = formatter.date(from: timestamp) {
                return date
            }
        }

        if let date = Self.fallbackFormatter1.date(from: timestamp) {
            return date
        }

        if let date = Self.fallbackFormatter2.date(from: timestamp) {
            return date
        }

        return Date.distantPast
    }

    init() {
        // 加载保存的会话数据
        loadSavedData()

        // 全局 WebSocket 消息处理 - 始终接收所有会话的消息
        webSocketService.$globalLastMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] tuple in
                guard let self = self else { return }
                let (sessionId, message) = tuple
                self.handleGlobalWSMessage(sessionId: sessionId, message: message)
            }
            .store(in: &cancellables)

        // 保留旧的单会话 WebSocket 用于兼容
        webSocketService.$lastMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] message in
                guard let self = self else { return }
                let targetSessionId = message.sessionId ?? self.currentSessionId
                guard let sessionId = targetSessionId else { return }
                // 如果全局 WebSocket 已订阅，跳过旧连接的消息
                if self.globalWSSubscribed { return }
                self.handleWebSocketMessage(message)
            }
            .store(in: &cancellables)
    }

    // 处理全局 WebSocket 消息（所有会话的消息，包括当前和非当前会话）
    private func handleGlobalWSMessage(sessionId: String, message: WSMessage) {
        print("[SessionStore] 📩 Global WS msg: \(message.type) for session \(sessionId)")

        // 忽略 connected 消息
        if message.type == .connected {
            print("[SessionStore] 🔗 WebSocket connected for \(sessionId)")
            return
        }

        // 确保在主线程更新 UI 相关数据
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let isCurrentSession = self.currentSessionId == sessionId

            switch message.type {
            case .sessionTitleUpdated:
                if let title = message.title { self.updateSessionTitle(sessionId, title) }

            case .status:
                if let state = message.state { self.updateSessionStatusFromState(sessionId, state) }

            case .contentStart, .contentDelta, .thinking:
                // 流式消息表明会话正在工作，更新状态
                let currentStatus = self.sessionStatuses[sessionId]
                if message.type == .thinking {
                    self.sessionStatuses[sessionId] = .thinking
                } else if currentStatus != .streaming && currentStatus != .thinking {
                    self.sessionStatuses[sessionId] = .streaming
                }

            case .toolUseComplete:
                self.sessionStatuses[sessionId] = .toolExecuting

            case .toolResult:
                break // 非当前会话不关心工具结果

            case .messageComplete:
                print("[SessionStore] ✅ messageComplete for \(sessionId)")
                self.sessionStatuses[sessionId] = .completed
                // 触发 objectWillChange 让会话列表刷新
                self.objectWillChange.send()

                // 🔔 非当前会话发送完成通知
                if !isCurrentSession {
                    // 非当前会话，发送通知
                    Task {
                        let sessionTitle = self.sessions.first { $0.id == sessionId }?.title ?? "对话"
                        // 获取最后一条助手消息作为通知内容
                        let lastAssistantMsg = self.messages[sessionId]?.last(where: { $0.type == .assistant })
                        let content = lastAssistantMsg?.content ?? "工作完成"
                        await NotificationService.shared.sendCompletionNotification(
                            title: sessionTitle,
                            message: content
                        )
                    }
                }

            case .permissionRequest:
                self.sessionStatuses[sessionId] = .permissionPending
                // 🔔 非当前会话发送权限通知
                if !isCurrentSession, let requestId = message.requestId {
                    Task {
                        await NotificationService.shared.sendPermissionNotification(
                            sessionId: sessionId,
                            permissionId: requestId,
                            toolName: message.toolName ?? "Unknown",
                            description: message.description ?? ""
                        )
                    }
                }

            case .question:
                self.sessionStatuses[sessionId] = .questionPending
                // 🔔 非当前会话发送问题通知
                if !isCurrentSession, let questionId = message.questionId {
                    Task {
                        await NotificationService.shared.sendQuestionNotification(
                            sessionId: sessionId,
                            questionId: questionId,
                            question: message.questionText ?? "",
                            options: message.options ?? []
                        )
                    }
                }

            case .tokenUsage:
                if let percentage = message.percentage {
                    self.contextUsages[sessionId] = Int(percentage * 100)
                }

            case .userMessageEcho:
                // 收到用户消息 echo，添加到消息列表
                print("[SessionStore] 📩 user_message_echo for session \(sessionId)")
                if let contentValue = message.content?.value {
                    var contentString = (contentValue as? String) ?? String(describing: contentValue)

                    // 过滤掉 tool_result 类型的 JSON 内容
                    contentString = filterToolResultContent(contentString)
                    if contentString.isEmpty { return }

                    // 检查是否已存在相同内容的用户消息（避免重复）
                    let existingUserMessages = self.messages[sessionId]?.filter {
                        $0.type == .user && $0.content == contentString
                    } ?? []

                    if existingUserMessages.isEmpty {
                        let userMsg = Message(
                            id: message.id ?? "user-\(UUID().uuidString)",
                            type: .user,
                            content: contentString,
                            timestamp: message.timestamp ?? sharedDateFormatter.string(from: Date())
                        )
                        self.addMessage(sessionId, userMsg)
                        print("[SessionStore] ✅ Added user message to session \(sessionId)")

                        // 通知 UI 刷新
                        self.objectWillChange.send()
                    } else {
                        print("[SessionStore] ⏭️ Skipping duplicate user message for session \(sessionId)")
                    }
                }

            case .error:
                if let text = message.text {
                    self.error = text
                }

            default:
                break
            }
        }
    }

    // 准备接收流式文本 - 清空之前的助手消息
    private func prepareForStreaming(_ sessionId: String) {
        var sessionMessages = messages[sessionId] ?? []
        // 移除最后一条空的助手消息（如果存在）
        if let lastIndex = sessionMessages.indices.last,
           sessionMessages[lastIndex].type == .assistant,
           sessionMessages[lastIndex].content.isEmpty {
            sessionMessages.removeLast()
        }
        // 创建新的空助手消息占位
        let newMessage = Message(
            id: "assistant-streaming-\(UUID().uuidString)",
            type: .assistant,
            content: "",
            timestamp: sharedDateFormatter.string(from: Date())
        )
        sessionMessages.append(newMessage)
        messages[sessionId] = sessionMessages
        print("[SessionStore] 📝 Prepared for streaming, message count: \(sessionMessages.count)")
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
                var contentString: String
                if let str = contentValue as? String {
                    contentString = str
                } else {
                    contentString = String(describing: contentValue)
                }
                // 过滤掉 tool_result 类型的 JSON 内容
                contentString = filterToolResultContent(contentString)
                if contentString.isEmpty { return }

                print("[SessionStore] 👤 User message echo: \(contentString.prefix(50))")
                let userMessage = Message(
                    id: wsMessage.id ?? "user-\(UUID().uuidString)",
                    type: .user,
                    content: contentString,
                    timestamp: wsMessage.timestamp ?? sharedDateFormatter.string(from: Date())
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
           sessionMessages[lastIndex].type == .assistant {

            let msg = sessionMessages[lastIndex]
            let newContent = msg.content + text
            let updatedMsg = Message(
                id: msg.id,
                type: msg.type,
                content: newContent,
                timestamp: msg.timestamp,
                toolName: msg.toolName,
                toolInput: msg.toolInput,
                toolResult: msg.toolResult,
                toolStatus: msg.toolStatus,
                isStreaming: true
            )
            sessionMessages[lastIndex] = updatedMsg
            messages[sessionId] = sessionMessages
        } else {
            // 创建新的助手消息
            let newMessage = Message(
                id: "assistant-\(UUID().uuidString)",
                type: .assistant,
                content: text,
                timestamp: sharedDateFormatter.string(from: Date()),
                isStreaming: true
            )
            sessionMessages.append(newMessage)
            messages[sessionId] = sessionMessages
            touchSession(sessionId)
        }
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
            messages[sessionId] = sessionMessages
        } else {
            // 创建新的思考消息
            let newMessage = Message(
                id: "thinking-\(UUID().uuidString)",
                type: .thinking,
                content: text,
                timestamp: sharedDateFormatter.string(from: Date())
            )
            sessionMessages.append(newMessage)
            messages[sessionId] = sessionMessages
        }
    }

    private func addToolUseMessage(_ sessionId: String, _ toolName: String, _ toolUseId: String?, _ input: [String: AnyCodable]?, _ status: ToolStatus) {
        let message = Message(
            id: toolUseId ?? UUID().uuidString,
            type: .toolUse,
            content: "",
            timestamp: sharedDateFormatter.string(from: Date()),
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
            type: .user,
            content: description ?? "权限请求: \(toolName)",
            timestamp: sharedDateFormatter.string(from: Date()),
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
            type: .user,
            content: questionText,
            timestamp: sharedDateFormatter.string(from: Date()),
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

            // 保留本地更新的 modifiedAt（避免被服务器旧数据覆盖）
            let localModifiedAt = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.modifiedAt) })

            sessions = fetched.map { serverSession in
                // 如果本地有更新的 modifiedAt，使用本地的
                if let localTime = localModifiedAt[serverSession.id] {
                    let localDate = parseTimestamp(localTime)
                    let serverDate = parseTimestamp(serverSession.modifiedAt)
                    if localDate > serverDate {
                        return Session(
                            id: serverSession.id,
                            title: serverSession.title,
                            projectPath: serverSession.projectPath,
                            workDir: serverSession.workDir,
                            workDirExists: serverSession.workDirExists,
                            createdAt: serverSession.createdAt,
                            modifiedAt: localTime,
                            messageCount: serverSession.messageCount
                        )
                    }
                }
                return serverSession
            }
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
                    // 合并消息（按 ID 和内容双重去重）
                    var existingIds = Set<String>()
                    var existingContents = Set<String>()
                    var mergedMessages = self.messages[sessionId] ?? []

                    for msg in mergedMessages {
                        existingIds.insert(msg.id)
                        existingContents.insert("\(msg.type.rawValue)-\(msg.content)")
                    }

                    for msg in fetched {
                        let contentKey = "\(msg.type.rawValue)-\(msg.content)"
                        // 按 ID 和内容双重检查去重
                        if !existingIds.contains(msg.id) && !existingContents.contains(contentKey) {
                            mergedMessages.append(msg)
                            existingIds.insert(msg.id)
                            existingContents.insert(contentKey)
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

        // 去重：检查是否已存在相同 ID 或相同类型+内容的消息
        let exists = sessionMessages.contains { existing in
            existing.id == message.id ||
            (existing.type == message.type &&
             existing.content == message.content &&
             !message.content.isEmpty)
        }

        if !exists {
            sessionMessages.append(message)
            messages[sessionId] = sessionMessages
            // 更新会话的最后修改时间
            touchSession(sessionId)
        }
    }

    /// 更新会话的最后修改时间（用于会话列表排序）
    func touchSession(_ sessionId: String) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            let old = sessions[index]
            let now = sharedDateFormatter.string(from: Date())
            sessions[index] = Session(
                id: old.id,
                title: old.title,
                projectPath: old.projectPath,
                workDir: old.workDir,
                workDirExists: old.workDirExists,
                createdAt: old.createdAt,
                modifiedAt: now,
                messageCount: old.messageCount
            )
            saveSessions()
            // 触发 UI 刷新
            objectWillChange.send()
        }
    }

    func updateToolResult(_ sessionId: String, _ toolUseId: String, _ result: String, _ status: ToolStatus) {
        var sessionMessages = messages[sessionId] ?? []
        guard let index = sessionMessages.firstIndex(where: { $0.id == toolUseId }) else { return }

        let msg = sessionMessages[index]
        let updatedMsg = Message(
            id: msg.id,
            type: msg.type,
            content: msg.content,
            timestamp: msg.timestamp,
            toolName: msg.toolName,
            toolInput: msg.toolInput,
            toolResult: result,
            toolStatus: status
        )
        sessionMessages[index] = updatedMsg
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
                modifiedAt: sharedDateFormatter.string(from: Date()),
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

    /// 订阅所有会话的消息（全局监听）
    func subscribeToAllSessions(serverUrl: String) {
        guard !serverUrl.isEmpty else { return }
        let sessionIds = sessions.map { $0.id }
        webSocketService.subscribeToAllSessions(serverUrl: serverUrl, sessionIds: sessionIds)
        globalWSSubscribed = true
        print("[SessionStore] ✅ Subscribed to \(sessionIds.count) sessions globally")
    }

    /// 更新订阅列表（当会话列表变化时调用）
    func updateGlobalSubscription(serverUrl: String) {
        guard globalWSSubscribed else { return }
        let sessionIds = sessions.map { $0.id }
        webSocketService.subscribeToAllSessions(serverUrl: serverUrl, sessionIds: sessionIds)
    }

    /// 重新连接所有 WebSocket（App 从后台返回前台时调用）
    func reconnectAllWebSocket(serverUrl: String) {
        guard !serverUrl.isEmpty else { return }
        print("[SessionStore] 🔄 Reconnecting all WebSocket connections...")

        // 断开所有现有连接
        webSocketService.disconnectAllGlobal()

        // 清理状态
        globalWSSubscribed = false

        // 重新订阅所有会话
        let sessionIds = sessions.map { $0.id }
        if !sessionIds.isEmpty {
            webSocketService.subscribeToAllSessions(serverUrl: serverUrl, sessionIds: sessionIds)
            globalWSSubscribed = true
            print("[SessionStore] ✅ Reconnected to \(sessionIds.count) sessions")
        }
    }

    func connectWebSocket(serverUrl: String, sessionId: String) {
        // 确保 currentSessionId 在连接前设置，用于消息路由
        currentSessionId = sessionId
        // 如果已连接同一个会话，不需要重连
        if webSocketService.isConnected && webSocketTaskSessionId == sessionId {
            return
        }
        // 先断开旧连接再重连
        if webSocketService.isConnected {
            webSocketService.disconnect()
        }
        webSocketTaskSessionId = sessionId
        webSocketService.connect(serverUrl: serverUrl, sessionId: sessionId)
    }

    func disconnectWebSocket() {
        webSocketService.disconnect()
        webSocketTaskSessionId = nil
    }

    func sendMessage(_ content: String) {
        guard let sessionId = currentSessionId else {
            print("[SessionStore] ❌ sendMessage: no currentSessionId")
            return
        }
        print("[SessionStore] 📤 sendMessage: sessionId=\(sessionId), globalWSSubscribed=\(globalWSSubscribed)")
        print("[SessionStore] 📤 globalConnections: \(webSocketService.globalConnections.keys)")
        let message = OutgoingMessage.userMessage(content)

        // 优先使用全局 WebSocket
        if globalWSSubscribed {
            let sent = webSocketService.sendGlobal(sessionId: sessionId, message: message)
            print("[SessionStore] 📤 sendGlobal result: \(sent)")
            if !sent {
                // 如果全局发送失败，尝试回退到旧连接
                print("[SessionStore] 📤 Falling back to legacy WebSocket")
                webSocketService.send(message)
            }
        } else {
            webSocketService.send(message)
            print("[SessionStore] 📤 sent via legacy WebSocket")
        }
    }

    func sendPermissionResponse(requestId: String, allowed: Bool, always: Bool = false) {
        guard let sessionId = currentSessionId else { return }
        let message = OutgoingMessage.permissionResponse(requestId: requestId, allowed: allowed, always: always)
        if globalWSSubscribed {
            _ = webSocketService.sendGlobal(sessionId: sessionId, message: message)
        } else {
            webSocketService.send(message)
        }
    }

    func sendQuestionResponse(questionId: String, answer: String) {
        guard let sessionId = currentSessionId else { return }
        let message = OutgoingMessage.questionResponse(questionId: questionId, answer: answer)
        if globalWSSubscribed {
            _ = webSocketService.sendGlobal(sessionId: sessionId, message: message)
        } else {
            webSocketService.send(message)
        }
    }

    func stopGeneration() {
        guard let sessionId = currentSessionId else { return }
        let message = OutgoingMessage.stop()
        if globalWSSubscribed {
            _ = webSocketService.sendGlobal(sessionId: sessionId, message: message)
        } else {
            webSocketService.send(message)
        }
    }

    // MARK: - 导入会话

    @MainActor
    func importSessions(
        _ sessionIds: [String],
        _ sessionInfos: [Session],
        onProgress: ((_ imported: Int, _ total: Int) -> Void)? = nil
    ) async -> (count: Int, error: String?) {
        var importedCount = 0
        let total = sessionIds.count

        for (index, sessionId) in sessionIds.enumerated() {
            do {
                // 获取服务器消息
                let messages = try await APIService.shared.getMessages(sessionId)

                // 写入本地
                self.messages[sessionId] = messages
                saveMessagesToLocal(sessionId)

                // 如果本地没有该会话，添加到会话列表
                let sessionInfo = sessionInfos.first { $0.id == sessionId }
                if let info = sessionInfo, !self.sessions.contains(where: { $0.id == sessionId }) {
                    self.sessions.append(info)
                    saveSessions()
                }

                importedCount += 1
                onProgress?(importedCount, total)
            } catch {
                print("[SessionStore] ❌ Failed to import session \(sessionId): \(error)")
                // 继续导入其他的
            }
        }

        if importedCount == 0 {
            return (0, "导入失败，请检查网络连接")
        }
        return (importedCount, nil)
    }

    // MARK: - 辅助方法：过滤 tool_result 内容

    /// 过滤掉 tool_result 类型的 JSON 内容
    /// 如果内容是 tool_result 数组，返回空字符串
    /// 如果内容混合了 tool_result 和其他类型，只保留非 tool_result 的文本
    private func filterToolResultContent(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 检查是否是 JSON 数组
        guard trimmed.hasPrefix("[") else {
            return content
        }

        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return content
        }

        // 检查是否包含 tool_result 类型
        let hasToolResult = json.contains { item in
            (item["type"] as? String) == "tool_result"
        }

        if !hasToolResult {
            return content
        }

        // 检查是否所有元素都是 tool_result
        let allAreToolResults = json.allSatisfy { item in
            (item["type"] as? String) == "tool_result"
        }

        if allAreToolResults {
            // 全部是 tool_result，不显示
            return ""
        }

        // 提取非 tool_result 的文本内容
        let texts = json.compactMap { item -> String? in
            guard (item["type"] as? String) == "text" else { return nil }
            return item["text"] as? String
        }

        return texts.isEmpty ? "" : texts.joined(separator: "\n")
    }
}
