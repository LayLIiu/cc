// 认证状态管理

import SwiftUI
import Combine

class AuthStore: ObservableObject {
    // 用户信息
    @Published var user: User?
    @Published var isLoggedIn: Bool = false

    // 服务器配置
    @Published var lanUrl: String = "" {
        didSet { saveAndSync() }
    }
    @Published var tunnelUrl: String = "" {
        didSet { saveAndSync() }
    }
    @Published var serverMode: ServerMode = .lan {
        didSet { saveAndSync() }
    }

    // 当前使用的服务器地址
    var serverUrl: String {
        switch serverMode {
        case .lan:
            return lanUrl
        case .tunnel:
            return tunnelUrl
        }
    }

    init() {
        // 恢复保存的设置（不触发 didSet）
        var savedLanUrl = UserDefaults.standard.string(forKey: "lanUrl") ?? ""
        var savedTunnelUrl = UserDefaults.standard.string(forKey: "tunnelUrl") ?? ""

        // 修正错误的 URL 格式（host:port:token -> http://host:port）
        savedLanUrl = Self.normalizeUrl(savedLanUrl)
        savedTunnelUrl = Self.normalizeUrl(savedTunnelUrl)

        _lanUrl = Published(initialValue: savedLanUrl)
        _tunnelUrl = Published(initialValue: savedTunnelUrl)

        let savedMode = UserDefaults.standard.string(forKey: "serverMode") ?? "lan"
        _serverMode = Published(initialValue: ServerMode(rawValue: savedMode) ?? .lan)

        // 检查登录状态
        checkLoginStatus()

        // 更新 API 服务地址
        updateApiServiceUrl()
    }

    /// 标准化 URL 格式，处理 host:port:token 格式
    private static func normalizeUrl(_ url: String) -> String {
        guard !url.isEmpty else { return url }

        // 移除协议前缀
        var processed = url
        if processed.hasPrefix("https://") {
            processed = String(processed.dropFirst(8))
        } else if processed.hasPrefix("http://") {
            processed = String(processed.dropFirst(7))
        }

        // 检查是否是 host:port:token 格式（多于一个冒号）
        let colonCount = processed.filter { $0 == ":" }.count
        if colonCount >= 2 {
            let parts = processed.split(separator: ":")
            if parts.count >= 2 {
                let host = String(parts[0])
                let port = String(parts[1])
                // 判断是否是 tunnel URL
                let isTunnel = host.contains(".tunnel.") ||
                               host.contains("trycloudflare") ||
                               host.contains("loca.lt")
                let normalized = isTunnel ? "https://\(host):\(port)" : "http://\(host):\(port)"
                print("[AuthStore] 🔧 Normalized URL from '\(url)' to '\(normalized)'")
                return normalized
            }
        }

        // 如果没有协议前缀，添加一个
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            let isTunnel = url.contains(".tunnel.") ||
                           url.contains("trycloudflare") ||
                           url.contains("loca.lt")
            return isTunnel ? "https://\(url)" : "http://\(url)"
        }

        return url
    }

    private func checkLoginStatus() {
        // 如果有保存的用户信息，尝试恢复
        if let userData = UserDefaults.standard.data(forKey: "userData"),
           let savedUser = try? JSONDecoder().decode(User.self, from: userData) {
            self.user = savedUser
            self.isLoggedIn = true
        }
    }

    private func saveAndSync() {
        UserDefaults.standard.set(lanUrl, forKey: "lanUrl")
        UserDefaults.standard.set(tunnelUrl, forKey: "tunnelUrl")
        UserDefaults.standard.set(serverMode.rawValue, forKey: "serverMode")
        updateApiServiceUrl()
    }

    private func updateApiServiceUrl() {
        let url = serverUrl
        if !url.isEmpty {
            APIService.shared.setBaseUrl(url)
        }
    }

    func login(user: User) {
        self.user = user
        self.isLoggedIn = true
        // 保存用户信息
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "userData")
        }
    }

    func logout() {
        self.user = nil
        self.isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: "userData")
    }

    func setLanUrl(_ url: String) {
        lanUrl = url
    }

    func setTunnelUrl(_ url: String) {
        tunnelUrl = url
    }

    func setServerMode(_ mode: ServerMode) {
        serverMode = mode
    }
}

// 服务器模式
enum ServerMode: String {
    case lan
    case tunnel
}
