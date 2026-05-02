//
//  ClaudeWidgetLiveActivity.swift
//  ClaudeWidget
//
//  灵动岛：实时显示多会话内容
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - 活动属性

/// 会话摘要（用于锁屏显示多个会话）
struct SessionSummary: Codable, Hashable {
    var title: String
    var content: String
    var type: ActivityType
}

struct ClaudeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: ClaudeWorkStatus
        var statusText: String
        var toolName: String
        var activityContent: String
        var activityType: ActivityType
        var sessionTitle: String
        var elapsedSeconds: Int
        var activeSessions: Int
        var totalSessions: Int
        var animationTimestamp: Double
        var sessionSummaries: [SessionSummary]
    }

    var sessionId: String
    var mascotColorHex: String
}

enum ClaudeWorkStatus: String, Codable {
    case idle, working, completed

    var displayText: String {
        switch self {
        case .idle: return "休闲中"
        case .working: return "工作中"
        case .completed: return "已完成"
        }
    }
}

enum ActivityType: String, Codable {
    case thinking, toolUse, streaming, completed, idle
}

// MARK: - Live Activity Widget

struct ClaudeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClaudeActivityAttributes.self) { context in
            // 锁屏/通知中心显示 - 显示多个会话
            VStack(alignment: .leading, spacing: 8) {
                // 顶部状态栏
                HStack {
                    MascotView(
                        status: context.state.status,
                        color: Color(hex: context.attributes.mascotColorHex),
                        size: 28,
                        timestamp: context.state.animationTimestamp
                    )

                    Text("Claude Code")
                        .font(.headline)

                    Spacer()

                    SessionCountBadge(
                        active: context.state.activeSessions,
                        total: context.state.totalSessions,
                        status: context.state.status
                    )
                }

                // 会话列表
                if !context.state.sessionSummaries.isEmpty {
                    ForEach(context.state.sessionSummaries, id: \.title) { summary in
                        SessionSummaryRow(summary: summary)
                    }
                } else if !context.state.activityContent.isEmpty {
                    // 单会话模式
                    Text(context.state.activityContent)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MascotView(
                        status: context.state.status,
                        color: Color(hex: context.attributes.mascotColorHex),
                        size: 48,
                        timestamp: context.state.animationTimestamp
                    )
                }

                DynamicIslandExpandedRegion(.trailing) {
                    SessionCountBadge(
                        active: context.state.activeSessions,
                        total: context.state.totalSessions,
                        status: context.state.status,
                        fontSize: 18
                    )
                }

                DynamicIslandExpandedRegion(.center) {
                    // 中间：项目名称 + 正在做的事情（两行）
                    VStack(alignment: .center, spacing: 2) {
                        // 第一行：项目名称
                        Text(context.state.sessionTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.center)

                        // 第二行：根据类型显示不同内容
                        CenterStatusView(
                            activityType: context.state.activityType,
                            toolName: context.state.toolName,
                            activityContent: context.state.activityContent
                        )
                    }
                }
            } compactLeading: {
                MascotView(
                    status: context.state.status,
                    color: Color(hex: context.attributes.mascotColorHex),
                    size: 24,
                    timestamp: context.state.animationTimestamp
                )
            } compactTrailing: {
                SessionCountBadge(
                    active: context.state.activeSessions,
                    total: context.state.totalSessions,
                    status: context.state.status,
                    fontSize: 14
                )
            } minimal: {
                SessionCountBadge(
                    active: context.state.activeSessions,
                    total: context.state.totalSessions,
                    status: context.state.status,
                    fontSize: 14,
                    minimal: true
                )
            }
        }
    }
}

// MARK: - 中间状态视图

// MARK: - 中间状态视图（完全遵循 CodeIsland 逻辑）

struct CenterStatusView: View {
    let activityType: ActivityType
    let toolName: String
    let activityContent: String

    var body: some View {
        // 有工具调用：显示工具名 + 描述
        if !toolName.isEmpty {
            HStack(spacing: 4) {
                Text(toolName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(toolColor(toolName))
                if !activityContent.isEmpty {
                    Text(activityContent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        } else if activityType == .thinking {
            // 思考中：只显示 thinking，不显示思考内容
            Text("thinking")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color(red: 0.6, green: 0.8, blue: 1.0))
        }
        // 其他情况（流式输出、完成、空闲）：不显示第二行
    }

    /// 工具名称对应的颜色
    private func toolColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "bash": return Color(red: 0.4, green: 1.0, blue: 0.5)
        case "edit", "write": return Color(red: 0.5, green: 0.7, blue: 1.0)
        case "read": return Color(red: 0.9, green: 0.8, blue: 0.4)
        case "grep": return Color(red: 1.0, green: 0.6, blue: 0.8)
        case "glob": return Color(red: 0.8, green: 0.6, blue: 1.0)
        default: return Color(red: 1.0, green: 0.7, blue: 0.3)
        }
    }
}

// MARK: - 会话摘要行

struct SessionSummaryRow: View {
    let summary: SessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                // 类型图标
                typeIcon
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(typeColor)

                // 会话标题
                Text(summary.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }

            // 内容
            if !summary.content.isEmpty {
                Text(summary.content)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var typeIcon: some View {
        switch summary.type {
        case .thinking: Image(systemName: "brain")
        case .toolUse: Image(systemName: "wrench.and.screwdriver")
        case .streaming: Image(systemName: "text.bubble")
        case .completed: Image(systemName: "checkmark.circle")
        case .idle: Image(systemName: "moon.zzz")
        }
    }

    private var typeColor: Color {
        switch summary.type {
        case .thinking: return Color(red: 0.6, green: 0.8, blue: 1.0)
        case .toolUse: return Color(red: 1.0, green: 0.7, blue: 0.3)
        case .streaming: return Color(red: 0.4, green: 1.0, blue: 0.5)
        case .completed: return Color(red: 0.3, green: 0.9, blue: 0.5)
        case .idle: return Color.white.opacity(0.5)
        }
    }
}

// MARK: - 会话数徽章

struct SessionCountBadge: View {
    let active: Int
    let total: Int
    let status: ClaudeWorkStatus
    var fontSize: CGFloat = 14
    var minimal: Bool = false

    var body: some View {
        HStack(spacing: 1) {
            if active > 0 && !minimal {
                Text("\(active)")
                    .foregroundStyle(Color(red: 0.4, green: 1.0, blue: 0.5))
                Text("/")
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            Text(minimal ? "\(active)" : "\(total)")
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .font(.system(size: fontSize, weight: .bold, design: .monospaced))
    }
}

// MARK: - 吉祥物视图

struct MascotView: View {
    let status: ClaudeWorkStatus
    let color: Color
    var size: CGFloat = 28
    var timestamp: Double = 0

    /// 时间（秒）
    private var t: Double { timestamp }

    var body: some View {
        Canvas { context, canvasSize in
            switch status {
            case .idle: drawIdle(context: context)
            case .working: drawWorking(context: context)
            case .completed: drawCompleted(context: context)
            }
        }
        .frame(width: size, height: size)
    }

    private var s: CGFloat { size / 17 }

    private func drawIdle(context: GraphicsContext) {
        // 呼吸动画：周期 2 秒
        let breathPhase = sin(t * .pi)
        let puff = breathPhase > 0 ? breathPhase * 0.25 : 0
        let ox = (size - 17 * s) / 2
        let oy = (size - 7 * s) / 2 - 4 * s

        context.fill(Path(roundedRect: CGRect(x: ox, y: oy + 15 * s, width: 17 * s, height: s), cornerRadius: 0), with: .color(.black.opacity(0.35)))

        for x in [3, 5, 9, 11] {
            context.fill(Path(roundedRect: CGRect(x: ox + CGFloat(x) * s, y: oy + 8.5 * s, width: s, height: 1.5 * s), cornerRadius: 0), with: .color(color))
        }

        let torsoH = 5 * (1.0 + puff)
        let torsoY = 15 - torsoH
        let torsoW = 13 + puff * 0.2
        let torsoX = 1 - (torsoW - 13) / 2

        context.fill(Path(roundedRect: CGRect(x: ox + torsoX * s, y: oy + torsoY * s, width: torsoW * s, height: torsoH * s), cornerRadius: 0), with: .color(color))
        context.fill(Path(roundedRect: CGRect(x: ox - s, y: oy + 13 * s, width: 2 * s, height: 2 * s), cornerRadius: 0), with: .color(color))
        context.fill(Path(roundedRect: CGRect(x: ox + 14 * s, y: oy + 13 * s, width: 2 * s, height: 2 * s), cornerRadius: 0), with: .color(color))

        let eyeY = 12.2 - puff * 2.5
        context.fill(Path(roundedRect: CGRect(x: ox + 3 * s, y: oy + eyeY * s, width: 2.5 * s, height: s), cornerRadius: 0), with: .color(Color(hex: "1a1a1a")))
        context.fill(Path(roundedRect: CGRect(x: ox + 9.5 * s, y: oy + eyeY * s, width: 2.5 * s, height: s), cornerRadius: 0), with: .color(Color(hex: "1a1a1a")))

        // "z" 闪烁：周期 0.5 秒
        let zOpacity = 0.3 + 0.4 * sin(t * .pi * 4)
        for i in 0..<3 {
            let zSize = size * (0.22 - CGFloat(i) * 0.03)
            context.draw(Text("z").font(.system(size: zSize, weight: .black)).foregroundColor(.white.opacity(zOpacity - CGFloat(i) * 0.1)), at: CGPoint(x: ox + (16 + CGFloat(i)) * s, y: oy + (3 - CGFloat(i) * 2.5) * s), anchor: .center)
        }
    }

    private func drawWorking(context: GraphicsContext) {
        // 弹跳动画：4Hz，幅度 1.5
        let bounce = 1.5 * sin(t * 2 * .pi * 4)
        let ox = (size - 16 * s) / 2
        let oy = (size - 11 * s) / 2 - 2 * s

        let shadowAlpha = 0.2 + 0.2 * (1 + sin(t * 2 * .pi * 4)) / 2
        context.fill(Path(roundedRect: CGRect(x: ox + 3 * s, y: oy + 15 * s, width: 9 * s, height: s), cornerRadius: 0), with: .color(.black.opacity(shadowAlpha)))

        for x in [3, 5, 9, 11] {
            context.fill(Path(roundedRect: CGRect(x: ox + CGFloat(x) * s, y: oy + 13 * s, width: s, height: 2 * s), cornerRadius: 0), with: .color(color))
        }

        context.fill(Path(roundedRect: CGRect(x: ox + 2 * s, y: oy + (6 + bounce) * s, width: 11 * s, height: 7 * s), cornerRadius: 0), with: .color(color))
        context.fill(Path(roundedRect: CGRect(x: ox + 4 * s, y: oy + (8 + bounce) * s, width: s, height: s), cornerRadius: 0), with: .color(Color(hex: "1a1a1a")))
        context.fill(Path(roundedRect: CGRect(x: ox + 10 * s, y: oy + (8 + bounce) * s, width: s, height: s), cornerRadius: 0), with: .color(Color(hex: "1a1a1a")))

        context.fill(Path(roundedRect: CGRect(x: ox - 0.5 * s, y: oy + 11.8 * s, width: 16 * s, height: 3.5 * s), cornerRadius: 0), with: .color(Color(hex: "616e7a")))

        // 键盘高亮：滚动效果
        let highlightCol = Int(t * 3) % 6
        for col in 0...5 {
            let keyX = ox + (0.3 + CGFloat(col) * 2.5) * s
            let isHighlight = col == highlightCol
            let keyColor = isHighlight ? Color(hex: "d4d4d4") : Color(hex: "9aa8b4")
            context.fill(Path(roundedRect: CGRect(x: keyX, y: oy + 12.2 * s, width: 2 * s, height: 0.7 * s), cornerRadius: 0), with: .color(keyColor))
            context.fill(Path(roundedRect: CGRect(x: keyX, y: oy + 13.2 * s, width: 2 * s, height: 0.7 * s), cornerRadius: 0), with: .color(keyColor))
        }

        context.fill(Path(roundedRect: CGRect(x: ox, y: oy + (9 + bounce) * s, width: 2 * s, height: 2 * s), cornerRadius: 0), with: .color(color))
        context.fill(Path(roundedRect: CGRect(x: ox + 13 * s, y: oy + (9 + bounce) * s, width: 2 * s, height: 2 * s), cornerRadius: 0), with: .color(color))
    }

    private func drawCompleted(context: GraphicsContext) {
        // 挥手动画：周期 1.5 秒
        let bounce = 1.5 * sin(t * 2 * .pi / 1.5)
        // 手臂摆动：周期 0.6 秒
        let armWave = 2.0 * sin(t * 2 * .pi / 0.6)

        let ox = (size - 17 * s) / 2
        let oy = (size - 14 * s) / 2 - 1 * s

        context.fill(Path(roundedRect: CGRect(x: ox + 3 * s, y: oy + 15 * s, width: 9 * s, height: s), cornerRadius: 0), with: .color(.black.opacity(0.3)))

        for x in [3, 5, 9, 11] {
            context.fill(Path(roundedRect: CGRect(x: ox + CGFloat(x) * s, y: oy + 11 * s, width: s, height: 3 * s), cornerRadius: 0), with: .color(color))
        }

        context.fill(Path(roundedRect: CGRect(x: ox + 2 * s, y: oy + 6 * s, width: 11 * s, height: 6 * s), cornerRadius: 0), with: .color(color))
        context.fill(Path(roundedRect: CGRect(x: ox + 3.5 * s, y: oy + 8 * s, width: s, height: s), cornerRadius: 0), with: .color(Color(hex: "1a1a1a")))
        context.fill(Path(roundedRect: CGRect(x: ox + 9.5 * s, y: oy + 8 * s, width: s, height: s), cornerRadius: 0), with: .color(Color(hex: "1a1a1a")))
        context.fill(Path(roundedRect: CGRect(x: ox + 6 * s, y: oy + 10 * s, width: 3 * s, height: 0.8 * s), cornerRadius: 0.4 * s), with: .color(Color(hex: "1a1a1a")))

        context.fill(Path(roundedRect: CGRect(x: ox - s, y: oy + (2 + armWave) * s, width: 2 * s, height: 5 * s), cornerRadius: 0), with: .color(color))
        context.fill(Path(roundedRect: CGRect(x: ox + 14 * s, y: oy + (2 - armWave) * s, width: 2 * s, height: 5 * s), cornerRadius: 0), with: .color(color))

        // 星星闪烁
        let starOn = sin(t * .pi * 2) > 0
        context.fill(Path(roundedRect: CGRect(x: ox - 2 * s, y: oy + s, width: s, height: s), cornerRadius: 0), with: .color(Color(hex: "fbbf24").opacity(starOn ? 1.0 : 0.3)))
        context.fill(Path(roundedRect: CGRect(x: ox + 16 * s, y: oy, width: 1.2 * s, height: 1.2 * s), cornerRadius: 0), with: .color(Color(hex: "fbbf24").opacity(starOn ? 0.3 : 1.0)))
    }
}

// MARK: - Color 扩展

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - 预览

extension ClaudeActivityAttributes {
    fileprivate static var preview: ClaudeActivityAttributes {
        ClaudeActivityAttributes(sessionId: "test", mascotColorHex: "E86B4A")
    }
}

extension ClaudeActivityAttributes.ContentState {
    fileprivate static var working: ClaudeActivityAttributes.ContentState {
        .init(
            status: .working,
            statusText: "工作中...",
            toolName: "Bash",
            activityContent: "npm install",
            activityType: .toolUse,
            sessionTitle: "性能优化",
            elapsedSeconds: 45,
            activeSessions: 2,
            totalSessions: 3,
            animationTimestamp: CACurrentMediaTime(),
            sessionSummaries: [
                SessionSummary(title: "性能优化", content: "正在分析代码结构，查找潜在的性能问题...", type: .thinking),
                SessionSummary(title: "API 集成", content: "Bash: npm install axios", type: .toolUse),
                SessionSummary(title: "文档编写", content: "生成 README.md 内容...", type: .streaming)
            ]
        )
    }
    fileprivate static var thinking: ClaudeActivityAttributes.ContentState {
        .init(
            status: .working,
            statusText: "工作中...",
            toolName: "",
            activityContent: "分析代码结构...",
            activityType: .thinking,
            sessionTitle: "性能优化",
            elapsedSeconds: 30,
            activeSessions: 1,
            totalSessions: 1,
            animationTimestamp: CACurrentMediaTime(),
            sessionSummaries: []
        )
    }
    fileprivate static var idle: ClaudeActivityAttributes.ContentState {
        .init(
            status: .idle,
            statusText: "休闲中",
            toolName: "",
            activityContent: "",
            activityType: .idle,
            sessionTitle: "Claude Code",
            elapsedSeconds: 0,
            activeSessions: 0,
            totalSessions: 1,
            animationTimestamp: CACurrentMediaTime(),
            sessionSummaries: []
        )
    }
    fileprivate static var completed: ClaudeActivityAttributes.ContentState {
        .init(
            status: .completed,
            statusText: "已完成",
            toolName: "",
            activityContent: "已成功优化数据库查询性能",
            activityType: .completed,
            sessionTitle: "性能优化",
            elapsedSeconds: 120,
            activeSessions: 0,
            totalSessions: 2,
            animationTimestamp: CACurrentMediaTime(),
            sessionSummaries: []
        )
    }
}

#Preview("Notification", as: .content, using: ClaudeActivityAttributes.preview) {
    ClaudeWidgetLiveActivity()
} contentStates: {
    ClaudeActivityAttributes.ContentState.idle
    ClaudeActivityAttributes.ContentState.thinking
    ClaudeActivityAttributes.ContentState.working
    ClaudeActivityAttributes.ContentState.completed
}
