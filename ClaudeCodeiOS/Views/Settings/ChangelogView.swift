// 更新日志视图

import SwiftUI

struct ChangelogView: View {
    @EnvironmentObject var appState: AppState

    private var isDark: Bool { appState.themeMode == .dark || appState.themeMode == .glass }

    private let versions: [VersionEntry] = [
        VersionEntry(
            version: "1.0.0",
            date: "2026-04-26",
            features: [
                "微信式聊天体验 - 即时进入、实时消息",
                "Markdown 渲染器 - 代码块、标题、列表、引用",
                "工具调用可视化 - 展开/折叠查看详情",
                "思考过程折叠显示",
                "Liquid Glass 毛玻璃主题",
                "局域网/公网双模式连接",
                "服务商管理和模型切换",
                "从服务器导入对话",
            ],
            fixes: [
                "修复消息实时同步延迟",
                "修复用户消息重复显示",
                "修复 Tab 栏误触穿透",
            ]
        ),
    ]

    var body: some View {
        ZStack {
            Color.clear
                .liquidGlassBackground(isDark: isDark)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    ForEach(versions) { entry in
                        versionCard(entry)
                    }
                }
                .padding()
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("更新日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func versionCard(_ entry: VersionEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 版本号 + 日期
            HStack {
                Text("v\(entry.version)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.adaptivePrimary)
                Spacer()
                Text(entry.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !entry.features.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("新功能")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    ForEach(entry.features, id: \.self) { feature in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                                .padding(.top, 2)
                            Text(feature)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }

            if !entry.fixes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("修复")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    ForEach(entry.fixes, id: \.self) { fix in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                                .padding(.top, 2)
                            Text(fix)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

private struct VersionEntry: Identifiable {
    let id = UUID()
    let version: String
    let date: String
    let features: [String]
    let fixes: [String]
}

#Preview {
    NavigationStack {
        ChangelogView()
    }
}
