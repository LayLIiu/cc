// 聊天视图

import SwiftUI
import UserNotifications

struct ChatView: View {
    let sessionId: String
    @Binding var hideTabBar: Bool
    @Binding var animateTabBar: Bool

    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authStore: AuthStore

    @State private var inputText = ""
    @State private var streamingText = ""
    @State private var streamingThinking = ""
    @State private var chatStatus: SessionStatus = .idle
    @State private var contextUsage: Int = 0
    @State private var previousStatus: SessionStatus = .idle
    @State private var scrollToBottomTrigger = false
    @State private var isAtBottom = true
    @State private var showScrollButton = false
    @State private var processedMsgIds = Set<String>()  // 去重
    @State private var addedMessageContents = Set<String>()  // 用户消息内容去重（防止本地+echo重复）
    @State private var inTextBlock = false
    @State private var inThinkingBlock = false

    @FocusState private var isInputFocused: Bool

    var session: Session? {
        sessionStore.sessions.first { $0.id == sessionId }
    }

    var messages: [Message] {
        sessionStore.messages[sessionId] ?? []
    }

    var allMessages: [Message] {
        var result = messages

        // 添加流式思考（正在生成）
        if !streamingThinking.isEmpty {
            result.append(Message(
                id: "streaming-thinking",
                type: .thinking,
                content: streamingThinking,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                isStreaming: true
            ))
        }

        // 添加流式文本（正在生成）
        if !streamingText.isEmpty {
            result.append(Message(
                id: "streaming-text",
                type: .assistantText,
                content: streamingText,
                timestamp: ISO8601DateFormatter().string(from: Date())
            ))
        }

        return result
    }

    var body: some View {
        ZStack {
            // 背景
            Color.clear
                .liquidGlassBackground(isDark: appState.themeMode == .dark || appState.themeMode == .glass)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 消息列表
                ZStack(alignment: .bottom) {
                    ScrollViewReader { proxy in
                        messageList
                            .onChange(of: scrollToBottomTrigger) { _, _ in
                                withAnimation {
                                    proxy.scrollTo("top-anchor", anchor: .top)
                                }
                            }
                    }

                    // "最新消息"按钮 - 只在往上滚动时显示
                    if showScrollButton {
                        Button {
                            scrollToBottomTrigger.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 10))
                                Text("最新消息")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // 输入区域
                chatInput
            }
        }
        .navigationTitle(session?.title ?? "对话")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(session?.title ?? "对话")
                        .font(.headline)
                        .foregroundColor(.adaptiveText)

                    statusView
                }
            }
        }
        .task {
            // 设置当前会话 ID（用于 WebSocket 消息路由）
            sessionStore.setCurrentSession(sessionId)

            // 先从服务端拉取最新消息（可能桌面端已产生新消息）
            await fetchLatestMessages()

            // 连接 WebSocket 接收实时消息
            let serverUrl = authStore.serverUrl
            if !serverUrl.isEmpty {
                sessionStore.connectWebSocket(serverUrl: serverUrl, sessionId: sessionId)
            }

            // 更新状态
            if let status = sessionStore.sessionStatuses[sessionId] {
                chatStatus = status
                previousStatus = status
            }
            if let usage = sessionStore.contextUsages[sessionId] {
                contextUsage = usage
            }
        }
        // 实时监听 WebSocket 消息 - 直接更新 UI
        .onReceive(sessionStore.webSocketService.$lastMessage) { wsMessage in
            guard let msg = wsMessage else { return }
            handleWSMessage(msg)
        }
        .onDisappear {
            sessionStore.disconnectWebSocket()
            sessionStore.saveMessagesToLocal(sessionId)
        }
        .onChange(of: sessionStore.sessionStatuses[sessionId]) { _, newStatus in
            if let status = newStatus {
                chatStatus = status
            }
        }
        .onChange(of: sessionStore.contextUsages[sessionId]) { _, newUsage in
            if let usage = newUsage {
                contextUsage = usage
            }
        }
        .onChange(of: chatStatus) { oldStatus, newStatus in
            if newStatus == .completed && oldStatus != .completed {
                sendCompletionNotification()
            }
            previousStatus = newStatus
        }
        .onAppear {
            hideTabBar = true
        }
        .onDisappear {
            animateTabBar = true
            hideTabBar = false
        }
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 顶部检测区域 - 判断是否在最新消息位置（倒序列表中顶部=最新）
                Color.clear
                    .frame(height: 1)
                    .id("top-anchor")
                    .onAppear {
                        isAtBottom = true
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showScrollButton = false
                        }
                    }
                    .onDisappear {
                        isAtBottom = false
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showScrollButton = true
                        }
                    }

                // 消息倒序排列（最新在上方 = 视觉上的底部）
                ForEach(allMessages.reversed()) { message in
                    MessageBubbleView(
                        message: message,
                        sessionId: sessionId,
                        onPermissionHandled: {
                            chatStatus = .idle
                        },
                        onQuestionAnswered: {
                            chatStatus = .idle
                        }
                    )
                    .rotationEffect(.degrees(180))  // 翻转每条消息
                    .id(message.id)
                }

                // 消息数量提示（在倒序列表中出现在底部）
                if !messages.isEmpty {
                    Text("\(messages.count) 条消息")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 4)
                        .rotationEffect(.degrees(180))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .rotationEffect(.degrees(180))  // 整体翻转，使最新消息在底部
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - 状态视图

    private var statusView: some View {
        HStack(spacing: 6) {
            if chatStatus != .idle && chatStatus != .completed {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }

            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)

            if contextUsage > 0 {
                ContextRingView(percentage: contextUsage, size: 14, strokeWidth: 2)
            }
        }
    }

    private var statusText: String {
        switch chatStatus {
        case .idle: return "等待中"
        case .thinking: return "思考中"
        case .streaming: return "工作中"
        case .toolExecuting: return "工具执行中"
        case .permissionPending: return "等待权限"
        case .questionPending: return "等待回答"
        case .completed: return "已完成"
        }
    }

    private var statusColor: Color {
        switch chatStatus {
        case .idle: return .secondary
        case .completed: return .green
        case .permissionPending: return .orange
        case .questionPending: return .yellow
        default: return .green
        }
    }

    // MARK: - 输入区域

    private var chatInput: some View {
        HStack(alignment: .center, spacing: 12) {
            // 模型选择器
            ModelSelector()

            TextField("发送消息...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
                .focused($isInputFocused)

            Button {
                sendMessage()
            } label: {
                Image(systemName: chatStatus == .idle ? "arrow.up.circle.fill" : "stop.circle.fill")
                    .font(.title)
                    .foregroundColor(inputText.isEmpty && chatStatus == .idle ? .secondary : .adaptivePrimary)
            }
            .disabled(inputText.isEmpty && chatStatus == .idle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .liquidGlass(cornerRadius: 0, isDark: appState.themeMode == .dark || appState.themeMode == .glass)
    }

    // MARK: - Actions

    private func updateTaskNotification(_ messages: [Message]) {
        // 查找任务列表消息
        guard let taskMessage = messages.last(where: { $0.type == .taskList }),
              let tasks = taskMessage.tasks else { return }

        Task {
            await NotificationService.shared.updateTaskListNotification(
                sessionId: sessionId,
                sessionTitle: session?.title ?? "任务",
                tasks: tasks
            )
        }
    }

    private func sendCompletionNotification() {
        guard let lastAssistantMessage = messages.last(where: { $0.type == .assistantText }) else { return }

        Task {
            await NotificationService.shared.sendCompletionNotification(
                title: session?.title ?? "对话完成",
                message: lastAssistantMessage.content
            )
        }
    }

    // MARK: - 拉取最新消息

    @MainActor
    private func fetchLatestMessages() async {
        do {
            let serverMessages = try await APIService.shared.getMessages(sessionId)
            let localMessages = sessionStore.messages[sessionId] ?? []
            var existingIds = Set(localMessages.map { $0.id })
            var merged = localMessages

            for msg in serverMessages {
                if !existingIds.contains(msg.id) {
                    merged.append(msg)
                    existingIds.insert(msg.id)
                }
            }

            merged.sort { $0.timestamp < $1.timestamp }
            sessionStore.messages[sessionId] = merged
            sessionStore.saveMessagesToLocal(sessionId)
            print("[ChatView] ✅ Synced \(serverMessages.count) from server, total: \(merged.count)")
        } catch {
            print("[ChatView] ⚠️ Failed to fetch messages: \(error)")
        }
    }

    // MARK: - WebSocket 消息处理（实时更新 UI）

    private func handleWSMessage(_ msg: WSMessage) {
        // 去重
        let msgId = "\(msg.type.rawValue)-\(msg.timestamp ?? "")"
        guard !processedMsgIds.contains(msgId) else { return }
        processedMsgIds.insert(msgId)
        if processedMsgIds.count > 200 {
            processedMsgIds = Set(Array(processedMsgIds.suffix(100)))
        }

        // 只处理当前会话
        let targetId = msg.sessionId ?? sessionId
        guard targetId == sessionId else { return }

        switch msg.type {
        case .contentStart:
            if chatStatus == .idle || chatStatus == .completed { chatStatus = .streaming }
            if msg.blockType == "text" { inTextBlock = true; streamingText = "" }

        case .contentDelta:
            if chatStatus == .idle || chatStatus == .completed { chatStatus = .streaming }
            if let text = msg.text { streamingText += text }

        case .thinking:
            if chatStatus == .idle || chatStatus == .completed { chatStatus = .thinking }
            if !inThinkingBlock { inThinkingBlock = true; streamingThinking = "" }
            if let text = msg.text { streamingThinking += text }

        case .toolUseComplete:
            flushStreaming()
            if let toolName = msg.toolName {
                let toolMsg = Message(
                    id: msg.toolUseId ?? UUID().uuidString, type: .toolUse, content: "",
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    toolName: toolName, toolInput: msg.input, toolResult: nil, toolStatus: .running
                )
                sessionStore.addMessage(sessionId, toolMsg)
            }
            chatStatus = .toolExecuting

        case .toolResult:
            if let toolUseId = msg.toolUseId, let content = msg.content {
                let resultStr = (content.value as? String) ?? String(describing: content.value)
                sessionStore.updateToolResult(sessionId, toolUseId, resultStr, msg.isError == true ? .failed : .completed)
            }

        case .messageComplete:
            flushStreaming()
            chatStatus = .completed
            sessionStore.sessionStatuses[sessionId] = .completed
            sessionStore.saveMessagesToLocal(sessionId)

        case .status:
            if let state = msg.state {
                let working = ["thinking", "tool_executing", "streaming", "permission_pending", "question_pending"]
                if working.contains(state) {
                    chatStatus = SessionStatus(rawValue: state) ?? .streaming
                    sessionStore.sessionStatuses[sessionId] = chatStatus
                } else if state == "completed" {
                    chatStatus = .completed
                    sessionStore.sessionStatuses[sessionId] = .completed
                }
            }

        case .permissionRequest:
            if let requestId = msg.requestId {
                let permMsg = Message(
                    id: "permission-\(requestId)", type: .permissionRequest,
                    content: msg.description ?? "权限请求: \(msg.toolName ?? "")",
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    toolName: msg.toolName, permissionId: requestId, permissionDescription: msg.description
                )
                sessionStore.addMessage(sessionId, permMsg)
                chatStatus = .permissionPending
            }

        case .question:
            if let questionId = msg.questionId {
                let qMsg = Message(
                    id: "question-\(questionId)", type: .question,
                    content: msg.questionText ?? "",
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    questionId: questionId, options: msg.options ?? []
                )
                sessionStore.addMessage(sessionId, qMsg)
                chatStatus = .questionPending
            }

        case .tokenUsage:
            if let p = msg.percentage { contextUsage = Int(p * 100); sessionStore.contextUsages[sessionId] = contextUsage }

        case .sessionTitleUpdated:
            if let title = msg.title { sessionStore.updateSessionTitle(sessionId, title) }

        case .userMessageEcho:
            if let contentValue = msg.content?.value {
                let str = contentValue is String ? (contentValue as! String) : String(describing: contentValue)
                // 用内容去重，防止本地发送和 echo 重复
                let contentKey = "user-\(str)"
                guard !addedMessageContents.contains(contentKey) else { return }
                addedMessageContents.insert(contentKey)
                let userMsg = Message(
                    id: msg.id ?? "user-\(UUID().uuidString)", type: .userText, content: str,
                    timestamp: msg.timestamp ?? ISO8601DateFormatter().string(from: Date())
                )
                sessionStore.addMessage(sessionId, userMsg)
            }

        case .connected, .error:
            break
        }
    }

    private func flushStreaming() {
        if !streamingText.isEmpty {
            let textMsg = Message(
                id: "ws-text-\(UUID().uuidString)", type: .assistantText, content: streamingText,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            sessionStore.addMessage(sessionId, textMsg)
            streamingText = ""; inTextBlock = false
        }
        if !streamingThinking.isEmpty {
            let thinkMsg = Message(
                id: "ws-think-\(UUID().uuidString)", type: .thinking, content: streamingThinking,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            sessionStore.addMessage(sessionId, thinkMsg)
            streamingThinking = ""; inThinkingBlock = false
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let content = inputText
        inputText = ""

        // 标记内容已添加，防止 echo 重复
        addedMessageContents.insert("user-\(content)")

        // 添加用户消息
        let userMessage = Message(
            id: "user-\(UUID().uuidString)",
            type: .userText,
            content: content,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        sessionStore.addMessage(sessionId, userMessage)

        // 发送到 WebSocket
        sessionStore.sendMessage(content)

        // 重置状态
        streamingText = ""
        streamingThinking = ""
        inTextBlock = false
        inThinkingBlock = false
        chatStatus = .thinking
    }
}

// MARK: - 消息气泡

struct MessageBubbleView: View {
    let message: Message
    let sessionId: String
    let onPermissionHandled: (() -> Void)?
    let onQuestionAnswered: (() -> Void)?

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionStore: SessionStore

    // 自定义输入状态
    @State private var showCustomInput = false
    @State private var customInputText = ""
    @FocusState private var isInputFocused: Bool

    init(message: Message, sessionId: String, onPermissionHandled: (() -> Void)? = nil, onQuestionAnswered: (() -> Void)? = nil) {
        self.message = message
        self.sessionId = sessionId
        self.onPermissionHandled = onPermissionHandled
        self.onQuestionAnswered = onQuestionAnswered
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if message.type == .userText {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.type == .userText ? .trailing : .leading, spacing: 4) {
                switch message.type {
                case .userText:
                    userTextBubble
                case .assistantText:
                    assistantTextBubble
                case .thinking:
                    thinkingBubble
                case .toolUse:
                    toolUseBubble
                case .toolResult:
                    toolResultBubble
                case .permissionRequest:
                    permissionRequestBubble
                case .question:
                    questionBubble
                case .taskList:
                    taskListBubble
                }
            }

            if message.type != .userText {
                Spacer(minLength: 60)
            }
        }
    }

    private var userTextBubble: some View {
        Text(message.content)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var assistantTextBubble: some View {
        MarkdownRenderer(content: message.content)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var thinkingBubble: some View {
        ThinkingBlock(
            content: message.content,
            isStreaming: message.isStreaming == true
        )
    }

    private var toolUseBubble: some View {
        ToolCallBlock(
            toolName: message.toolName ?? "Unknown",
            input: message.toolInput,
            status: message.toolStatus ?? .completed,
            result: message.toolResult
        )
    }

    private var toolResultBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "doc.text")
                Text("结果")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                if let status = message.toolStatus {
                    switch status {
                    case .completed:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    case .failed:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    default:
                        EmptyView()
                    }
                }
            }

            if let result = message.toolResult {
                MarkdownRenderer(content: result)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 权限请求气泡

    private var permissionRequestBubble: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                Text("权限请求")
                    .font(.headline)
                    .foregroundColor(.adaptiveText)
                Spacer()
            }

            // 工具名称
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.caption)
                    .foregroundColor(.adaptivePrimary)
                    .frame(width: 24, height: 24)
                    .background(Color.adaptivePrimary.opacity(0.1))
                    .cornerRadius(6)

                Text(message.toolName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.adaptiveText)
            }

            // 描述
            if let desc = message.permissionDescription, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.adaptiveTextSecondary)
            }

            // 已处理的结果
            if message.isPermissionHandled {
                HStack {
                    if message.permissionResult == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已允许")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("已拒绝")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            } else {
                // 按钮
                HStack(spacing: 12) {
                    Button {
                        handlePermission(allow: false)
                    } label: {
                        Text("拒绝")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Button {
                        handlePermission(allow: true)
                    } label: {
                        Text("允许")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.adaptivePrimary)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 问题选项气泡

    private var questionBubble: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.purple)
                Text("请选择")
                    .font(.headline)
                    .foregroundColor(.adaptiveText)
                Spacer()
            }

            // 问题内容
            Text(message.content)
                .font(.subheadline)
                .foregroundColor(.adaptiveTextSecondary)

            // 已回答的结果
            if message.isQuestionAnswered {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(message.selectedAnswer ?? "")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            } else if let options = message.options {
                // 选项列表
                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            handleQuestionAnswer(option)
                        } label: {
                            Text(option)
                                .font(.subheadline)
                                .foregroundColor(.adaptiveText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(8)
                        }
                    }

                    // 自定义输入选项
                    if showCustomInput {
                        VStack(spacing: 8) {
                            TextField("输入您的回答...", text: $customInputText)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                                .focused($isInputFocused)

                            HStack(spacing: 12) {
                                Button {
                                    withAnimation {
                                        showCustomInput = false
                                        customInputText = ""
                                    }
                                } label: {
                                    Text("取消")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.primary.opacity(0.1))
                                        .cornerRadius(8)
                                }

                                Button {
                                    let answer = customInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !answer.isEmpty else { return }
                                    handleQuestionAnswer(answer)
                                } label: {
                                    Text("确定")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.adaptivePrimary)
                                        .cornerRadius(8)
                                }
                                .disabled(customInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    } else {
                        Button {
                            withAnimation {
                                showCustomInput = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                Text("自定义输入")
                                    .font(.subheadline)
                                Spacer()
                            }
                            .foregroundColor(.adaptivePrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.adaptivePrimary.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 任务列表气泡

    private var taskListBubble: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "checklist")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text("任务计划")
                    .font(.headline)
                    .foregroundColor(.adaptiveText)
                Spacer()

                // 进度指示
                if let tasks = message.tasks {
                    let completed = tasks.filter { $0.status == .completed }.count
                    let total = tasks.count
                    Text("\(completed)/\(total)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            // 任务列表
            if let tasks = message.tasks {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        HStack(spacing: 12) {
                            // 状态图标
                            ZStack {
                                if task.status == .inProgress {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: task.icon)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(task.color)
                                }
                            }
                            .frame(width: 24, height: 24)

                            // 任务内容
                            Text(task.content)
                                .font(.subheadline)
                                .foregroundColor(task.status == .completed ? .secondary : .adaptiveText)
                                .strikethrough(task.status == .completed)

                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(task.status == .inProgress ? Color.blue.opacity(0.08) : Color.clear)
                        )
                    }
                }

                // 进度条
                let completed = tasks.filter { $0.status == .completed }.count
                let total = tasks.count
                let progress = total > 0 ? Double(completed) / Double(total) : 0

                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text("已完成 \(completed) / \(total) 项任务")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 操作处理

    private func handlePermission(allow: Bool) {
        // 发送权限响应到 WebSocket
        if let permissionId = message.permissionId {
            sessionStore.sendPermissionResponse(requestId: permissionId, allowed: allow)
        }

        // 更新消息状态
        if let index = sessionStore.messages[sessionId]?.firstIndex(where: { $0.id == message.id }) {
            var updatedMessage = message
            updatedMessage.isPermissionHandled = true
            updatedMessage.permissionResult = allow
            sessionStore.messages[sessionId]?[index] = updatedMessage
        }
        // 恢复状态
        sessionStore.sessionStatuses[sessionId] = .idle
        onPermissionHandled?()
    }

    private func handleQuestionAnswer(_ answer: String) {
        // 发送问题响应到 WebSocket
        if let questionId = message.questionId {
            sessionStore.sendQuestionResponse(questionId: questionId, answer: answer)
        }

        // 更新消息状态
        if let index = sessionStore.messages[sessionId]?.firstIndex(where: { $0.id == message.id }) {
            var updatedMessage = message
            updatedMessage.isQuestionAnswered = true
            updatedMessage.selectedAnswer = answer
            sessionStore.messages[sessionId]?[index] = updatedMessage
        }
        // 恢复状态
        sessionStore.sessionStatuses[sessionId] = .idle
        onQuestionAnswered?()
    }

    @ViewBuilder
    private var toolStatusBadge: some View {
        switch message.toolStatus {
        case .pending:
            Label("等待中", systemImage: "clock")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .running:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                Text("执行中")
                    .font(.caption2)
            }
            .foregroundColor(.blue)
        case .completed:
            Label("完成", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
        case .failed:
            Label("失败", systemImage: "xmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.red)
        case .none:
            EmptyView()
        }
    }

    private func formatToolInput(_ input: [String: AnyCodable]) -> String {
        // 简化显示工具输入
        let keys = input.keys.map { "\($0): ..." }
        return keys.joined(separator: "\n")
    }
}

// MARK: - 权限对话框

struct PermissionDialog: View {
    let request: PermissionRequest
    let onAllow: (Bool) -> Void
    let onDeny: () -> Void

    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
            }

            // 标题
            VStack(spacing: 8) {
                Text("权限请求")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.adaptiveText)

                Text("Claude Code 需要您的授权")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 工具信息卡片
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "terminal.fill")
                        .font(.title3)
                        .foregroundColor(.adaptivePrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.adaptivePrimary.opacity(0.1))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.toolName)
                            .font(.headline)
                            .foregroundColor(.adaptiveText)

                        Text("工具")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let description = request.description, !description.isEmpty {
                    Divider()

                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.adaptiveTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(12)

            Spacer()

            // 按钮
            VStack(spacing: 12) {
                Button {
                    onAllow(false)
                } label: {
                    Text("允许")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.adaptivePrimary)
                        .cornerRadius(12)
                }

                Button {
                    onDeny()
                } label: {
                    Text("拒绝")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .padding(24)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 问题对话框

struct QuestionDialog: View {
    let request: QuestionRequest
    let onAnswer: (String) -> Void

    @EnvironmentObject var appState: AppState
    @State private var selectedOption: String?
    @State private var customInput: String = ""
    @FocusState private var isInputFocused: Bool

    private var isCustomInputMode: Bool {
        selectedOption == "__custom__"
    }

    private var canConfirm: Bool {
        if isCustomInputMode {
            return !customInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return selectedOption != nil
    }

    var body: some View {
        VStack(spacing: 24) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.purple)
            }

            // 问题内容卡片
            VStack(alignment: .leading, spacing: 8) {
                Text(request.questionText)
                    .font(.headline)
                    .foregroundColor(.adaptiveText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(12)

            // 选项列表
            ScrollView {
                VStack(spacing: 10) {
                    // 预设选项
                    ForEach(request.options, id: \.self) { option in
                        OptionButton(
                            text: option,
                            isSelected: selectedOption == option,
                            onTap: {
                                selectedOption = option
                                customInput = ""
                            }
                        )
                    }

                    // 自定义输入选项
                    OptionButton(
                        text: "自定义输入",
                        icon: "pencil",
                        isSelected: selectedOption == "__custom__",
                        onTap: {
                            selectedOption = "__custom__"
                        }
                    )
                }
            }
            .frame(maxHeight: 200)

            // 自定义输入框
            if isCustomInputMode {
                TextField("请输入您的回答...", text: $customInput)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                    .focused($isInputFocused)
            }

            Spacer()

            // 确定按钮
            Button {
                let answer: String
                if isCustomInputMode {
                    answer = customInput.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    answer = selectedOption ?? ""
                }
                onAnswer(answer)
            } label: {
                Text("确定")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canConfirm ? Color.adaptivePrimary : Color.secondary.opacity(0.3))
                    .cornerRadius(12)
            }
            .disabled(!canConfirm)
        }
        .padding(24)
        .presentationDetents([.height(520)])
        .presentationDragIndicator(.visible)
        .onAppear {
            // 默认选中第一个选项
            if let firstOption = request.options.first {
                selectedOption = firstOption
            }
        }
    }
}

// MARK: - 选项按钮

struct OptionButton: View {
    let text: String
    var icon: String? = nil
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 选中指示器
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.adaptivePrimary : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color.adaptivePrimary)
                            .frame(width: 12, height: 12)
                    }
                }

                // 图标（如果有）
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .adaptivePrimary : .secondary)
                }

                // 文字
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .adaptiveText : .secondary)
                    .lineLimit(2)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.adaptivePrimary.opacity(0.1) : Color.secondary.opacity(0.05))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.adaptivePrimary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 扩展

extension PermissionRequest: Identifiable {
    var id: String { requestId }
}

extension QuestionRequest: Identifiable {
    var id: String { questionId }
}

// MARK: - 滚动偏移 PreferenceKey

#Preview {
    NavigationStack {
        ChatView(sessionId: "test", hideTabBar: .constant(false), animateTabBar: .constant(false))
    }
    .environmentObject(SessionStore())
    .environmentObject(AppState())
}
