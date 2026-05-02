// 会话列表视图

import SwiftUI

struct SessionsView: View {
    @Binding var hideTabBar: Bool
    @Binding var animateTabBar: Bool
    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var appState: AppState

    @State private var showNewSessionModal = false
    @State private var customPath = ""
    @State private var navigateToChat: String?
    @State private var searchText = ""

    // 搜索过滤后的会话
    var filteredSessions: [(title: String, sessions: [Session])] {
        if searchText.isEmpty {
            return sessionStore.groupedSessions
        }
        return sessionStore.groupedSessions.compactMap { group in
            let filtered = group.sessions.filter { session in
                session.title.localizedCaseInsensitiveContains(searchText) ||
                session.projectPath.localizedCaseInsensitiveContains(searchText)
            }
            return filtered.isEmpty ? nil : (group.title, filtered)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景 - 统一使用玻璃背景
                Color.clear
                    .liquidGlassBackground(isDark: appState.themeMode == .dark || appState.themeMode == .glass)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 标题栏
                    HStack {
                        Spacer()
                        Text("Claude Code")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.adaptiveText)
                        Spacer()
                    }
                    .overlay(
                        Button {
                            showNewSessionModal = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.adaptivePrimary)
                        }
                        , alignment: .trailing
                    )
                    .padding(.horizontal, 16)

                    // 搜索框
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("搜索对话...", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    if sessionStore.isLoading && sessionStore.sessions.isEmpty {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if let error = sessionStore.error, sessionStore.sessions.isEmpty {
                        Spacer()
                        ErrorView(
                            error: error,
                            onRetry: {
                                Task { await sessionStore.fetchSessions() }
                            }
                        )
                        Spacer()
                    } else {
                        sessionList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showNewSessionModal) {
                NewSessionSheet(customPath: $customPath)
            }
            .navigationDestination(item: $navigateToChat) { sessionId in
                ChatView(sessionId: sessionId, hideTabBar: $hideTabBar, animateTabBar: $animateTabBar)
            }
        }
        .task {
            await sessionStore.fetchSessions()
        }
        // 定期刷新会话列表（每 30 秒）以同步标题
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            Task { await sessionStore.fetchSessions() }
        }
        .onChange(of: appState.pendingNavigateToSession) { _, newSessionId in
            // 监听通知点击，导航到对应会话
            if let sessionId = newSessionId {
                navigateToChat = sessionId
                appState.pendingNavigateToSession = nil
            }
        }
    }

    private var sessionList: some View {
        List {
            ForEach(filteredSessions, id: \.title) { group in
                Section(header: Text(group.title).font(.caption).fontWeight(.semibold)) {
                    ForEach(group.sessions) { session in
                        SessionRowView(
                            session: session,
                            status: sessionStore.sessionStatuses[session.id],
                            onTap: { navigateToChat = session.id },
                            onRename: { newTitle in
                                Task { await sessionStore.renameSession(session.id, newTitle: newTitle) }
                            },
                            onDelete: {
                                sessionStore.deleteLocalSession(session.id)
                            }
                        )
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await sessionStore.fetchSessions()
        }
    }
}

// MARK: - 会话行视图（用于 List）

struct SessionRowView: View {
    let session: Session
    let status: SessionStatus?
    let onTap: () -> Void
    var onRename: ((String) -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var showRenameSheet = false
    @State private var showDeleteConfirm = false
    @State private var newTitle = ""
    @EnvironmentObject var appState: AppState

    // 随机颜色列表
    private let mascotColors: [Color] = [
        Color(hex: "E86B4A"),
        Color(hex: "2ECC71"),
        Color(hex: "9B59B6"),
        Color(hex: "E67E22"),
        Color(hex: "3498DB"),
        Color(hex: "E91E63"),
        Color(hex: "1ABC9C"),
        Color(hex: "F39C12"),
    ]

    private var mascotColor: Color {
        let hash = abs(session.id.hashValue)
        return mascotColors[hash % mascotColors.count]
    }

    private var statusText: String? {
        switch status {
        case .thinking: return "思考中"
        case .streaming: return "工作中"
        case .toolExecuting: return "执行中"
        case .permissionPending: return "等待权限"
        case .questionPending: return "等待回答"
        case .completed: return "已完成"
        case .idle, .none: return nil
        }
    }

    private var statusColor: Color {
        switch status {
        case .thinking, .streaming, .toolExecuting: return .green
        case .permissionPending, .questionPending: return .orange
        case .completed: return .green
        case .idle, .none: return .secondary
        }
    }

    private var mascotStatus: MascotStatus {
        switch status {
        case .thinking, .streaming, .toolExecuting: return .processing
        case .permissionPending, .questionPending: return .waitingApproval
        case .completed: return .completed
        case .idle, .none: return .idle
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                PixelMascot(size: 32, status: mascotStatus, bodyColor: mascotColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.headline)
                        .foregroundColor(.adaptiveText)
                        .lineLimit(1)

                    if !session.projectPath.isEmpty {
                        Text(session.projectPath)
                            .font(.caption)
                            .foregroundColor(.adaptiveTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let text = statusText {
                    Text(text)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.secondary.opacity(0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("移除", systemImage: "trash")
                }
            }

            if onRename != nil {
                Button {
                    newTitle = session.title
                    showRenameSheet = true
                } label: {
                    Label("重命名", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
        .alert("从本地移除对话？", isPresented: $showDeleteConfirm) {
            Button("移除", role: .destructive) {
                onDelete?()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作只会从本机移除对话，不会删除服务器上的数据。你可以稍后通过导入会话重新导入。")
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameSheet(
                title: $newTitle,
                onConfirm: {
                    if !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        onRename?(newTitle.trimmingCharacters(in: .whitespaces))
                    }
                }
            )
        }
        .listRowSeparator(.hidden)
    }
}

// MARK: - 会话分组视图（保留兼容）

struct SessionGroupView: View {
    let title: String
    let sessions: [Session]
    let onSelect: (Session) -> Void
    let onDelete: (Session) -> Void

    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveTextSecondary)
                .padding(.leading, 4)

            VStack(spacing: 8) {
                ForEach(sessions) { session in
                    SessionItemView(
                        session: session,
                        status: sessionStore.sessionStatuses[session.id],
                        onTap: { onSelect(session) },
                        onRename: { newTitle in
                            Task { await sessionStore.renameSession(session.id, newTitle: newTitle) }
                        }
                    )
                    .liquidGlass(cornerRadius: 18, isDark: appState.themeMode == .dark || appState.themeMode == .glass)
                }
            }
        }
    }
}

// MARK: - 会话项视图

struct SessionItemView: View {
    let session: Session
    let status: SessionStatus?
    let onTap: () -> Void
    var onRename: ((String) -> Void)? = nil

    @State private var showDeleteConfirm = false
    @State private var showRenameSheet = false
    @State private var newTitle = ""

    // 随机颜色列表 - 高饱和度
    private let mascotColors: [Color] = [
        Color(hex: "E86B4A"), // 鲜橙色
        Color(hex: "2ECC71"), // 翠绿色
        Color(hex: "9B59B6"), // 紫色
        Color(hex: "E67E22"), // 橙色
        Color(hex: "3498DB"), // 蓝色
        Color(hex: "E91E63"), // 粉红色
        Color(hex: "1ABC9C"), // 青色
        Color(hex: "F39C12"), // 金色
    ]

    // 根据会话 ID 生成固定颜色
    private var mascotColor: Color {
        let hash = abs(session.id.hashValue)
        return mascotColors[hash % mascotColors.count]
    }

    // 状态文字
    private var statusText: String? {
        switch status {
        case .thinking:
            return "思考中"
        case .streaming:
            return "工作中"
        case .toolExecuting:
            return "执行中"
        case .permissionPending:
            return "等待权限"
        case .questionPending:
            return "等待回答"
        case .completed:
            return "已完成"
        case .idle, .none:
            return nil
        }
    }

    // 状态颜色
    private var statusColor: Color {
        switch status {
        case .thinking, .streaming, .toolExecuting:
            return .green
        case .permissionPending, .questionPending:
            return .orange
        case .completed:
            return .green
        case .idle, .none:
            return .secondary
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 左边：像素吉祥物 - 显示工作状态
                PixelMascot(size: 32, status: mascotStatus, bodyColor: mascotColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.headline)
                        .foregroundColor(.adaptiveText)
                        .lineLimit(1)

                    if !session.projectPath.isEmpty {
                        Text(session.projectPath)
                            .font(.caption)
                            .foregroundColor(.adaptiveTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // 右边：状态文字
                if let text = statusText {
                    Text(text)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除", systemImage: "trash")
            }

            if onRename != nil {
                Button {
                    newTitle = session.title
                    showRenameSheet = true
                } label: {
                    Label("重命名", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
        .confirmationDialog("确定删除此对话？", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                // onDelete
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameSheet(
                title: $newTitle,
                onConfirm: {
                    if !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        onRename?(newTitle.trimmingCharacters(in: .whitespaces))
                    }
                }
            )
        }
    }

    private var mascotStatus: MascotStatus {
        switch status {
        case .thinking, .streaming, .toolExecuting:
            return .processing
        case .permissionPending, .questionPending:
            return .waitingApproval
        case .completed:
            return .completed
        case .idle, .none:
            return .idle
        }
    }
}

// MARK: - 新建会话弹窗

struct NewSessionSheet: View {
    @Binding var customPath: String
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("自定义项目路径") {
                    TextField("例如: /Users/xxx/projects/my-project", text: $customPath)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("创建对话") {
                        Task {
                            if let sessionId = await sessionStore.createSession(projectPath: customPath.isEmpty ? nil : customPath) {
                                // 导航到聊天页面
                            }
                            dismiss()
                        }
                    }
                    .disabled(customPath.isEmpty && sessionStore.recentProjects.isEmpty)
                }

                if !sessionStore.recentProjects.isEmpty {
                    Section("最近项目") {
                        ForEach(sessionStore.recentProjects, id: \.projectPath) { project in
                            Button {
                                Task {
                                    if let sessionId = await sessionStore.createSession(projectPath: project.realPath) {
                                        // 导航
                                    }
                                    dismiss()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.projectName)
                                        .font(.headline)
                                    Text(project.projectPath)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if project.isGit, let repoName = project.repoName, let branch = project.branch {
                                        Text("\(repoName) (\(branch))")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("新建对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("取消")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 错误视图

struct ErrorView: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("无法连接服务器")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("重试") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - 上下文环形进度条

struct ContextRingView: View {
    let percentage: Int
    var size: CGFloat = 20
    var strokeWidth: CGFloat = 2

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: CGFloat(percentage) / 100)
                .stroke(
                    colorForPercentage(percentage),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: percentage)
        }
        .frame(width: size, height: size)
    }

    private func colorForPercentage(_ p: Int) -> Color {
        if p < 50 { return .green }
        if p < 75 { return .yellow }
        if p < 90 { return .orange }
        return .red
    }
}

// MARK: - 重命名弹窗

struct RenameSheet: View {
    @Binding var title: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("新标题") {
                    TextField("输入新标题", text: $title)
                        .focused($isFocused)
                }
            }
            .navigationTitle("重命名对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        onConfirm()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { isFocused = true }
        .presentationDetents([.height(200)])
    }
}

#Preview {
    SessionsView(hideTabBar: .constant(false), animateTabBar: .constant(false))
        .environmentObject(SessionStore())
        .environmentObject(AuthStore())
        .environmentObject(AppState())
}
