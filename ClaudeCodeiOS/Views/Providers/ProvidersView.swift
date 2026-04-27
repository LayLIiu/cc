// 服务商管理视图

import SwiftUI

struct ProvidersView: View {
    @EnvironmentObject var providerStore: ProviderStore
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var appState: AppState

    @State private var showAddModal = false
    @State private var selectedPreset: String?
    @State private var editingProvider: Provider?

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景 - 统一使用玻璃背景
                Color.clear
                    .liquidGlassBackground(isDark: appState.themeMode == .dark || appState.themeMode == .glass)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 标题栏
                        HStack {
                            Spacer()
                            Text("服务商")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.adaptiveText)
                            Spacer()
                        }
                        .overlay(
                            Button {
                                showAddModal = true
                                editingProvider = nil
                            } label: {
                                Text("添加")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.adaptivePrimary)
                            }
                            , alignment: .trailing
                        )
                        .padding(.horizontal, 16)

                        // 连接设置
                        connectionSection
                            .padding(.horizontal, 16)

                        // 官方认证
                        officialSection
                            .padding(.horizontal, 16)

                        // 自定义服务商
                        customProvidersSection
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // 加载服务商列表
                await providerStore.loadProviders()
            }
            .sheet(isPresented: $showAddModal) {
                ProviderFormSheet(
                    preset: selectedPreset,
                    editingProvider: editingProvider,
                    onSave: { input in
                        Task {
                            if let provider = editingProvider {
                                try? await providerStore.updateProvider(provider.id, input)
                            } else {
                                try? await providerStore.createProvider(input)
                            }
                            showAddModal = false
                        }
                    }
                )
            }
            .alert("错误", isPresented: .init(
                get: { providerStore.error != nil },
                set: { if !$0 { providerStore.setError(nil) } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(providerStore.error ?? "")
            }
        }
    }

    // MARK: - 连接设置

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("连接设置")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                // 配对码
                Button {
                    // 生成配对码
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("配对码")
                                .font(.subheadline)
                            Text("生成配对码连接桌面端")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("生成")
                            .font(.caption)
                            .foregroundColor(.adaptivePrimary)
                    }
                }
                .padding(12)
                .liquidGlass(cornerRadius: 8, isDark: appState.themeMode == .dark || appState.themeMode == .glass)

                // 局域网地址
                HStack {
                    VStack(alignment: .leading) {
                        Text("局域网地址")
                            .font(.subheadline)
                        Text(authStore.lanUrl.isEmpty ? "未设置" : authStore.lanUrl)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .liquidGlass(cornerRadius: 8, isDark: appState.themeMode == .dark || appState.themeMode == .glass)

                // 公网隧道
                HStack {
                    VStack(alignment: .leading) {
                        Text("公网隧道")
                            .font(.subheadline)
                        Text("未开启")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    Toggle("", isOn: .constant(false))
                        .labelsHidden()
                }
                .padding(12)
                .liquidGlass(cornerRadius: 8, isDark: appState.themeMode == .dark || appState.themeMode == .glass)
            }
        }
    }

    // MARK: - 官方认证

    private var officialSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("官方认证")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Button {
                Task { try? await providerStore.activateOfficial() }
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Claude Official")
                            .font(.headline)
                        Text("使用官方 Anthropic 认证")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if providerStore.activeProviderId == nil {
                        Text("当前")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.adaptivePrimary)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .liquidGlass(cornerRadius: 6, isDark: appState.themeMode == .dark || appState.themeMode == .glass)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 自定义服务商

    private var customProvidersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自定义服务商")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if providerStore.providers.isEmpty {
                Text("暂无自定义服务商，点击右上角添加")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .liquidGlass(cornerRadius: 6, isDark: appState.themeMode == .dark || appState.themeMode == .glass)
            } else {
                ForEach(providerStore.providers) { provider in
                    ProviderCard(
                        provider: provider,
                        isActive: providerStore.activeProviderId == provider.id,
                        onSelect: {
                            editingProvider = provider
                            selectedPreset = provider.presetId
                            showAddModal = true
                        },
                        onActivate: {
                            Task { try? await providerStore.activateProvider(provider.id) }
                        },
                        onTest: {
                            // 测试连接
                        },
                        onDelete: {
                            Task { try? await providerStore.deleteProvider(provider.id) }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - 服务商卡片

struct ProviderCard: View {
    let provider: Provider
    let isActive: Bool
    let onSelect: () -> Void
    let onActivate: () -> Void
    let onTest: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            Button {
                onSelect()
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(provider.name)
                            .font(.headline)
                        Text(provider.apiFormat.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isActive {
                        Text("当前")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.adaptivePrimary)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button {
                    onActivate()
                } label: {
                    Text(isActive ? "已激活" : "激活")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                .disabled(isActive)

                Button {
                    onTest()
                } label: {
                    Text("测试")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }

                Button {
                    onDelete()
                } label: {
                    Text("删除")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .liquidGlass(cornerRadius: 6, isDark: appState.themeMode == .dark || appState.themeMode == .glass)
    }
}

// MARK: - 服务商表单

struct ProviderFormSheet: View {
    let preset: String?
    let editingProvider: Provider?
    let onSave: (ProviderInput) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var selectedPresetId: String = "openai"
    @State private var name = ""
    @State private var apiKey = ""
    @State private var baseUrl = ""

    var selectedPreset: ProviderPreset? {
        PROVIDER_PRESETS.first { $0.id == selectedPresetId }
    }

    var body: some View {
        NavigationStack {
            Form {
                if editingProvider == nil {
                    Section("选择预设") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(PROVIDER_PRESETS.filter { $0.id != "custom" }) { preset in
                                    Button {
                                        selectedPresetId = preset.id
                                        name = preset.name
                                        baseUrl = preset.baseUrl
                                    } label: {
                                        Text(preset.name)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedPresetId == preset.id ? Color.adaptivePrimary : Color.secondary.opacity(0.1))
                                            .foregroundColor(selectedPresetId == preset.id ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    TextField("名称", text: $name)
                    SecureField("API Key", text: $apiKey)
                    TextField("Base URL", text: $baseUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(editingProvider == nil ? "添加服务商" : "编辑服务商")
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
                        guard let preset = selectedPreset else { return }
                        let input = ProviderInput(
                            presetId: preset.id,
                            name: name,
                            apiKey: apiKey,
                            baseUrl: baseUrl,
                            apiFormat: preset.apiFormat,
                            models: preset.defaultModels,
                            notes: nil
                        )
                        onSave(input)
                    } label: {
                        Text("保存")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.adaptivePrimary)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .disabled(name.isEmpty || apiKey.isEmpty)
                }
            }
            .onAppear {
                if let provider = editingProvider {
                    selectedPresetId = provider.presetId
                    name = provider.name
                    apiKey = provider.apiKey
                    baseUrl = provider.baseUrl
                } else if let preset = preset {
                    selectedPresetId = preset
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    ProvidersView()
        .environmentObject(ProviderStore())
        .environmentObject(AuthStore())
        .environmentObject(AppState())
}
