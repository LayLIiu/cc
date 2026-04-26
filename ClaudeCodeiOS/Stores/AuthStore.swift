// 认证状态管理

import SwiftUI
import Combine

class AuthStore: ObservableObject {
    // 用户信息
    @Published var user: User?
    @Published var isLoggedIn: Bool = false

    // 服务器配置
    @Published var lanUrl: String {
        didSet { UserDefaults.standard.set(lanUrl, forKey: "lanUrl") }
    }
    @Published var tunnelUrl: String {
        didSet { UserDefaults.standard.set(tunnelUrl, forKey: "tunnelUrl") }
    }
    @Published var serverMode: ServerMode {
        didSet { UserDefaults.standard.set(serverMode.rawValue, forKey: "serverMode") }
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
        // 恢复保存的设置
        self.lanUrl = UserDefaults.standard.string(forKey: "lanUrl") ?? ""
        self.tunnelUrl = UserDefaults.standard.string(forKey: "tunnelUrl") ?? ""
        let savedMode = UserDefaults.standard.string(forKey: "serverMode") ?? "lan"
        self.serverMode = ServerMode(rawValue: savedMode) ?? .lan

        // 检查登录状态
        checkLoginStatus()
    }

    private func checkLoginStatus() {
        // 如果有保存的用户信息，尝试恢复
        if let userData = UserDefaults.standard.data(forKey: "userData"),
           let savedUser = try? JSONDecoder().decode(User.self, from: userData) {
            self.user = savedUser
            self.isLoggedIn = true
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
