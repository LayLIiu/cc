// 聊天视图

import SwiftUI
import UserNotifications

struct ChatView: View {
    let sessionId: String
    @Binding var hideTabBar: Bool
    @Binding var animateTabBar: Bool

    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var appState: AppState

    @State private var inputText = ""
    @State private var streamingText = ""
    @State private var streamingThinking = ""
    @State private var chatStatus: SessionStatus = .idle
    @State private var contextUsage: Int = 0
    @State private var showScrollToBottom = false
    @State private var previousStatus: SessionStatus = .idle

    @FocusState private var isInputFocused: Bool

    var session: Session? {
        sessionStore.sessions.first { $0.id == sessionId }
    }

    var messages: [Message] {
        sessionStore.messages[sessionId] ?? []
    }

    var allMessages: [Message] {
        var result: [Message] = []

        // 添加流式文本
        if !streamingText.isEmpty {
            result.append(Message(
                id: "streaming-text",
                type: .assistantText,
                content: streamingText,
                timestamp: Date()
            ))
        }

        // 添加流式思考
        if !streamingThinking.isEmpty {
            result.append(Message(
                id: "streaming-thinking",
                type: .thinking,
                content: streamingThinking,
                timestamp: Date(),
                isStreaming: true
            ))
        }

        // 添加历史消息
        result.append(contentsOf: messages)

        return result
    }

    var body: some View {
        ZStack {
            // 背景 - 统一使用玻璃背景
            Color.clear
                .liquidGlassBackground(isDark: appState.themeMode == .dark || appState.themeMode == .glass)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 消息列表
                messageList

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
            // 请求通知权限
            _ = await NotificationService.shared.requestAuthorization()

            await sessionStore.fetchMessages(sessionId)
            if let status = sessionStore.sessionStatuses[sessionId] {
                chatStatus = status
                previousStatus = status
            }
            if let usage = sessionStore.contextUsages[sessionId] {
                contextUsage = usage
            }

            // 测试：添加权限请求、问题消息和任务列表（只在首次进入时添加）
            let existingMessages = sessionStore.messages[sessionId] ?? []
            let hasPermissionMessage = existingMessages.contains { $0.type == .permissionRequest }
            let hasQuestionMessage = existingMessages.contains { $0.type == .question }
            let hasTaskListMessage = existingMessages.contains { $0.type == .taskList }

            if sessionId == "session-1" && !hasPermissionMessage {
                // 添加权限请求消息
                sessionStore.addMessage(sessionId, Message(
                    id: "msg-permission-1",
                    type: .permissionRequest,
                    content: "",
                    timestamp: Date(),
                    toolName: "Bash",
                    permissionId: "perm-1",
                    permissionDescription: "Claude Code 请求执行命令:\n\nnpm install react-native-vector-icons\n\n此命令将安装图标库到您的项目中。"
                ))
                // 更新状态为等待权限
                chatStatus = .permissionPending
                sessionStore.sessionStatuses[sessionId] = .permissionPending

            } else if sessionId == "session-2" && !hasQuestionMessage {
                // 添加问题消息
                sessionStore.addMessage(sessionId, Message(
                    id: "msg-question-1",
                    type: .question,
                    content: "请选择您想要使用的认证方式：",
                    timestamp: Date(),
                    questionId: "q-1",
                    options: [
                        "JWT (JSON Web Token)",
                        "OAuth 2.0",
                        "Session Cookie"
                    ]
                ))
                // 更新状态为等待回答
                chatStatus = .questionPending
                sessionStore.sessionStatuses[sessionId] = .questionPending

            } else if sessionId == "session-3" && !hasTaskListMessage {
                // 添加任务列表示例
                let tasks = [
                    TaskItem(id: "t1", content: "分析当前查询结构", status: .completed),
                    TaskItem(id: "t2", content: "检查索引配置", status: .completed),
                    TaskItem(id: "t3", content: "添加 users 表 email 索引", status: .inProgress),
                    TaskItem(id: "t4", content: "添加订单复合索引", status: .pending),
                    TaskItem(id: "t5", content: "修复 N+1 查询问题", status: .pending)
                ]
                sessionStore.addMessage(sessionId, Message(
                    id: "msg-tasklist-1",
                    type: .taskList,
                    content: "",
                    timestamp: Date(),
                    tasks: tasks
                ))

                // 发送常驻任务通知
                Task {
                    await NotificationService.shared.updateTaskListNotification(
                        sessionId: sessionId,
                        sessionTitle: session?.title ?? "任务",
                        tasks: tasks
                    )
                }
            }
        }
        .onChange(of: messages) { _, newMessages in
            // 监听消息变化，更新任务通知
            updateTaskNotification(newMessages)
        }
        .onChange(of: chatStatus) { oldStatus, newStatus in
            // 当状态变为完成时，发送通知
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
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
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: allMessages.count) { _, _ in
                if let firstId = allMessages.first?.id {
                    withAnimation { proxy.scrollTo(firstId, anchor: .bottom) }
                }
            }
        }
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
        // 获取最后一条助手消息作为通知内容
        guard let lastAssistantMessage = messages.last(where: { $0.type == .assistantText }) else { return }

        Task {
            await NotificationService.shared.sendCompletionNotification(
                title: session?.title ?? "对话完成",
                message: lastAssistantMessage.content
            )
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let content = inputText
        inputText = ""

        // 添加用户消息
        let userMessage = Message(
            id: "user-\(UUID().uuidString)",
            type: .userText,
            content: content,
            timestamp: Date()
        )
        sessionStore.addMessage(sessionId, userMessage)

        // 重置状态
        streamingText = ""
        streamingThinking = ""
        chatStatus = .thinking

        // TODO: 发送到 WebSocket
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
        Text(message.content)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var thinkingBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain")
                Text("思考")
                    .font(.caption)
                    .fontWeight(.medium)
                if message.isStreaming == true {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .foregroundColor(.secondary)

            Text(message.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var toolUseBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                Text(message.toolName ?? "Tool")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                toolStatusBadge
            }

            if let input = message.toolInput, !input.isEmpty {
                Text(formatToolInput(input))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            if let result = message.toolResult {
                Divider()
                Text(result)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(10)
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

#Preview {
    NavigationStack {
        ChatView(sessionId: "test", hideTabBar: .constant(false), animateTabBar: .constant(false))
    }
    .environmentObject(SessionStore())
    .environmentObject(AppState())
}
