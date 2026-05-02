// 聊天视图

import SwiftUI

// 复用 DateFormatter，避免重复创建
private let sharedDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

struct ChatView: View {
    let sessionId: String
    @Binding var hideTabBar: Bool
    @Binding var animateTabBar: Bool

    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authStore: AuthStore

    @State private var inputText = ""
    // 流式文本本地管理（参考 RN 版本架构）
    @State private var streamingText = ""
    @State private var streamingThinking = ""
    @State private var inTextBlock = false
    @State private var inThinkingBlock = false

    // 分页加载 - 性能优化
    @State private var displayedMessageCount = 50  // 初始显示 50 条
    @State private var isLoadingMore = false
    @State private var hasMoreMessages = false

    // 是否是浅色主题
    private var isLightTheme: Bool {
        appState.themeMode == .light
    }
    @State private var chatStatus: SessionStatus = .idle
    @State private var contextUsage: Int = 0
    @State private var previousStatus: SessionStatus = .idle
    @State private var scrollToBottomTrigger = false
    @State private var isAtBottom = true
    @State private var showScrollButton = false
    @State private var userIsViewingHistory = false  // 用户是否在主动查看历史
    // Token 使用量
    @State private var tokenUsage: Int = 0
    // 最近发送的消息内容（用于去重 user_message_echo）
    @State private var recentlySentMessages: Set<String> = []

    @FocusState private var isInputFocused: Bool

    var session: Session? {
        sessionStore.sessions.first { $0.id == sessionId }
    }

    var messages: [Message] {
        sessionStore.messages[sessionId] ?? []
    }

    /// 当前会话的权限模式
    var currentPermissionMode: PermissionMode {
        sessionStore.sessionPermissionModes[sessionId] ?? .default
    }

    // 分页后的消息（只显示最近 N 条）- 缓存优化
    @State private var cachedVisibleMessages: [Message] = []
    @State private var lastMessagesCount = 0

    // 更新可见消息缓存
    private func updateVisibleMessagesCache() {
        let allMessages = messages
        let currentCount = allMessages.count

        // 只在消息数量变化时更新缓存
        if currentCount != lastMessagesCount {
            lastMessagesCount = currentCount
            if currentCount <= displayedMessageCount {
                cachedVisibleMessages = allMessages
            } else {
                cachedVisibleMessages = Array(allMessages.suffix(displayedMessageCount))
            }
        }
    }

    // 合并 store 消息 + 本地流式消息
    var allMessages: [Message] {
        var result = cachedVisibleMessages

        // 添加流式思考（正在生成）
        if !streamingThinking.isEmpty {
            result.append(Message(
                id: "streaming-thinking",
                type: .thinking,
                content: streamingThinking,
                timestamp: sharedDateFormatter.string(from: Date()),
                isStreaming: true
            ))
        }

        // 添加流式文本（正在生成）
        if !streamingText.isEmpty {
            result.append(Message(
                id: "streaming-text",
                type: .assistant,
                content: streamingText,
                timestamp: sharedDateFormatter.string(from: Date()),
                isStreaming: true
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
                            userIsViewingHistory = false  // 用户主动回到底部
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

                // 任务面板
                SessionTaskBarView()

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

                    // 状态行：简单居中
                    HStack(spacing: 6) {
                        if chatStatus != .idle && chatStatus != .completed {
                            StatusIndicator(status: chatStatus, size: 10)
                        }
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(statusColor)
                        if contextUsage > 0 {
                            ContextRingView(percentage: contextUsage, size: 14, strokeWidth: 2)
                        }
                    }
                }
            }

            // 测试按钮（仅调试模式）
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Section("权限模式") {
                        ForEach(PermissionMode.allCases, id: \.self) { mode in
                            Button {
                                sessionStore.changePermissionMode(mode)
                            } label: {
                                HStack {
                                    // 小圆点指示当前选中
                                    Circle()
                                        .fill(mode.color)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mode.displayName)
                                            .font(.subheadline)
                                        Text(mode.description)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    // 当前选中的模式显示勾选标记
                                    if sessionStore.sessionPermissionModes[sessionId] == mode ||
                                        (sessionStore.sessionPermissionModes[sessionId] == nil && mode == .default) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(mode.color)
                                    }
                                }
                            }
                        }
                    }

                    // 保留测试功能（调试用）
                    Section("测试功能") {
                        Button("模拟权限请求") {
                            sessionStore.simulatePermissionRequest()
                        }
                        Button("模拟问题") {
                            sessionStore.simulateQuestion()
                        }
                        Button("模拟任务列表") {
                            sessionStore.simulateTaskList()
                        }
                    }
                } label: {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(currentPermissionMode.color)
                }
            }
        }
        .task {
            // 设置当前会话 ID（用于消息路由）
            print("[ChatView] 🔧 Setting current session: \(sessionId)")
            sessionStore.setCurrentSession(sessionId)

            // 更新会话的最后修改时间（让会话移动到"今天"分组）
            sessionStore.touchSession(sessionId)

            // 🔥 先同步加载本地缓存（如果有），确保 UI 立即显示
            if sessionStore.messages[sessionId] == nil || sessionStore.messages[sessionId]?.isEmpty == true {
                if let localMessages = sessionStore.loadMessagesFromLocal(sessionId) {
                    sessionStore.messages[sessionId] = localMessages
                    print("[ChatView] 📦 Loaded \(localMessages.count) messages from local cache")
                }
            }

            // 初始化分页状态和缓存
            updatePaginationState()
            updateVisibleMessagesCache()

            // 🔥 确保 WebSocket 已订阅该会话
            let serverUrl = authStore.serverUrl
            if !serverUrl.isEmpty {
                sessionStore.subscribeToSession(serverUrl: serverUrl, sessionId: sessionId)
            }

            // 🚀 后台静默同步消息，不阻塞 UI
            Task {
                await fetchLatestMessages()
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
        // 监听全局 WebSocket 消息 - 本地 State 处理流式文本
        .onReceive(sessionStore.webSocketService.$globalLastMessage) { tuple in
            guard let (msgSessionId, msg) = tuple else { return }
            guard msgSessionId == sessionId else { return }
            print("[ChatView] 📩 Received WS msg: \(msg.type)")
            handleStreamingMessage(msg)
        }
        // 监听 messages 变化 - 滚动到底部
        .onChange(of: sessionStore.messages[sessionId]?.count ?? 0) { oldValue, newValue in
            print("[ChatView] Messages count changed: \(oldValue) -> \(newValue)")
            // 更新分页状态和缓存
            updatePaginationState()
            updateVisibleMessagesCache()
            // 缓存已通过 updateVisibleMessagesCache 更新
            if newValue > oldValue && !userIsViewingHistory {
                // 新消息到达，只有在用户没有在查看历史时才滚动
                scrollToBottomTrigger.toggle()
            }
        }
        .onDisappear {
            // 只保存当前会话消息到本地，不断开 WebSocket
            sessionStore.saveMessagesToLocal(sessionId)
            // 清除当前会话 ID
            sessionStore.setCurrentSession(nil)
        }
        .onAppear {
            hideTabBar = true
            // 🔥 每次出现时检查并修复 WebSocket 连接
            let serverUrl = authStore.serverUrl
            if !serverUrl.isEmpty {
                sessionStore.subscribeToSession(serverUrl: serverUrl, sessionId: sessionId)
            }
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
                        // 用户离开了最新消息位置，标记为正在查看历史
                        userIsViewingHistory = true
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showScrollButton = true
                        }
                    }

                // 流式处理指示器 - 独立组件避免触发父视图重绘
                // 由于列表倒序，这个指示器放在 ForEach 之前，翻转后显示在视觉底部
                // 只在 AI 工作时显示：thinking / tool_executing / streaming
                if chatStatus == .thinking || chatStatus == .toolExecuting || chatStatus == .streaming {
                    StreamingStatusView(
                        status: chatStatus,
                        tokenCount: tokenUsage
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .rotationEffect(.degrees(180))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
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

                // 加载更多历史消息（在倒序列表中出现在顶部）
                if hasMoreMessages {
                    Button {
                        loadMoreMessages()
                    } label: {
                        HStack(spacing: 8) {
                            if isLoadingMore {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 10))
                            }
                            Text("加载更早消息")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                    }
                    .rotationEffect(.degrees(180))
                }

                // 消息数量提示（在倒序列表中出现在底部）
                if !messages.isEmpty {
                    Text(hasMoreMessages ? "已显示 \(displayedMessageCount)/\(messages.count) 条" : "\(messages.count) 条消息")
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

    // 加载更多历史消息
    private func loadMoreMessages() {
        guard !isLoadingMore, hasMoreMessages else { return }
        isLoadingMore = true

        // 异步加载，避免阻塞 UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let increment = 30
            let newCount = min(displayedMessageCount + increment, messages.count)
            displayedMessageCount = newCount
            hasMoreMessages = displayedMessageCount < messages.count
            isLoadingMore = false
        }
    }

    // 更新分页状态
    private func updatePaginationState() {
        let totalCount = messages.count
        // 如果消息数少于已显示数，重置为显示全部
        if totalCount <= displayedMessageCount {
            displayedMessageCount = totalCount
            hasMoreMessages = false
        } else {
            hasMoreMessages = true
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
                Text("发送")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(inputText.isEmpty ? .secondary : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(inputText.isEmpty ? Color.secondary.opacity(0.2) : Color.adaptivePrimary)
                    .cornerRadius(16)
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isLightTheme ? Color.clear : Color(hex: "1A1A1A").opacity(0.8))
    }

    // MARK: - 拉取最新消息

    @MainActor
    private func fetchLatestMessages() async {
        do {
            let serverMessages = try await APIService.shared.getMessages(sessionId)
            let localMessages = sessionStore.messages[sessionId] ?? []

            // 构建已存在内容的集合（用于内容去重）
            var existingContents = Set<String>()
            var existingIds = Set<String>()

            for msg in localMessages {
                existingIds.insert(msg.id)
                // 用类型+内容作为去重键
                existingContents.insert("\(msg.type.rawValue)-\(msg.content)")
            }

            var merged = localMessages

            for msg in serverMessages {
                let contentKey = "\(msg.type.rawValue)-\(msg.content)"

                // 先检查 ID，再检查内容
                if !existingIds.contains(msg.id) && !existingContents.contains(contentKey) {
                    merged.append(msg)
                    existingIds.insert(msg.id)
                    existingContents.insert(contentKey)
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

    // MARK: - WebSocket 流式消息处理（本地 State 驱动 UI）

    private func handleStreamingMessage(_ msg: WSMessage) {
        switch msg.type {
        case .contentStart:
            // 开始新的文本块 - 确保灵动岛已启动
            let sessionTitle = session?.title ?? "对话"
            LiveActivityService.shared.sessionStartedWorking(sessionId: sessionId, sessionTitle: sessionTitle)

            if chatStatus == .idle || chatStatus == .completed {
                chatStatus = .streaming
            }
            if msg.blockType == "text" {
                inTextBlock = true
                streamingText = ""
            }

        case .contentDelta:
            // 流式文本追加到本地 state
            if chatStatus == .idle || chatStatus == .completed {
                chatStatus = .streaming
            }
            if let text = msg.text {
                streamingText += text
                // 🎯 更新灵动岛显示完整内容
                LiveActivityService.shared.updateStreamingContent(streamingText, sessionId: sessionId)
            }

        case .thinking:
            // 思考内容追加到本地 state
            // 确保灵动岛已启动
            let sessionTitle = session?.title ?? "对话"
            LiveActivityService.shared.sessionStartedWorking(sessionId: sessionId, sessionTitle: sessionTitle)

            if chatStatus == .idle || chatStatus == .completed {
                chatStatus = .thinking
            }
            if !inThinkingBlock {
                inThinkingBlock = true
                streamingThinking = ""
            }
            if let text = msg.text {
                streamingThinking += text
                // 🎯 更新灵动岛显示完整思考内容
                LiveActivityService.shared.updateThinkingContent(streamingThinking, sessionId: sessionId)
            }

        case .toolUseComplete:
            // 工具调用完成 - 把流式缓冲区写入 store
            flushStreamingBuffers()
            inTextBlock = false
            inThinkingBlock = false

            // 添加工具消息
            if let toolName = msg.toolName {
                let toolMsg = Message(
                    id: msg.toolUseId ?? "tool-\(UUID().uuidString)",
                    type: .toolUse,
                    content: "",
                    timestamp: sharedDateFormatter.string(from: Date()),
                    toolName: toolName,
                    toolInput: msg.input,
                    toolStatus: .running
                )
                sessionStore.addMessage(sessionId, toolMsg)

                // 🎯 更新灵动岛显示工具调用（完整内容）
                let sessionTitle = session?.title ?? "对话"
                LiveActivityService.shared.sessionStartedWorking(sessionId: sessionId, sessionTitle: sessionTitle)

                // 提取工具输入的完整描述
                var inputDesc: String? = nil
                if let input = msg.input {
                    // 优先使用 description 字段
                    if let desc = input["description"]?.value as? String, !desc.isEmpty {
                        inputDesc = desc
                    } else if let filePath = input["file_path"]?.value as? String {
                        inputDesc = filePath
                    } else if let command = input["command"]?.value as? String {
                        inputDesc = command
                    } else if let pattern = input["pattern"]?.value as? String {
                        inputDesc = pattern
                    }
                }
                LiveActivityService.shared.updateToolUse(toolName: toolName, toolInput: inputDesc, sessionId: sessionId)

                // 拦截任务工具调用，更新任务面板
                sessionStore.handleTaskToolCallPublic(sessionId, toolName: toolName, input: msg.input)
            }
            chatStatus = .toolExecuting

        case .toolResult:
            // 工具结果
            if let toolUseId = msg.toolUseId, let content = msg.content {
                let resultStr = (content.value as? String) ?? String(describing: content.value)
                sessionStore.updateToolResult(sessionId, toolUseId, resultStr, msg.isError == true ? .failed : .completed)
            }

        case .messageComplete:
            // 消息完成 - 把流式缓冲区写入 store
            flushStreamingBuffers()
            inTextBlock = false
            inThinkingBlock = false
            chatStatus = .completed
            // 更新 token 使用量
            if let outputTokens = msg.used {
                tokenUsage = outputTokens
            }
            // 只有用户没有在查看历史时才滚动
            if !userIsViewingHistory {
                scrollToBottomTrigger.toggle()
            }

        case .status:
            if let state = msg.state {
                print("[ChatView] 📊 Status update: \(state)")
                switch state {
                case "idle":
                    chatStatus = .idle
                case "thinking":
                    chatStatus = .thinking
                case "tool_executing":
                    chatStatus = .toolExecuting
                case "streaming":
                    chatStatus = .streaming
                case "permission_pending":
                    chatStatus = .permissionPending
                case "question_pending":
                    chatStatus = .questionPending
                case "completed":
                    chatStatus = .completed
                default:
                    break
                }
            }

        case .permissionRequest:
            flushStreamingBuffers()
            chatStatus = .permissionPending

        case .question, .questions:
            flushStreamingBuffers()
            chatStatus = .questionPending

        case .tokenUsage:
            if let percentage = msg.percentage {
                contextUsage = Int(percentage * 100)
                sessionStore.setContextUsage(sessionId, Int(percentage * 100))
            }

        case .userMessageEcho:
            print("[ChatView] 📩 Received user_message_echo for session \(sessionId)")
            if let contentValue = msg.content?.value {
                var contentString = (contentValue as? String) ?? String(describing: contentValue)
                print("[ChatView] 📩 Content: \(contentString.prefix(100))")

                // 解析桌面端发送的消息格式 [{"type":"text","text":"实际内容"}]
                if contentString.hasPrefix("[") && contentString.contains("\"text\"") {
                    if let data = contentString.data(using: .utf8),
                       let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        // 提取所有 text 字段拼接
                        let texts = jsonArray.compactMap { $0["text"] as? String }
                        if !texts.isEmpty {
                            contentString = texts.joined(separator: "\n")
                            print("[ChatView] 📩 Parsed desktop message: \(contentString.prefix(100))")
                        }
                    }
                }

                // 检查是否是最近发送的消息（iOS 端发送的会有记录）
                if recentlySentMessages.contains(contentString) {
                    print("[ChatView] 📩 Skipping user_message_echo - already added locally")
                    recentlySentMessages.remove(contentString)
                } else {
                    // 桌面端发送的消息，需要添加到列表
                    print("[ChatView] 📩 Adding message from desktop")
                    let userMsg = Message(
                        id: msg.id ?? "user-\(UUID().uuidString)",
                        type: .user,
                        content: contentString,
                        timestamp: msg.timestamp ?? sharedDateFormatter.string(from: Date())
                    )
                    sessionStore.addMessage(sessionId, userMsg)
                }
            }

        default:
            break
        }
    }

    // 把流式缓冲区写入 store（只在完成时调用）
    private func flushStreamingBuffers() {
        if !streamingText.isEmpty {
            // 过滤掉 JSON 格式的工具调用链消息
            let trimmed = streamingText.trimmingCharacters(in: .whitespacesAndNewlines)
            let shouldHide = trimmed.hasPrefix("[{") && (trimmed.contains("\"tool_use_id\"") || trimmed.contains("\"tool_result\""))

            if !shouldHide {
                let textMsg = Message(
                    id: "assistant-\(UUID().uuidString)",
                    type: .assistant,
                    content: streamingText,
                    timestamp: sharedDateFormatter.string(from: Date())
                )
                sessionStore.addMessage(sessionId, textMsg)
            }
            streamingText = ""
        }

        if !streamingThinking.isEmpty {
            let thinkMsg = Message(
                id: "thinking-\(UUID().uuidString)",
                type: .thinking,
                content: streamingThinking,
                timestamp: sharedDateFormatter.string(from: Date())
            )
            sessionStore.addMessage(sessionId, thinkMsg)
            streamingThinking = ""
        }
        // 缓存已通过 updateVisibleMessagesCache 更新
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let content = inputText
        inputText = ""

        // 用户发送新消息，退出查看历史模式
        userIsViewingHistory = false

        // 记录最近发送的消息内容（用于去重 user_message_echo）
        recentlySentMessages.insert(content)

        // 添加用户消息
        let userMessage = Message(
            id: "user-\(UUID().uuidString)",
            type: .user,
            content: content,
            timestamp: sharedDateFormatter.string(from: Date())
        )
        sessionStore.addMessage(sessionId, userMessage)

        // 发送到 WebSocket
        sessionStore.sendMessage(content)

        // 重置流式状态
        streamingText = ""
        streamingThinking = ""
        inTextBlock = false
        inThinkingBlock = false
        // 缓存已通过 updateVisibleMessagesCache 更新
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

    // 本地状态：问题/权限是否已处理（解决 SwiftUI 不刷新问题）
    @State private var localIsQuestionAnswered = false
    @State private var localSelectedAnswer: String?
    @State private var localIsPermissionHandled = false
    @State private var localPermissionResult: Bool?

    // 复制功能状态
    @State private var showCopyButton = false
    @State private var showCopiedIndicator = false

    // 是否是浅色主题
    private var isLightTheme: Bool {
        appState.themeMode == .light
    }

    // 可复制的消息类型
    private var canCopy: Bool {
        message.type == .user || message.type == .assistant
    }

    // 要复制的内容
    private var copyContent: String {
        message.content
    }

    init(message: Message, sessionId: String, onPermissionHandled: (() -> Void)? = nil, onQuestionAnswered: (() -> Void)? = nil) {
        self.message = message
        self.sessionId = sessionId
        self.onPermissionHandled = onPermissionHandled
        self.onQuestionAnswered = onQuestionAnswered
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                if message.type == .user {
                    Spacer(minLength: 60)
                }

                VStack(alignment: message.type == .user ? .trailing : .leading, spacing: 4) {
                    switch message.type {
                    case .user:
                        userTextBubble
                    case .assistant:
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
                        EmptyView()  // 任务列表已移至底部悬浮面板
                    }
                }

                if message.type != .user {
                    Spacer(minLength: 60)
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.3) {
                if canCopy {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showCopyButton = true
                    }
                }
            }
            .onTapGesture {
                // 点击消息时关闭复制按钮
                if showCopyButton {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showCopyButton = false
                    }
                }
            }

            // 复制按钮 / 已复制提示
            if showCopyButton || showCopiedIndicator {
                copyActionView
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
    }

    // MARK: - 复制操作视图

    private var copyActionView: some View {
        HStack {
            if message.type != .user {
                Spacer(minLength: 60)
            }

            if showCopiedIndicator {
                // 已复制提示
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已复制")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            } else {
                // 复制按钮
                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("复制")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            if message.type == .user {
                Spacer(minLength: 60)
            }
        }
        .padding(.top, 4)
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = copyContent

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopyButton = false
            showCopiedIndicator = true
        }

        // 1.5秒后隐藏已复制提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showCopiedIndicator = false
            }
        }
    }

    private var userTextBubble: some View {
        Text(message.content)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var assistantTextBubble: some View {
        // 过滤掉工具调用 JSON 格式的内容
        Group {
            if shouldHideContent(message.content) {
                EmptyView()
            } else {
                MarkdownRenderer(content: message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    /// 检测是否应该隐藏内容（工具调用 JSON 格式）
    private func shouldHideContent(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        // 只检测以 [{ 开头的 JSON 数组格式
        guard trimmed.hasPrefix("[{") else { return false }
        return trimmed.contains("\"tool_use_id\"") ||
               trimmed.contains("\"tool_result\"")
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
        // 如果结果是 JSON 格式的工具调用，隐藏整个气泡
        Group {
            if let result = message.toolResult, !shouldHideToolResult(result) {
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

                    MarkdownRenderer(content: result)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                EmptyView()
            }
        }
    }

    /// 检测是否应该隐藏工具结果（JSON 格式的工具调用）
    private func shouldHideToolResult(_ result: String) -> Bool {
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        // 只检测以 [{ 开头的 JSON 数组格式
        guard trimmed.hasPrefix("[{") else { return false }
        return trimmed.contains("\"tool_use_id\"") ||
               trimmed.contains("\"tool_result\"")
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

            // 已处理的结果（优先使用本地状态，解决 SwiftUI 刷新问题）
            if localIsPermissionHandled || message.isPermissionHandled {
                HStack {
                    if localPermissionResult ?? message.permissionResult == true {
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
        .background(Color.secondary.opacity(0.08))
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

            // 已回答的结果（优先使用本地状态，解决 SwiftUI 刷新问题）
            if localIsQuestionAnswered || message.isQuestionAnswered {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(localSelectedAnswer ?? message.selectedAnswer ?? "")
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
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 操作处理

    private func handlePermission(allow: Bool) {
        // 立即更新本地状态（解决 UI 不刷新问题）
        withAnimation {
            localIsPermissionHandled = true
            localPermissionResult = allow
        }

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
            // 触发 UI 刷新
            sessionStore.notifyChanged()
        }
        // 恢复状态
        sessionStore.sessionStatuses[sessionId] = .idle
        onPermissionHandled?()
    }

    private func handleQuestionAnswer(_ answer: String) {
        print("[ChatView] 📝 Question answered: \(answer), questionId: \(message.questionId ?? "nil")")

        // 立即更新本地状态（解决 UI 不刷新问题）
        withAnimation {
            localIsQuestionAnswered = true
            localSelectedAnswer = answer
        }

        // 发送问题响应到 WebSocket
        if let questionId = message.questionId {
            print("[ChatView] 📤 Sending question response...")
            sessionStore.sendQuestionResponse(questionId: questionId, answer: answer)
        }

        // 更新消息状态
        if let index = sessionStore.messages[sessionId]?.firstIndex(where: { $0.id == message.id }) {
            print("[ChatView] ✅ Updating message at index \(index)")
            var updatedMessage = message
            updatedMessage.isQuestionAnswered = true
            updatedMessage.selectedAnswer = answer
            sessionStore.messages[sessionId]?[index] = updatedMessage
            // 触发 UI 刷新
            sessionStore.notifyChanged()
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

// MARK: - 底部悬浮任务面板

struct SessionTaskBarView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var appState: AppState

    private var tasks: [TaskItem] {
        sessionStore.getCurrentTasks()
    }

    private var allCompleted: Bool {
        !tasks.isEmpty && tasks.allSatisfy { $0.status == .completed }
    }

    private var completedCount: Int {
        tasks.filter { $0.status == .completed }.count
    }

    private var totalCount: Int {
        tasks.count
    }

    private var progressPercent: Double {
        totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }

    var body: some View {
        // 无任务或用户已关闭时隐藏
        if !tasks.isEmpty && !sessionStore.taskBarDismissed {
            VStack(spacing: 0) {
                // 分隔线
                Divider()
                    .opacity(0.3)

                // 主体
                VStack(spacing: 0) {
                    // 标题栏 - 始终可见，点击展开/收起
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sessionStore.toggleTaskBarExpanded()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            // 图标
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.adaptivePrimary.opacity(0.1))
                                    .frame(width: 26, height: 26)
                                Image(systemName: "checklist")
                                    .font(.system(size: 13))
                                    .foregroundColor(.adaptivePrimary)
                            }

                            // 标题
                            Text("任务")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.adaptiveText)

                            // 进度条
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.2))
                                    Capsule()
                                        .fill(allCompleted ? Color.green : Color.adaptivePrimary)
                                        .frame(width: max(geometry.size.width * progressPercent, progressPercent > 0 ? 4 : 0))
                                }
                            }
                            .frame(height: 4)
                            .frame(maxWidth: 160)

                            // 计数
                            Text("\(completedCount)/\(totalCount)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)

                            Spacer()

                            // 展开箭头
                            Image(systemName: "chevron.up")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(sessionStore.taskBarExpanded ? 0 : 180))

                            // 全部完成时显示关闭按钮
                            if allCompleted {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        sessionStore.dismissTaskBar()
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 20, height: 20)
                                        .background(Color.secondary.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 展开的任务列表
                    if sessionStore.taskBarExpanded {
                        VStack(spacing: 0) {
                            Divider()
                                .opacity(0.2)

                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVStack(spacing: 2) {
                                    ForEach(tasks) { task in
                                        TaskItemRow(task: task)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .frame(maxHeight: 200)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .background(.ultraThinMaterial)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - 任务项行

struct TaskItemRow: View {
    let task: TaskItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 状态图标
            ZStack {
                if task.status == .inProgress {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: task.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(task.color)
                }
            }
            .frame(width: 16, height: 16)
            .padding(.top, 1)

            // 内容区
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("#\(task.id)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(task.content)
                        .font(.system(size: 12))
                        .foregroundColor(task.status == .completed ? .secondary : .adaptiveText)
                        .strikethrough(task.status == .completed, color: .secondary)
                }

                // 进行中显示 activeForm
                if task.status == .inProgress, let activeForm = task.activeForm {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                            .modifier(PulseEffect())
                        Text(activeForm)
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }

                // 负责人
                if let owner = task.owner {
                    HStack(spacing: 3) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 8))
                        Text(owner)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(task.status == .inProgress ? Color.blue.opacity(0.06) : Color.clear)
        )
    }
}

// MARK: - 脉冲动画修饰符

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

#Preview {
    NavigationStack {
        ChatView(sessionId: "test", hideTabBar: .constant(false), animateTabBar: .constant(false))
    }
    .environmentObject(SessionStore())
    .environmentObject(AppState())
}
