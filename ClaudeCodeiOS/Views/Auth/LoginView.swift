// 登录视图

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var appState: AppState

    @State private var mode: ConnectionMode = .pairing
    @State private var pairingCode = ""
    @State private var serverUrl = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    enum ConnectionMode {
        case pairing
        case manual
    }

    var body: some View {
        ZStack {
            // 背景 - 统一使用玻璃背景
            Color.clear
                .liquidGlassBackground(isDark: appState.themeMode == .dark || appState.themeMode == .glass)
                .ignoresSafeArea()

            ScrollView {
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

                        Text("移动端助手")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)

                    // 模式切换
                    HStack(spacing: 0) {
                        Button {
                            mode = .pairing
                        } label: {
                            Text("配对码连接")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(mode == .pairing ? .adaptivePrimary : .secondary)
                        }
                        .background(mode == .pairing ? Color.adaptivePrimary.opacity(0.1) : Color.clear)
                        .cornerRadius(8)

                        Button {
                            mode = .manual
                        } label: {
                            Text("手动输入")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(mode == .manual ? .adaptivePrimary : .secondary)
                        }
                        .background(mode == .manual ? Color.adaptivePrimary.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 32)

                    // 输入区域
                    if mode == .pairing {
                        pairingInputView
                    } else {
                        manualInputView
                    }

                    // 使用说明
                    instructionsView

                    Spacer()
                }
            }
        }
    }

    // MARK: - 配对码输入

    private var pairingInputView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("配对码")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.adaptiveText)

                TextField("粘贴连接串或 IP:端口:配对码", text: $pairingCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.body)
            }
            .padding(.horizontal, 32)

            Text("支持局域网或公网隧道连接，在桌面端获取配对码")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // 错误提示
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // 连接按钮
            Button {
                connectWithPairingCode()
            } label: {
                HStack {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("配对连接")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.adaptivePrimary)
                .cornerRadius(12)
            }
            .disabled(pairingCode.isEmpty || isConnecting)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - 手动输入

    private var manualInputView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("服务器地址")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.adaptiveText)

                TextField("http://192.168.1.100:3456", text: $serverUrl)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .font(.body)
            }
            .padding(.horizontal, 32)

            Text("请输入桌面端服务地址（确保手机和电脑在同一网络）")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // 错误提示
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // 连接按钮
            Button {
                connectManual()
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
        }
    }

    // MARK: - 使用说明

    private var instructionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("使用步骤")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveText)

            instructionStep(number: 1, text: "在电脑上启动 Claude Code 桌面应用")
            instructionStep(number: 2, text: "设置 → IM 接入 → 生成配对码")
            instructionStep(number: 3, text: "局域网：输入 IP:端口:配对码")
            instructionStep(number: 4, text: "公网：粘贴完整连接串")
        }
        .padding(20)
        .background(Color.adaptiveSurface)
        .cornerRadius(12)
        .padding(.horizontal, 32)
    }

    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.adaptivePrimary)
                .clipShape(Circle())

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 配对码连接

    private func connectWithPairingCode() {
        let input = pairingCode.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return }

        isConnecting = true
        errorMessage = nil

        var serverAddr: String
        var code: String

        // 解析格式
        // 格式1: 公网隧道 URL + 双冒号分隔码 (推荐)
        // 例如: https://xxx.trycloudflare.com::ABC123
        if input.contains("::") {
            let parts = input.components(separatedBy: "::")
            serverAddr = parts[0].trimmingCharacters(in: .whitespaces)
            code = parts.count > 1 ? parts[1].uppercased() : ""
        }
        // 格式2: 公网隧道 URL + 单冒号分隔码
        // 例如: https://xxx.trycloudflare.com:ABC123
        else if input.hasPrefix("https://") || input.hasPrefix("http://") {
            if let lastColon = input.lastIndex(of: ":"),
               input.distance(from: input.startIndex, to: lastColon) > 8 {
                serverAddr = String(input[..<lastColon])
                code = String(input[input.index(after: lastColon)...]).uppercased()
            } else {
                errorMessage = "公网地址格式错误\n请使用: https://xxx.trycloudflare.com:ABC123"
                isConnecting = false
                return
            }
        }
        // 格式3: 局域网地址 host:port:code
        // 例如: 192.168.1.100:3456:ABC123
        else {
            let parts = input.components(separatedBy: ":")
            if parts.count == 3 {
                serverAddr = "http://\(parts[0]):\(parts[1])"
                code = parts[2].uppercased()
            } else {
                errorMessage = "配对码格式错误\n局域网: 192.168.1.100:3456:ABC123\n公网: https://xxx.trycloudflare.com:ABC123"
                isConnecting = false
                return
            }
        }

        guard code.count >= 4 else {
            errorMessage = "配对码无效，请检查格式"
            isConnecting = false
            return
        }

        print("[Login] Connecting to: \(serverAddr) with code: \(code)")

        Task {
            do {
                // 设置 API 服务地址
                APIService.shared.setBaseUrl(serverAddr)

                // 验证配对码
                guard let url = URL(string: "\(serverAddr)/api/mobile/pair") else {
                    await MainActor.run {
                        errorMessage = "无效的服务器地址"
                        isConnecting = false
                    }
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: ["code": code])

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    await MainActor.run {
                        // 保存服务器地址
                        if serverAddr.hasPrefix("https://") {
                            authStore.setTunnelUrl(serverAddr)
                        } else {
                            authStore.setLanUrl(serverAddr)
                        }

                        // 登录成功
                        let user = User(id: "1", name: "用户", email: nil)
                        authStore.login(user: user)
                        isConnecting = false
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "配对失败，请检查配对码是否正确"
                        isConnecting = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "连接失败：\(error.localizedDescription)"
                    isConnecting = false
                }
            }
        }
    }

    // MARK: - 手动连接

    private func connectManual() {
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
