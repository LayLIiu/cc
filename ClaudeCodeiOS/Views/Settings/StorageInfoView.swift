// 存储管理视图

import SwiftUI

struct StorageInfoView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var appState: AppState

    private var isDark: Bool { appState.themeMode == .dark || appState.themeMode == .glass }

    @State private var totalSize: Int64 = 0
    @State private var messageCount: Int = 0
    @State private var sessionCount: Int = 0
    @State private var isCalculating = true

    var body: some View {
        ZStack {
            Color.clear
                .liquidGlassBackground(isDark: isDark)
                .ignoresSafeArea()

            if isCalculating {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在计算存储空间...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // 总占用
                        totalSizeCard

                        // 明细
                        detailCards

                        // 操作
                        actionsSection
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("存储管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await calculateStorage()
        }
    }

    // MARK: - 总占用

    private var totalSizeCard: some View {
        VStack(spacing: 12) {
            Text(formatSize(totalSize))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.adaptivePrimary)

            Text("本地存储总占用")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 占比条
            GeometryReader { geo in
                let usedRatio = min(Double(totalSize) / (100 * 1024 * 1024), 1.0) // 假设 100MB 为上限
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.adaptivePrimary)
                        .frame(width: geo.size.width * usedRatio, height: 8)
                }
            }
            .frame(height: 8)

            Text("上限参考: 100 MB")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 明细

    private var detailCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("存储明细")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                detailRow(
                    icon: "message.fill",
                    color: .blue,
                    title: "消息数据",
                    detail: "\(messageCount) 条消息"
                )
                detailRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .green,
                    title: "会话数量",
                    detail: "\(sessionCount) 个会话"
                )
                detailRow(
                    icon: "folder.fill",
                    color: .orange,
                    title: "消息缓存",
                    detail: formatSize(messagesDirSize)
                )
            }
        }
    }

    private func detailRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 操作

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("操作")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Button {
                clearMessageCache()
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("清除消息缓存")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Spacer()
                    Text(formatSize(messagesDirSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - 方法

    private var messagesDirSize: Int64 {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let messagesDir = paths[0].appendingPathComponent("messages", isDirectory: true)
        return directorySize(at: messagesDir)
    }

    private func calculateStorage() async {
        isCalculating = true

        // 计算消息目录大小
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let messagesDir = paths[0].appendingPathComponent("messages", isDirectory: true)
        totalSize = directorySize(at: messagesDir)

        // 统计数量
        sessionCount = sessionStore.sessions.count
        messageCount = sessionStore.messages.values.reduce(0) { $0 + $1.count }

        isCalculating = false
    }

    private func directorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    private func clearMessageCache() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let messagesDir = paths[0].appendingPathComponent("messages", isDirectory: true)
        try? FileManager.default.removeItem(at: messagesDir)
        try? FileManager.default.createDirectory(at: messagesDir, withIntermediateDirectories: true)

        for key in sessionStore.messages.keys {
            sessionStore.messages[key] = []
        }

        // 重新计算
        Task {
            await calculateStorage()
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    NavigationStack {
        StorageInfoView()
            .environmentObject(SessionStore())
    }
}
