// 工具调用可视化组件

import SwiftUI

// MARK: - 工具图标映射

struct ToolIcon {
    let sfSymbol: String
    let label: String
    let color: Color

    static let mapping: [String: ToolIcon] = [
        "Bash": ToolIcon(sfSymbol: "terminal", label: "Terminal", color: .green),
        "Read": ToolIcon(sfSymbol: "doc.text", label: "Read file", color: .blue),
        "Write": ToolIcon(sfSymbol: "square.and.pencil", label: "Write file", color: .orange),
        "Edit": ToolIcon(sfSymbol: "pencil.line", label: "Edit file", color: .yellow),
        "Glob": ToolIcon(sfSymbol: "magnifyingglass", label: "Search files", color: .purple),
        "Grep": ToolIcon(sfSymbol: "text.magnifyingglass", label: "Search content", color: .purple),
        "Agent": ToolIcon(sfSymbol: "person.wave.2", label: "Agent", color: .cyan),
        "WebSearch": ToolIcon(sfSymbol: "globe", label: "Web search", color: .blue),
        "WebFetch": ToolIcon(sfSymbol: "arrow.down.doc", label: "Web fetch", color: .blue),
        "Skill": ToolIcon(sfSymbol: "star", label: "Skill", color: .yellow),
    ]

    static func icon(for name: String) -> ToolIcon {
        mapping[name] ?? ToolIcon(sfSymbol: "wrench", label: name, color: .gray)
    }
}

// MARK: - 工具调用块

struct ToolCallBlock: View {
    let toolName: String
    let input: [String: AnyCodable]?
    let status: ToolStatus
    let result: String?

    @State private var isExpanded = false

    private var icon: ToolIcon {
        ToolIcon.icon(for: toolName)
    }

    /// 根据工具类型提取摘要
    private var summary: String {
        guard let input = input else { return "" }
        switch toolName {
        case "Bash":
            if let cmd = input["command"]?.value as? String {
                return String(cmd.prefix(50))
            }
        case "Read", "Write", "Edit":
            if let path = input["file_path"]?.value as? String {
                return URL(fileURLWithPath: path).lastPathComponent
            }
        case "Glob":
            if let pattern = input["pattern"]?.value as? String {
                return pattern
            }
        case "Grep":
            if let pattern = input["pattern"]?.value as? String {
                return pattern
            }
        case "Agent":
            if let desc = input["description"]?.value as? String {
                return String(desc.prefix(40))
            }
        default:
            break
        }
        return ""
    }

    /// 是否可展开
    private var isExpandable: Bool {
        ["Edit", "Write", "Bash", "Read", "Grep", "WebFetch"].contains(toolName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                if isExpandable {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    // 图标
                    Image(systemName: icon.sfSymbol)
                        .font(.system(size: 12))
                        .foregroundColor(icon.color)
                        .frame(width: 24, height: 24)
                        .background(icon.color.opacity(0.12))
                        .cornerRadius(6)

                    // 工具名
                    Text(icon.label.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    // 摘要
                    if !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                            .lineLimit(1)
                    }

                    Spacer()

                    // 状态
                    statusIcon

                    // 展开箭头
                    if isExpandable {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 展开区域
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 8) {
                    // INPUT
                    if let input = input, !input.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("INPUT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)

                            Text(formatJSON(input))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary.opacity(0.8))
                                .textSelection(.enabled)
                        }
                    }

                    // OUTPUT
                    if let result = result, !result.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("OUTPUT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)

                            MarkdownRenderer(content: result)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        case .running:
            ProgressView()
                .scaleEffect(0.6)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.red)
        }
    }

    private func formatJSON(_ input: [String: AnyCodable]) -> String {
        var lines: [String] = []
        for (key, value) in input.sorted(by: { $0.key < $1.key }) {
            if let str = value.value as? String {
                if str.count > 100 {
                    lines.append("\(key): \"\(str.prefix(100))...\"")
                } else {
                    lines.append("\(key): \"\(str)\"")
                }
            } else {
                lines.append("\(key): \(value.value)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - 工具调用分组

struct ToolCallGroup: View {
    let title: String
    let tools: [ToolCallItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            ForEach(tools) { tool in
                ToolCallBlock(
                    toolName: tool.toolName,
                    input: tool.input,
                    status: tool.status,
                    result: tool.result
                )
            }
        }
    }
}

struct ToolCallItem: Identifiable {
    let id = UUID()
    let toolName: String
    let input: [String: AnyCodable]?
    let status: ToolStatus
    let result: String?
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            ToolCallBlock(
                toolName: "Bash",
                input: ["command": AnyCodable(value: "npm install --save react")],
                status: .completed,
                result: "added 1 package in 2s"
            )
            ToolCallBlock(
                toolName: "Read",
                input: ["file_path": AnyCodable(value: "/Users/test/project/App.tsx")],
                status: .completed,
                result: nil
            )
            ToolCallBlock(
                toolName: "Edit",
                input: [
                    "file_path": AnyCodable(value: "/Users/test/project/App.tsx"),
                    "old_string": AnyCodable(value: "const x = 1"),
                    "new_string": AnyCodable(value: "const x = 2")
                ],
                status: .running,
                result: nil
            )
        }
        .padding()
    }
}
