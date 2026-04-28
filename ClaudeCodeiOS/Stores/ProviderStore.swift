// 服务商状态管理

import SwiftUI
import Combine

class ProviderStore: ObservableObject {
    // 服务商列表
    @Published var providers: [Provider] = []
    @Published var activeProviderId: String?

    // 加载状态
    @Published var isLoading: Bool = false
    @Published var error: String?

    // 当前激活的服务商
    var activeProvider: Provider? {
        guard let id = activeProviderId else { return nil }
        return providers.first { $0.id == id }
    }

    init() {
        loadSavedProviders()
    }

    private func loadSavedProviders() {
        if let data = UserDefaults.standard.data(forKey: "providers"),
           let saved = try? JSONDecoder().decode([Provider].self, from: data) {
            self.providers = saved
        }
        self.activeProviderId = UserDefaults.standard.string(forKey: "activeProviderId")
    }

    private func saveProviders() {
        if let data = try? JSONEncoder().encode(providers) {
            UserDefaults.standard.set(data, forKey: "providers")
        }
        if let id = activeProviderId {
            UserDefaults.standard.set(id, forKey: "activeProviderId")
        }
    }

    // MARK: - API 操作

    @MainActor
    func loadProviders() async {
        isLoading = true
        error = nil

        do {
            let response = try await APIService.shared.getProviders()
            self.providers = response.providers
            self.activeProviderId = response.activeId
            saveProviders()
        } catch {
            // 网络错误时不显示弹窗，静默失败
            // 可能是 URL 格式问题或网络不可用
            print("[ProviderStore] Failed to load providers: \(error.localizedDescription)")
            // 保留本地缓存的数据
        }

        isLoading = false
    }

    @MainActor
    func createProvider(_ input: ProviderInput) async throws {
        let response = try await APIService.shared.createProvider(input)
        providers.append(response.provider)
        saveProviders()
    }

    @MainActor
    func updateProvider(_ id: String, _ input: ProviderInput) async throws {
        let response = try await APIService.shared.updateProvider(id, input)

        if let index = providers.firstIndex(where: { $0.id == id }) {
            providers[index] = response.provider
            saveProviders()
        }
    }

    @MainActor
    func deleteProvider(_ id: String) async throws {
        try await APIService.shared.deleteProvider(id)
        providers.removeAll { $0.id == id }
        if activeProviderId == id {
            activeProviderId = nil
        }
        saveProviders()
    }

    func activateProvider(_ id: String) async throws {
        try await APIService.shared.activateProvider(id)
        activeProviderId = id
        saveProviders()
    }

    func activateOfficial() async throws {
        try await APIService.shared.activateOfficialProvider()
        activeProviderId = nil
        saveProviders()
    }

    func testProvider(_ id: String, overrides: ProviderTestOverrides? = nil) async throws -> Bool {
        let response = try await APIService.shared.testProvider(id, overrides: overrides)
        return response.result.connectivity.success
    }

    func setError(_ error: String?) {
        self.error = error
    }
}

// MARK: - 错误类型

enum ProviderError: Error, LocalizedError {
    case notFound
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .notFound: return "服务商不存在"
        case .invalidInput: return "输入无效"
        }
    }
}

// MARK: - 预设服务商

struct ProviderPreset: Identifiable {
    let id: String
    let name: String
    let baseUrl: String
    let apiFormat: ApiFormat
    let defaultModels: ModelMapping
}

let PROVIDER_PRESETS: [ProviderPreset] = [
    ProviderPreset(
        id: "openai",
        name: "OpenAI",
        baseUrl: "https://api.openai.com/v1",
        apiFormat: .openAIChat,
        defaultModels: ModelMapping(main: "gpt-4o", haiku: "gpt-4o-mini", sonnet: "gpt-4o", opus: "gpt-4o")
    ),
    ProviderPreset(
        id: "anthropic",
        name: "Anthropic",
        baseUrl: "https://api.anthropic.com",
        apiFormat: .anthropic,
        defaultModels: ModelMapping(main: "claude-sonnet-4-20250514", haiku: "claude-haiku-4-5-20250219", sonnet: "claude-sonnet-4-20250514", opus: "claude-opus-4-20250514")
    ),
    ProviderPreset(
        id: "deepseek",
        name: "DeepSeek",
        baseUrl: "https://api.deepseek.com",
        apiFormat: .openAIChat,
        defaultModels: ModelMapping(main: "deepseek-chat", haiku: "deepseek-chat", sonnet: "deepseek-reasoner", opus: "deepseek-reasoner")
    ),
    ProviderPreset(
        id: "gemini",
        name: "Google Gemini",
        baseUrl: "https://generativelanguage.googleapis.com/v1beta",
        apiFormat: .openAIChat,
        defaultModels: ModelMapping(main: "gemini-2.5-pro", haiku: "gemini-2.5-flash", sonnet: "gemini-2.5-pro", opus: "gemini-2.5-pro")
    ),
    ProviderPreset(
        id: "custom",
        name: "自定义",
        baseUrl: "",
        apiFormat: .openAIChat,
        defaultModels: ModelMapping(main: "", haiku: "", sonnet: "", opus: "")
    )
]
