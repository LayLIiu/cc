// Markdown 渲染器 - 轻量级解析与渲染

import SwiftUI
import UniformTypeIdentifiers

// MARK: - AST 节点

enum MarkdownNode: Equatable {
    case codeBlock(language: String, code: String)
    case heading(level: Int, text: String)
    case unorderedListItem(text: String)
    case orderedListItem(index: Int, text: String)
    case blockquote(text: String)
    case paragraph(text: String)
    case spacer
}

// MARK: - 解析缓存

private class MarkdownCache {
    static let shared = MarkdownCache()
    private var cache = NSCache<NSString, NSArray>()

    func getNodes(for content: String) -> [MarkdownNode]? {
        cache.object(forKey: content as NSString) as? [MarkdownNode]
    }

    func setNodes(_ nodes: [MarkdownNode], for content: String) {
        cache.setObject(nodes as NSArray, forKey: content as NSString)
    }
}

// MARK: - 解析器

struct MarkdownParser {
    static func parse(_ content: String) -> [MarkdownNode] {
        // 检查缓存
        if let cached = MarkdownCache.shared.getNodes(for: content) {
            return cached
        }

        var nodes: [MarkdownNode] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // 代码块
            if line.hasPrefix("```") {
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                nodes.append(.codeBlock(language: language, code: codeLines.joined(separator: "\n")))
                i += 1 // 跳过结束的 ```
                continue
            }

            // 标题
            if line.hasPrefix("#") {
                let level = line.prefix(while: { $0 == "#" }).count
                if level >= 1 && level <= 6 {
                    let text = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    nodes.append(.heading(level: level, text: text))
                    i += 1
                    continue
                }
            }

            // 引用块
            if line.hasPrefix("> ") {
                let text = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                nodes.append(.blockquote(text: text))
                i += 1
                continue
            }

            // 无序列表
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ") {
                let text = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                nodes.append(.unorderedListItem(text: text))
                i += 1
                continue
            }

            // 有序列表
            if let match = trimmedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let prefix = trimmedLine[match]
                let indexStr = prefix.replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
                let index = Int(indexStr) ?? 1
                let text = String(trimmedLine[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                nodes.append(.orderedListItem(index: index, text: text))
                i += 1
                continue
            }

            // 空行
            if trimmedLine.isEmpty {
                nodes.append(.spacer)
                i += 1
                continue
            }

            // 普通段落
            nodes.append(.paragraph(text: line))
            i += 1
        }

        // 缓存结果
        MarkdownCache.shared.setNodes(nodes, for: content)
        return nodes
    }
}

// MARK: - 内联元素渲染（优化版：缓存 AttributedString）

private class InlineTextCache {
    static let shared = InlineTextCache()
    private var cache = NSCache<NSString, NSAttributedString>()

    func getAttributed(for text: String) -> AttributedString? {
        guard let nsAttr = cache.object(forKey: text as NSString) else { return nil }
        return AttributedString(nsAttr)
    }

    func setAttributed(_ attr: AttributedString, for text: String) {
        let nsAttr = NSAttributedString(attr)
        cache.setObject(nsAttr, forKey: text as NSString)
    }
}

struct InlineText: View {
    let text: String

    var body: some View {
        Text(getOrCreateAttributedText())
    }

    private func getOrCreateAttributedText() -> AttributedString {
        if let cached = InlineTextCache.shared.getAttributed(for: text) {
            return cached
        }
        let attributed = parseInlineElements(text)
        InlineTextCache.shared.setAttributed(attributed, for: text)
        return attributed
    }

    private func parseInlineElements(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text

        while !remaining.isEmpty {
            // 行内代码 `code`
            if let range = remaining.range(of: #"`[^`]+`"#, options: .regularExpression) {
                if range.lowerBound != remaining.startIndex {
                    result.append(parseFormatting(String(remaining[remaining.startIndex..<range.lowerBound])))
                }
                let code = String(remaining[range]).replacingOccurrences(of: "`", with: "")
                var codeAttr = AttributedString(code)
                codeAttr.font = .system(.body, design: .monospaced)
                codeAttr.foregroundColor = Color.purple
                codeAttr.backgroundColor = Color.purple.opacity(0.1)
                result.append(codeAttr)
                remaining = String(remaining[range.upperBound...])
            }
            // 粗体 **text**
            else if let range = remaining.range(of: #"\*\*[^*]+\*\*"#, options: .regularExpression) {
                if range.lowerBound != remaining.startIndex {
                    result.append(parseFormatting(String(remaining[remaining.startIndex..<range.lowerBound])))
                }
                var bold = AttributedString(String(remaining[range]).replacingOccurrences(of: "**", with: ""))
                bold.font = .body.bold()
                result.append(bold)
                remaining = String(remaining[range.upperBound...])
            }
            // 斜体 *text*
            else if let range = remaining.range(of: #"\*[^*]+\*"#, options: .regularExpression) {
                if range.lowerBound != remaining.startIndex {
                    result.append(parseFormatting(String(remaining[remaining.startIndex..<range.lowerBound])))
                }
                var italic = AttributedString(String(remaining[range]).replacingOccurrences(of: "*", with: ""))
                italic.font = .body.italic()
                result.append(italic)
                remaining = String(remaining[range.upperBound...])
            }
            // 链接 [text](url)
            else if let range = remaining.range(of: #"\[[^\]]+\]\([^)]+\)"#, options: .regularExpression) {
                if range.lowerBound != remaining.startIndex {
                    result.append(parseFormatting(String(remaining[remaining.startIndex..<range.lowerBound])))
                }
                let linkText = String(remaining[range])
                if let nameRange = linkText.range(of: #"\[([^\]]+)\]"#, options: .regularExpression),
                   let urlRange = linkText.range(of: #"\(([^)]+)\)"#, options: .regularExpression) {
                    let name = String(linkText[nameRange]).replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                    let urlStr = String(linkText[urlRange]).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                    var linkAttr = AttributedString(name)
                    linkAttr.foregroundColor = .blue
                    linkAttr.underlineStyle = .single
                    linkAttr.link = URL(string: urlStr)
                    result.append(linkAttr)
                }
                remaining = String(remaining[range.upperBound...])
            }
            else {
                result.append(parseFormatting(remaining))
                remaining = ""
            }
        }

        return result
    }

    private func parseFormatting(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        attr.foregroundColor = .primary
        return attr
    }
}

// MARK: - 代码块视图

struct CodeBlockView: View {
    let language: String
    let code: String

    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(language.isEmpty ? "code" : language.lowercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                Button {
                    UIPasteboard.general.string = code
                    withAnimation {
                        showCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showCopied = false
                        }
                    }
                } label: {
                    if showCopied {
                        Text("已复制")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))

            // 代码内容
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Markdown 渲染器主视图

struct MarkdownRenderer: View {
    let content: String

    private var nodes: [MarkdownNode] {
        MarkdownParser.parse(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                switch node {
                case .codeBlock(let language, let code):
                    CodeBlockView(language: language, code: code)

                case .heading(let level, let text):
                    InlineText(text: text)
                        .font(.system(size: CGFloat(24 - level * 2), weight: .bold))
                        .padding(.top, level == 1 ? 8 : 4)

                case .unorderedListItem(let text):
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.secondary)
                        InlineText(text: text)
                    }
                    .padding(.leading, 8)

                case .orderedListItem(let index, let text):
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index).")
                            .foregroundColor(.secondary)
                            .frame(width: 24, alignment: .trailing)
                        InlineText(text: text)
                    }
                    .padding(.leading, 8)

                case .blockquote(let text):
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 3)
                        InlineText(text: text)
                            .italic()
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 4)

                case .paragraph(let text):
                    InlineText(text: text)

                case .spacer:
                    Color.clear.frame(height: 4)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        MarkdownRenderer(content: """
        # Hello World

        This is a **bold** text and *italic* text.

        - Item 1
        - Item 2

        1. First
        2. Second

        > A blockquote

        ```swift
        print("Hello, World!")
        ```

        Some `inline code` here.
        """)
        .padding()
    }
}
