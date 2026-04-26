// 全局应用状态管理

import SwiftUI
import Combine

// 模型结构体
struct Model {
    let id: String
    let name: String
}

class AppState: ObservableObject {
    // 主题模式
    @Published var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
        }
    }

    // 当前模型
    @Published var currentModel: Model? {
        didSet {
            if let model = currentModel {
                UserDefaults.standard.set(model.id, forKey: "currentModelId")
            }
        }
    }

    // 思考强度
    @Published var effortLevel: String {
        didSet {
            UserDefaults.standard.set(effortLevel, forKey: "effortLevel")
        }
    }

    // 待导航的会话ID（用于通知点击跳转）
    @Published var pendingNavigateToSession: String?

    // 计算当前应该使用的颜色方案
    var colorScheme: ColorScheme? {
        switch themeMode {
        case .light:
            return .light
        case .dark, .glass:
            return .dark
        case .system:
            return nil // 跟随系统
        }
    }

    // 是否为玻璃模式
    var isGlassMode: Bool {
        themeMode == .glass
    }

    init() {
        // 从 UserDefaults 恢复主题设置
        if let savedMode = UserDefaults.standard.string(forKey: "themeMode"),
           let mode = ThemeMode(rawValue: savedMode) {
            self.themeMode = mode
        } else {
            self.themeMode = .system
        }

        // 恢复模型设置
        if let savedModelId = UserDefaults.standard.string(forKey: "currentModelId") {
            let models = [
                Model(id: "claude-opus-4-7", name: "Claude Opus 4"),
                Model(id: "claude-sonnet-4-6", name: "Claude Sonnet 4"),
                Model(id: "claude-haiku-4-5", name: "Claude Haiku 4"),
            ]
            self.currentModel = models.first { $0.id == savedModelId } ?? models[1]
        } else {
            self.currentModel = Model(id: "claude-sonnet-4-6", name: "Claude Sonnet 4")
        }

        // 恢复思考强度
        if let savedEffort = UserDefaults.standard.string(forKey: "effortLevel") {
            self.effortLevel = savedEffort
        } else {
            self.effortLevel = "medium"
        }
    }

    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
    }

    func setCurrentModel(_ model: Model) {
        currentModel = model
    }

    func setEffortLevel(_ level: String) {
        effortLevel = level
    }
}
