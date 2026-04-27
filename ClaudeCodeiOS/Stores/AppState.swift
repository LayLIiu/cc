// 全局应用状态管理

import SwiftUI
import Combine

// 模型结构体
struct Model: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String?
}

class AppState: ObservableObject {
    // 主题模式
    @Published var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
        }
    }

    // 可用模型列表
    @Published var availableModels: [Model] = []

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

    // 可用的思考强度选项
    @Published var availableEfforts: [String] = ["low", "medium", "high", "max"]

    // 服务商信息
    @Published var currentProviderName: String?

    // 待导航的会话ID（用于通知点击跳转）
    @Published var pendingNavigateToSession: String?

    // 加载状态
    @Published var isLoadingModels: Bool = false

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

        // 恢复思考强度
        if let savedEffort = UserDefaults.standard.string(forKey: "effortLevel") {
            self.effortLevel = savedEffort
        } else {
            self.effortLevel = "medium"
        }

        // 恢复模型设置（稍后会被 API 数据覆盖）
        if let savedModelId = UserDefaults.standard.string(forKey: "currentModelId") {
            self.currentModel = Model(id: savedModelId, name: savedModelId, description: nil)
        }
    }

    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
    }

    func setCurrentModel(_ model: Model) {
        currentModel = model
        // 同步到服务器
        Task {
            try? await APIService.shared.setCurrentModel(model.id)
        }
    }

    func setEffortLevel(_ level: String) {
        effortLevel = level
    }

    // 从 API 获取模型列表
    @MainActor
    func fetchModels() async {
        isLoadingModels = true

        do {
            let response = try await APIService.shared.getModels()
            self.availableModels = response.models.map { Model(id: $0.id, name: $0.name, description: $0.description) }
            self.currentProviderName = response.provider?.name

            // 如果当前没有选中的模型，使用第一个
            if currentModel == nil, let first = availableModels.first {
                currentModel = first
            } else if let current = currentModel {
                // 确保当前选中的模型在列表中
                if !availableModels.contains(where: { $0.id == current.id }) {
                    currentModel = availableModels.first
                }
            }
        } catch {
            // 使用默认模型列表
            self.availableModels = [
                Model(id: "claude-sonnet-4-20250514", name: "Claude Sonnet 4", description: "平衡的性能和速度"),
                Model(id: "claude-opus-4-20250514", name: "Claude Opus 4", description: "最强大的推理能力"),
            ]
            if currentModel == nil {
                currentModel = availableModels.first
            }
        }

        isLoadingModels = false
    }

    // 从 API 获取 effort 选项
    @MainActor
    func fetchEffortOptions() async {
        do {
            let response = try await APIService.shared.getEffort()
            self.availableEfforts = response.available
            if !availableEfforts.contains(effortLevel) {
                self.effortLevel = response.level
            }
        } catch {
            // 使用默认值
        }
    }
}
