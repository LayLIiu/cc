// 思考过程可视化组件

import SwiftUI

// MARK: - 思考块

struct ThinkingBlock: View {
    let content: String
    let isStreaming: Bool

    @State private var isExpanded = false

    /// 摘要：取第一行非空内容，超60字符截断
    private var summary: String {
        let firstLine = content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty }) ?? ""
        return firstLine.count > 60 ? String(firstLine.prefix(60)) + "..." : firstLine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header（点击展开/折叠）
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    // 戴安娜 Logo 动画
                    ClaudeLogoWidget(
                        size: 16,
                        mode: isStreaming ? .thinking : .idle
                    )

                    Text("thinking")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    // 折叠时显示摘要
                    if !isExpanded && !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 展开内容
            if isExpanded {
                ScrollView(.vertical, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        Text(content)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)

                        // 流式输出时显示光标
                        if isStreaming {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.secondary.opacity(0.5))
                                .frame(width: 2, height: 12)
                                .padding(.leading, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.05))
            }
        }
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - 流式指示器

struct StreamingIndicator: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ClaudeLogoWidget(
                size: 20,
                mode: .thinking
            )

            if !text.isEmpty {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
    }
}

// MARK: - 状态指示器（用于聊天状态栏）

struct StatusIndicator: View {
    let status: SessionStatus
    var size: CGFloat = 10

    @State private var isBreathing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(isBreathing ? 1.2 : 0.8)
            .opacity(isBreathing ? 1.0 : 0.5)
            .animation(
                isAnimating
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: isBreathing
            )
            .onAppear {
                if isAnimating {
                    isBreathing = true
                }
            }
            .onChange(of: status) { _, newStatus in
                isBreathing = isAnimating
            }
    }

    private var isAnimating: Bool {
        switch status {
        case .idle, .completed:
            return false
        case .thinking, .streaming, .toolExecuting, .permissionPending, .questionPending:
            return true
        }
    }

    private var color: Color {
        switch status {
        case .idle, .completed:
            return .gray
        case .thinking:
            return .orange
        case .streaming:
            return .green
        case .toolExecuting:
            return .blue
        case .permissionPending, .questionPending:
            return .yellow
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ThinkingBlock(
                content: "用户想要创建一个移动端应用，需要考虑跨平台兼容性和性能优化。让我分析一下需求...",
                isStreaming: false
            )
            ThinkingBlock(
                content: "正在思考中...",
                isStreaming: true
            )
            StreamingIndicator(text: "正在生成回答")

            HStack(spacing: 20) {
                StatusIndicator(status: .idle, size: 32)
                StatusIndicator(status: .thinking, size: 32)
                StatusIndicator(status: .streaming, size: 32)
                StatusIndicator(status: .permissionPending, size: 32)
            }
        }
        .padding()
    }
}
