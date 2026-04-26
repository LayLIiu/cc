// 设置视图

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionStore: SessionStore

    @State private var showLanModal = false
    @State private var showTunnelModal = false
    @State private var showThemeModal = false
    @State private var showLogoutConfirm = false
    @State private var tempUrl = ""
    @State private var testingLatency = false
    @State private var latency: Int?

    private let appVersion = "1.0.0"
    private let buildTime = "2026-04-26"

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景 - 统一使用玻璃背景
                Color.clear
                    .liquidGlassBackground(isDark: appState.themeMode == .dark || appState.themeMode == .glass)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 标题
                        Text("设置")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.adaptiveText)
                            .frame(maxWidth: .infinity)

                        // 账户
                        accountSection

                        // 连接
                        connectionSection

                        // 外观
                        appearanceSection

                        // 数据管理
                        dataSection

                        // 关于
                        aboutSection

                        // 退出登录
                        logoutButton

                        // 底部信息
                        footerView
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showLanModal) {
            UrlEditSheet(
                title: "局域网地址",
                placeholder: "http://192.168.x.x:3456",
                url: $tempUrl,
                onSave: {
                    authStore.setLanUrl(tempUrl)
                    showLanModal = false
                }
            )
        }
        .sheet(isPresented: $showTunnelModal) {
            UrlEditSheet(
                title: "公网地址",
                placeholder: "https://xxx.trycloudflare.com",
                url: $tempUrl,
                onSave: {
                    authStore.setTunnelUrl(tempUrl)
                    showTunnelModal = false
                }
            )
        }
        .sheet(isPresented: $showThemeModal) {
            ThemeSelectionSheet()
        }
        .confirmationDialog("确定退出登录？", isPresented: $showLogoutConfirm) {
            Button("退出", role: .destructive) {
                authStore.logout()
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 账户

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("账户")

            HStack {
                Text("用户")
                    .font(.subheadline)
                Spacer()
                Text(authStore.user?.name ?? "未登录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .liquidGlass(cornerRadius: 6, isDark: appState.themeMode == .dark || appState.themeMode == .glass)
        }
    }

    // MARK: - 连接设置

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("连接")

            VStack(spacing: 8) {
                // 网络模式切换
                HStack {
                    Text("当前网络")
                        .font(.subheadline)

                    Spacer()

                    NetworkModeSlider(
                        mode: $authStore.serverMode,
                        lanEnabled: !authStore.lanUrl.isEmpty,
                        tunnelEnabled: !authStore.tunnelUrl.isEmpty
                    )
                }
                .padding(12)
                .liquidGlass(cornerRadius: 8, isDark: appState.themeMode == .dark || appState.themeMode == .glass)

                // 局域网地址
                Button {
                    tempUrl = authStore.lanUrl
                    showLanModal = true
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("局域网地址")
                                .font(.subheadline)
                            Text(authStore.lanUrl.isEmpty ? "未设置" : authStore.lanUrl)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("编辑")
                            .font(.caption)
                            .foregroundColor(.adaptivePrimary)
                    }
                }
                .padding(12)
                .liquidGlass(cornerRadius: 8, isDark: appState.themeMode == .dark || appState.themeMode == .glass)

                // 公网地址
                Button {
                    tempUrl = authStore.tunnelUrl
                    showTunnelModal = true
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("公网地址")
                                .font(.subheadline)
                            Text(authStore.tunnelUrl.isEmpty ? "未设置" : authStore.tunnelUrl)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("编辑")
                            .font(.caption)
                            .foregroundColor(.adaptivePrimary)
                    }
                }
                .padding(12)
                .liquidGlass(cornerRadius: 8, isDark: appState.themeMode == .dark || appState.themeMode == .glass)

                // 当前地址
                HStack {
                    Text("当前地址")
                        .font(.subheadline)
                    Spacer()
                    Text(authStore.serverUrl.isEmpty ? "未设置" : authStore.serverUrl)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .liquidGlass(cornerRadius: 8, isDark: appState.themeMode == .dark || appState.themeMode == .glass)

                // 连接速度
                Button {
                    testLatency()
                } label: {
                    HStack {
                        Text("连接速度")
                            .font(.subheadline)

                        Spacer()

                        if testingLatency {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if let latency = latency {
                            Text(formatLatency(latency))
                                .font(.caption)
                                .foregroundColor(latencyColor(latency))
                        } else {
                            Text("点击测试")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .liquidGlass(cornerRadius: 8, isDark: appState.themeMode == .dark || appState.themeMode == .glass)
                .disabled(testingLatency || authStore.serverUrl.isEmpty)
            }

            Text("局域网适合在家使用，公网适合外出使用")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 外观设置

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("外观")

            Button {
                showThemeModal = true
            } label: {
                HStack {
                    Text("主题")
                        .font(.subheadline)
                    Spacer()
                    Text(appState.themeMode.label)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .liquidGlass(cornerRadius: 6, isDark: appState.themeMode == .dark || appState.themeMode == .glass)
            }
        }
    }

    // MARK: - 数据管理

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("数据管理")

            Button {
                // 导入对话
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                        .foregroundColor(.adaptivePrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.adaptivePrimary.opacity(0.1))
                        .cornerRadius(8)

                    VStack(alignment: .leading) {
                        Text("导入对话")
                            .font(.subheadline)
                        Text("从 Cloud Code 导入对话到本地")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .liquidGlass(cornerRadius: 6, isDark: appState.themeMode == .dark || appState.themeMode == .glass)
            }
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("关于")

            VStack(spacing: 8) {
                HStack {
                    Text("版本")
                        .font(.subheadline)
                    Spacer()
                    Text(appVersion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .liquidGlass(cornerRadius: 8, isDark: appState.themeMode == .dark || appState.themeMode == .glass)

                HStack {
                    Text("构建时间")
                        .font(.subheadline)
                    Spacer()
                    Text(buildTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .liquidGlass(cornerRadius: 8, isDark: appState.themeMode == .dark || appState.themeMode == .glass)

                HStack {
                    Text("主题")
                        .font(.subheadline)
                    Spacer()
                    Text(appState.themeMode.label)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .liquidGlass(cornerRadius: 8, isDark: appState.themeMode == .dark || appState.themeMode == .glass)
            }
        }
    }

    // MARK: - 退出登录

    private var logoutButton: some View {
        Button {
            showLogoutConfirm = true
        } label: {
            Text("退出登录")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
        }
    }

    // MARK: - 底部信息

    private var footerView: some View {
        Text("Claude Code iOS v\(appVersion) (\(buildTime))")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 32)
    }

    // MARK: - 辅助方法

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
    }

    private func testLatency() {
        guard !authStore.serverUrl.isEmpty else { return }
        testingLatency = true

        Task {
            let start = Date()
            // TODO: 实际测试连接
            try? await Task.sleep(nanoseconds: 500_000_000)
            let end = Date()
            let duration = Int(end.timeIntervalSince(start) * 1000)

            await MainActor.run {
                self.latency = duration
                self.testingLatency = false
            }
        }
    }

    private func formatLatency(_ ms: Int) -> String {
        if ms < 100 { return "\(ms)ms (极快)" }
        if ms < 300 { return "\(ms)ms (很快)" }
        if ms < 500 { return "\(ms)ms (较快)" }
        if ms < 1000 { return "\(ms)ms (一般)" }
        return "\(ms)ms (较慢)"
    }

    private func latencyColor(_ ms: Int) -> Color {
        if ms < 100 { return .green }
        if ms < 300 { return .green }
        if ms < 500 { return .yellow }
        return .orange
    }
}

// MARK: - URL 编辑弹窗

struct UrlEditSheet: View {
    let title: String
    let placeholder: String
    @Binding var url: String
    let onSave: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField(placeholder, text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Text("输入桌面端的地址")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .navigationTitle(title)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave()
                        dismiss()
                    } label: {
                        Text("保存")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.adaptivePrimary)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .disabled(url.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 主题选择弹窗

struct ThemeSelectionSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    Button {
                        appState.setThemeMode(mode)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: mode.icon)
                                .frame(width: 28)

                            Text(mode.label)
                                .foregroundColor(.primary)

                            Spacer()

                            if appState.themeMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.adaptivePrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择主题")
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
        .presentationDetents([.medium])
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthStore())
        .environmentObject(AppState())
        .environmentObject(SessionStore())
}

// MARK: - 网络模式滑块

struct NetworkModeSlider: View {
    @Binding var mode: ServerMode
    let lanEnabled: Bool
    let tunnelEnabled: Bool

    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            // 局域网
            networkTab(.lan, label: "局域网", enabled: lanEnabled)

            // 公网
            networkTab(.tunnel, label: "公网", enabled: tunnelEnabled)
        }
        .padding(3)
        .background(Color.secondary.opacity(0.15))
        .cornerRadius(10)
    }

    @ViewBuilder
    private func networkTab(_ targetMode: ServerMode, label: String, enabled: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                mode = targetMode
            }
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(enabled ? (mode == targetMode ? .white : .primary) : .secondary.opacity(0.5))
                .frame(width: 50, height: 26)
                .background {
                    if mode == targetMode && enabled {
                        Capsule()
                            .fill(Color.adaptivePrimary)
                            .matchedGeometryEffect(id: "network_slider", in: animation)
                    }
                }
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }
}
