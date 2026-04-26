// 模型选择器

import SwiftUI

struct ModelSelector: View {
    @EnvironmentObject var appState: AppState
    @State private var showModelSheet = false
    @State private var glowOpacity: Double = 0.6

    var body: some View {
        Button {
            showModelSheet = true
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

    private let models: [(id: String, name: String, icon: String, description: String)] = [
        ("claude-opus-4-7", "Claude Opus 4", "◆", "最强大的推理能力"),
        ("claude-sonnet-4-6", "Claude Sonnet 4", "✦", "平衡的性能和速度"),
        ("claude-haiku-4-5", "Claude Haiku 4", "⚡", "快速响应"),
    ]

    private let effortOptions = [
        ("low", "低"),
        ("medium", "中"),
        ("high", "高"),
        ("max", "最高"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(models, id: \.id) { model in
                        Button {
                            appState.setCurrentModel(Model(id: model.id, name: model.name))
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: appState.currentModel?.id == model.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(appState.currentModel?.id == model.id ? .adaptivePrimary : .secondary)

                                Text(model.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(.adaptivePrimary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("选择模型")
                }

                Section {
                    HStack(spacing: 8) {
                        ForEach(effortOptions, id: \.0) { option in
                            Button {
                                appState.setEffortLevel(option.0)
                            } label: {
                                Text(option.1)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(appState.effortLevel == option.0 ? Color.adaptivePrimary : Color.secondary.opacity(0.1))
                                    .foregroundColor(appState.effortLevel == option.0 ? .white : .secondary)
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
