// 模型选择器

import SwiftUI

struct ModelSelector: View {
    @EnvironmentObject var appState: AppState
    @State private var showModelSheet = false
    @State private var glowOpacity: Double = 0.6

    var body: some View {
        Button {
            showModelSheet = true
            // 每次打开时刷新模型列表
            Task {
                await appState.fetchModels()
            }
        } label: {
            Text("✦")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.adaptivePrimary)
                .opacity(glowOpacity)
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
            // 首次加载获取模型
            Task {
                await appState.fetchModels()
            }
        }
        .sheet(isPresented: $showModelSheet) {
            ModelSelectionSheet()
        }
    }
}

// MARK: - 模型选择弹窗

struct ModelSelectionSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    private let effortLabels: [String: String] = [
        "low": "低",
        "medium": "中",
        "high": "高",
        "max": "最高"
    ]

    var body: some View {
        NavigationStack {
            List {
                // 服务商信息
                if let providerName = appState.currentProviderName {
                    Section {
                        HStack {
                            Text("服务商")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(providerName)
                                .foregroundColor(.adaptiveText)
                        }
                    }
                }

                // 模型列表
                Section {
                    if appState.isLoadingModels {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if appState.availableModels.isEmpty {
                        Text("暂无可用模型")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(appState.availableModels) { model in
                            Button {
                                appState.setCurrentModel(model)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: appState.currentModel?.id == model.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(appState.currentModel?.id == model.id ? .adaptivePrimary : .secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.name)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        if let desc = model.description {
                                            Text(desc)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("选择模型")
                }

                // 思考强度
                Section {
                    HStack(spacing: 8) {
                        ForEach(appState.availableEfforts, id: \.self) { effort in
                            Button {
                                appState.setEffortLevel(effort)
                                Task {
                                    try? await APIService.shared.setEffort(effort)
                                }
                            } label: {
                                Text(effortLabels[effort] ?? effort)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(appState.effortLevel == effort ? Color.adaptivePrimary : Color.secondary.opacity(0.1))
                                    .foregroundColor(appState.effortLevel == effort ? .white : .secondary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                } header: {
                    Text("思考强度")
                }
            }
            .navigationTitle("模型设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ModelSelector()
}
