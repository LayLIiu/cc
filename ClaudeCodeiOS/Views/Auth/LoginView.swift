// 登录视图

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var appState: AppState

    @State private var serverUrl = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // 背景 - 统一使用玻璃背景
            Color.clear
                .liquidGlassBackground(isDark: appState.themeMode == .dark || appState.themeMode == .glass)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Logo
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.adaptivePrimary)

                    Text("Claude Code")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.adaptiveText)

                    Text("移动端客户端")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 输入区域
                VStack(spacing: 16) {
                    TextField("服务器地址", text: $serverUrl)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textContentType(.URL)

                    Text("输入桌面端的服务器地址，例如：http://192.168.1.100:3456")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                // 错误提示
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // 连接按钮
                Button {
                    connect()
                } label: {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("连接")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.adaptivePrimary)
                    .cornerRadius(12)
                }
                .disabled(serverUrl.isEmpty || isConnecting)
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.top, 100)
        }
    }

    private func connect() {
        guard !serverUrl.isEmpty else { return }

        isConnecting = true
        errorMessage = nil

        // 格式化URL
        var url = serverUrl.trimmingCharacters(in: .whitespaces)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "http://" + url
        }

        Task {
            do {
                // 设置 API 服务地址
                APIService.shared.setBaseUrl(url)

                // 验证连接 - 获取网络信息
                let networkInfo = try await APIService.shared.getNetworkInfo()

                await MainActor.run {
                    // 保存 URL
                    authStore.setLanUrl(url)

                    // 如果有隧道地址，也保存
                    if let tunnelUrl = networkInfo.tunnelUrl, !tunnelUrl.isEmpty {
                        authStore.setTunnelUrl(tunnelUrl)
                    }

                    // 登录成功
                    let user = User(id: "1", name: "用户", email: nil)
                    authStore.login(user: user)
                    isConnecting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "连接失败：\(error.localizedDescription)"
                    isConnecting = false
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthStore())
        .environmentObject(AppState())
}
