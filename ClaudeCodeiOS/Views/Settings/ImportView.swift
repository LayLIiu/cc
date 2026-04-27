// 导入对话视图

import SwiftUI

struct ImportView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var authStore: AuthStore
    @Environment(\.dismiss) var dismiss

    @State private var serverSessions: [Session] = []
    @State private var isLoading = true
    @State private var selectedIds: Set<String> = []
    @State private var isImporting = false
    @State private var importProgress: String = ""
    @State private var errorMessage: String?

    // 本地已有的会话 ID
    private var localSessionIds: Set<String> {
        Set(sessionStore.sessions.map { $0.id })
    }

    // 未导入的数量
    private var notImportedCount: Int {
        serverSessions.filter { !localSessionIds.contains($0.id) }.count
    }

    var body: some View {
        ZStack {
            Color.clear
                .liquidGlassBackground(isDark: false)
                .ignoresSafeArea()

            if isLoading {
                loadingView
            } else {
                contentView
            }
        }
        .navigationTitle("导入对话")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleSelectAll()
                } label: {
                    Text(selectedIds.count == notImportedCount ? "取消" : "全选")
                        .font(.subheadline)
                }
                .disabled(serverSessions.isEmpty)
            }
        }
        .task {
            await loadServerSessions()
        }
        .alert("错误", isPresented: .constant(errorMessage != nil)) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 加载中

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在加载服务器对话列表...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 内容视图

    private var contentView: some View {
        VStack(spacing: 0) {
            // 服务器信息
            serverInfoBar

            // 统计栏
            statsBar

            // 列表
            if serverSessions.isEmpty {
                emptyView
            } else {
                sessionList
            }

            // 底部操作栏
            footerBar
        }
    }

    // MARK: - 服务器信息

    private var serverInfoBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("服务器:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(authStore.serverUrl)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
    }

    // MARK: - 统计栏

    private var statsBar: some View {
        HStack {
            Text("共 \(serverSessions.count) 个对话，\(notImportedCount) 个未导入")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 空视图

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))
            Text("暂无可导入的对话")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                Task { await loadServerSessions() }
            } label: {
                Text("重新加载")
                    .font(.subheadline)
                    .foregroundColor(.adaptivePrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 会话列表

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(serverSessions) { session in
                    sessionRow(session)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        let isSelected = selectedIds.contains(session.id)
        let isImported = localSessionIds.contains(session.id)

        return Button {
            if !isImported {
                toggleSelection(session.id)
            }
        } label: {
            HStack(spacing: 12) {
                // 选择框
                if isImported {
                    Text("已导入")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(6)
                } else {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.adaptivePrimary : Color.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.adaptivePrimary))
                        }
                    }
                }

                // 会话信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title.isEmpty ? "新对话" : session.title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if !projectName(session.projectPath).isEmpty {
                            Text(projectName(session.projectPath))
                                .font(.caption)
                                .foregroundColor(.adaptivePrimary)
                        }
                        Text(formatDate(session.modifiedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(session.messageCount) 条消息")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.adaptivePrimary.opacity(0.08) : Color.secondary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.adaptivePrimary.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(isImported ? 0.6 : 1.0)
        .disabled(isImported)
    }

    // MARK: - 底部操作栏

    private var footerBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("已选择 \(selectedIds.count) 个对话")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    handleImport()
                } label: {
                    HStack(spacing: 6) {
                        if isImporting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        }
                        Text(isImporting ? importProgress : "导入选中")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        selectedIds.isEmpty ? Color.secondary.opacity(0.3) : Color.adaptivePrimary
                    )
                    .cornerRadius(10)
                }
                .disabled(selectedIds.isEmpty || isImporting)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - 方法

    private func loadServerSessions() async {
        isLoading = true
        do {
            let sessions = try await APIService.shared.getSessions()
            serverSessions = sessions
        } catch {
            errorMessage = "无法连接服务器，请检查网络设置"
        }
        isLoading = false
    }

    private func toggleSelection(_ sessionId: String) {
        if selectedIds.contains(sessionId) {
            selectedIds.remove(sessionId)
        } else {
            selectedIds.insert(sessionId)
        }
    }

    private func toggleSelectAll() {
        let notImported = serverSessions.filter { !localSessionIds.contains($0.id) }
        if selectedIds.count == notImported.count {
            selectedIds.removeAll()
        } else {
            selectedIds = Set(notImported.map { $0.id })
        }
    }

    private func handleImport() {
        guard !selectedIds.isEmpty else { return }
        isImporting = true

        Task {
            let selectedSessions = serverSessions.filter { selectedIds.contains($0.id) }
            let (count, error) = await sessionStore.importSessions(
                Array(selectedIds),
                selectedSessions
            ) { imported, total in
                importProgress = "\(imported)/\(total)"
            }

            isImporting = false
            importProgress = ""

            if let error = error {
                errorMessage = error
            } else {
                dismiss()
            }
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateStr) else { return dateStr }

        let display = DateFormatter()
        display.locale = Locale(identifier: "zh_CN")
        display.dateFormat = "M月d日 HH:mm"
        return display.string(from: date)
    }

    private func projectName(_ path: String) -> String {
        let parts = path.replacingOccurrences(of: "^-", with: "", options: .regularExpression)
            .components(separatedBy: "-")
        return parts.last ?? path
    }
}

#Preview {
    NavigationStack {
        ImportView()
            .environmentObject(SessionStore())
            .environmentObject(AuthStore())
    }
}
