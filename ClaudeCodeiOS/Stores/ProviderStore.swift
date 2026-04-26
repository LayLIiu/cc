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
            // TODO: 调用 API
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    @MainActor
    func createProvider(_ input: CreateProviderInput) async throws {
        let newProvider = Provider(
            id: UUID().uuidString,
            presetId: input.presetId,
            name: input.name,
            apiKey: input.apiKey,
            baseUrl: input.baseUrl,
            apiFormat: input.apiFormat,
            models: input.models,
            notes: input.notes,
            createdAt: Date(),
            updatedAt: Date()
        )

        providers.append(newProvider)
        saveProviders()
    }

    @MainActor
    func updateProvider(_ id: String, _ input: UpdateProviderInput) async throws {
        guard let index = providers.firstIndex(where: { $0.id == id }) else {
            throw ProviderError.notFound
        }

        var provider = providers[index]
        provider = Provider(
            id: provider.id,
            presetId: provider.presetId,
            name: input.name ?? provider.name,
            apiKey: input.apiKey ?? provider.apiKey,
            baseUrl: input.baseUrl ?? provider.baseUrl,
            apiFormat: provider.apiFormat,
            models: input.models ?? provider.models,
            notes: input.notes ?? provider.notes,
            createdAt: provider.createdAt,
            updatedAt: Date()
        )

        providers[index] = provider
        saveProviders()
    }

    @MainActor
    func deleteProvider(_ id: String) async throws {
        providers.removeAll { $0.id == id }
        if activeProviderId == id {
            activeProviderId = nil
        }
        saveProviders()
    }

    func activateProvider(_ id: String) async throws {
        activeProviderId = id
        saveProviders()
    }

    func activateOfficial() async throws {
        activeProviderId = nil
        saveProviders()
    }

    func setError(_ error: String?) {
        self.error = error
    }
}

// MARK: - 输入类型

struct CreateProviderInput: Encodable {
    let presetId: String
    let name: String
    let apiKey: String
    let baseUrl: String
    let apiFormat: ApiFormat
    let models: [ModelMapping]
    var notes: String?
}

struct UpdateProviderInput: Encodable {
    var name: String?
    var apiKey: String?
    var baseUrl: String?
    var models: [ModelMapping]?
    var notes: String?
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
    let defaultModels: [ModelMapping]
}

let PROVIDER_PRESETS: [ProviderPreset] = [
    ProviderPreset(
        id: "openai",
        name: "OpenAI",
        baseUrl: "https://api.openai.com/v1",
        apiFormat: .openAI,
        defaultModels: [
            ModelMapping(modelId: "gpt-4o", displayName: "GPT-4o"),
            ModelMapping(modelId: "gpt-4o-mini", displayName: "GPT-4o Mini")
        ]
    ),
    ProviderPreset(
        id: "anthropic",
        name: "Anthropic",
        baseUrl: "https://api.anthropic.com",
        apiFormat: .anthropic,
        defaultModels: [
            ModelMapping(modelId: "claude-sonnet-4-20250514", displayName: "Claude Sonnet 4"),
            ModelMapping(modelId: "claude-opus-4-20250514", displayName: "Claude Opus 4")
        ]
    ),
    ProviderPreset(
        id: "deepseek",
        name: "DeepSeek",
        baseUrl: "https://api.deepseek.com",
        apiFormat: .openAICompatible,
        defaultModels: [
            ModelMapping(modelId: "deepseek-chat", displayName: "DeepSeek Chat"),
            ModelMapping(modelId: "deepseek-reasoner", displayName: "DeepSeek Reasoner")
        ]
    ),
    ProviderPreset(
        id: "gemini",
        name: "Google Gemini",
        baseUrl: "https://generativelanguage.googleapis.com/v1beta",
        apiFormat: .openAICompatible,
        defaultModels: [
            ModelMapping(modelId: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro"),
            ModelMapping(modelId: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash")
        ]
    ),
    ProviderPreset(
        id: "custom",
        name: "自定义",
        baseUrl: "",
        apiFormat: .openAICompatible,
        defaultModels: []
    )
]
