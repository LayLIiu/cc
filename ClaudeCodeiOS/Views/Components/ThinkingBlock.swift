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
                    // 思考动画指示器
                    if isStreaming {
                        ThinkingDots()
                    } else {
                        Image(systemName: "brain")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

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

// MARK: - 思考动画（三点脉冲）

struct ThinkingDots: View {
    @State private var activeDot = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 5, height: 5)
                    .opacity(activeDot == index ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.2), value: activeDot)
            }
        }
        .onReceive(timer) { _ in
            activeDot = (activeDot + 1) % 3
        }
    }
}

// MARK: - 流式指示器

struct StreamingIndicator: View {
    let text: String
    @State private var activeDot = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.adaptivePrimary)
                        .frame(width: 6, height: 6)
                        .opacity(activeDot == index ? 1.0 : 0.3)
                        .animation(.easeInOut(duration: 0.2), value: activeDot)
                }
            }
            .onReceive(timer) { _ in
                activeDot = (activeDot + 1) % 3
            }

            if !text.isEmpty {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
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
        }
        .padding()
    }
}
