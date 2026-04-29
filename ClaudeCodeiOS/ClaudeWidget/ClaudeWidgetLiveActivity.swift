//
//  ClaudeWidgetLiveActivity.swift
//  ClaudeWidget
//
//  简化版：三个状态（休闲中、工作中、已完成）
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - 活动属性

struct ClaudeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: ClaudeWorkStatus
        var statusText: String
        var lastMessage: String
        var sessionTitle: String
        var elapsedSeconds: Int
        var completedTasks: Int
        var totalTasks: Int
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

// MARK: - Live Activity Widget

struct ClaudeWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClaudeActivityAttributes.self) { context in
            HStack(spacing: 12) {
                MascotView(
                    status: context.state.status,
                    color: Color(hex: context.attributes.mascotColorHex),
                    size: 36,
                    frame: context.state.elapsedSeconds
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.sessionTitle)
                        .font(.headline)
                        .lineLimit(1)

                    Text(context.state.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(context.state.completedTasks)/\(context.state.totalTasks)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(context.state.status == .completed ? .green : .primary)
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
                        frame: context.state.elapsedSeconds
                    )
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.completedTasks)/\(context.state.totalTasks)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(context.state.status == .completed ? .green : .primary)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.sessionTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        Text(context.state.statusText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                MascotView(
                    status: context.state.status,
                    color: Color(hex: context.attributes.mascotColorHex),
                    size: 24,
                    frame: context.state.elapsedSeconds
                )
            } compactTrailing: {
                Text("\(context.state.completedTasks)/\(context.state.totalTasks)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(context.state.status == .completed ? .green : .primary)
            } minimal: {
                Text("\(context.state.completedTasks)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(context.state.status == .completed ? .green : .primary)
            }
        }
    }
}

// MARK: - 吉祥物视图（三个状态）

struct MascotView: View {
    let status: ClaudeWorkStatus
    let color: Color
    var size: CGFloat = 28
    var frame: Int = 0

    // elapsedSeconds 每 0.5 秒增加 1，所以 t 是实际秒数
    private var t: Double { Double(frame) * 0.5 }

    var body: some View {
        Canvas { context, canvasSize in
            switch status {
            case .idle:
                drawIdle(context: context)       // 休闲中：睡眠呼吸 + ZZZ
            case .working:
                drawWorking(context: context)    // 工作中：敲键盘
            case .completed:
                drawCompleted(context: context)  // 已完成：庆祝挥手
            }
        }
        .frame(width: size, height: size)
    }

    private var s: CGFloat { size / 20 }

    // MARK: - 呼吸脉冲

    private var breathPulse: CGFloat {
        let phase = t.truncatingRemainder(dividingBy: 2.0) / 2.0
        return (sin(phase * 2 * .pi) + 1) / 2
    }

    private var fastPulse: CGFloat {
        let phase = t.truncatingRemainder(dividingBy: 0.5) / 0.5
        return (sin(phase * 2 * .pi) + 1) / 2
    }

    private var gentlePulse: CGFloat {
        let phase = t.truncatingRemainder(dividingBy: 1.0) / 1.0
        return (sin(phase * 2 * .pi) + 1) / 2
    }

    // MARK: - 1. 休闲状态：睡眠呼吸 + ZZZ

    private func drawIdle(context: GraphicsContext) {
        let bodyScale = 0.9 + breathPulse * 0.1
        let bodyH = 7 * s * bodyScale

        // 身体
        context.fill(
            RoundedRectangle(cornerRadius: 2 * s)
                .path(in: CGRect(x: 4 * s, y: size - 6 * s - bodyH, width: 12 * s, height: bodyH)),
            with: .color(color)
        )

        // 闭眼
        let eyeY = size - 8 * s - bodyH * 0.3
        context.fill(Capsule().path(in: CGRect(x: 6.5 * s, y: eyeY, width: 3 * s, height: 1.2 * s)), with: .color(Color(hex: "1a1a1a")))
        context.fill(Capsule().path(in: CGRect(x: 10.5 * s, y: eyeY, width: 3 * s, height: 1.2 * s)), with: .color(Color(hex: "1a1a1a")))

        // ZZZ
        for i in 0..<3 {
            let zPhase = (t + Double(i) * 0.5).truncatingRemainder(dividingBy: 2.0) / 2.0
            let zOpacity = (sin(zPhase * 2 * .pi) + 1) / 2 * 0.6
            let zSize = CGFloat(10 - i * 2)
            context.draw(
                Text("z").font(.system(size: zSize, weight: .bold)).foregroundColor(.white.opacity(zOpacity)),
                at: CGPoint(x: 16 * s, y: CGFloat(2 + i * 3) * s),
                anchor: .topLeading
            )
        }
    }

    // MARK: - 2. 工作状态：敲键盘

    private func drawWorking(context: GraphicsContext) {
        let bounce = (fastPulse - 0.5) * 3 * s

        // 影子
        context.fill(
            Ellipse().path(in: CGRect(x: 5 * s, y: size - 3 * s, width: 10 * s, height: 2 * s)),
            with: .color(Color.black.opacity(0.2))
        )

        // 身体
        let bodyY = size / 2 - 4 * s + bounce
        context.fill(
            RoundedRectangle(cornerRadius: 2 * s)
                .path(in: CGRect(x: 4 * s, y: bodyY, width: 12 * s, height: 7 * s)),
            with: .color(color)
        )

        // 眼睛
        let eyeY = bodyY + 2 * s
        context.fill(RoundedRectangle(cornerRadius: 0.2 * s).path(in: CGRect(x: 7 * s, y: eyeY, width: s, height: s)), with: .color(Color(hex: "1a1a1a")))
        context.fill(RoundedRectangle(cornerRadius: 0.2 * s).path(in: CGRect(x: 12 * s, y: eyeY, width: s, height: s)), with: .color(Color(hex: "1a1a1a")))

        // 键盘
        context.fill(RoundedRectangle(cornerRadius: s).path(in: CGRect(x: 3 * s, y: size - 5 * s, width: 14 * s, height: 3 * s)), with: .color(Color(hex: "404040")))

        // 按键闪烁
        for i in 0..<5 {
            let keyPulse = (sin(t * 6 + Double(i) * 0.8) + 1) / 2
            let keyX = 4 * s + CGFloat(i) * 2.5 * s
            context.fill(
                RoundedRectangle(cornerRadius: 0.3 * s)
                    .path(in: CGRect(x: keyX, y: size - 4.5 * s, width: 2 * s, height: s)),
                with: .color(Color(hex: "808080").opacity(0.5 + keyPulse * 0.5))
            )
        }

        // 手臂
        let armY = bodyY + 4 * s
        context.fill(RoundedRectangle(cornerRadius: 0.5 * s).path(in: CGRect(x: 2 * s, y: armY, width: 2 * s, height: 2 * s)), with: .color(color))
        context.fill(RoundedRectangle(cornerRadius: 0.5 * s).path(in: CGRect(x: 16 * s, y: armY, width: 2 * s, height: 2 * s)), with: .color(color))
    }

    // MARK: - 3. 完成状态：庆祝 + 星星

    private func drawCompleted(context: GraphicsContext) {
        let bounce = (gentlePulse - 0.5) * s
        let wave = sin(t * 4 * .pi) * 2 * s

        // 身体
        let bodyY = size / 2 - 2 * s + bounce
        context.fill(
            RoundedRectangle(cornerRadius: 2 * s)
                .path(in: CGRect(x: 4 * s, y: bodyY, width: 12 * s, height: 6 * s)),
            with: .color(color)
        )

        // 开心眼睛
        let eyeY = bodyY + 2 * s
        context.fill(RoundedRectangle(cornerRadius: 0.2 * s).path(in: CGRect(x: 7 * s, y: eyeY, width: s, height: s)), with: .color(Color(hex: "1a1a1a")))
        context.fill(RoundedRectangle(cornerRadius: 0.2 * s).path(in: CGRect(x: 12 * s, y: eyeY, width: s, height: s)), with: .color(Color(hex: "1a1a1a")))

        // 微笑
        context.fill(Capsule().path(in: CGRect(x: 8 * s, y: eyeY + 2 * s, width: 4 * s, height: s * 0.8)), with: .color(Color(hex: "1a1a1a")))

        // 手臂挥舞
        context.fill(RoundedRectangle(cornerRadius: 0.5 * s).path(in: CGRect(x: 1 * s, y: 1 * s + wave, width: 2 * s, height: 5 * s)), with: .color(color))
        context.fill(RoundedRectangle(cornerRadius: 0.5 * s).path(in: CGRect(x: 17 * s, y: 1 * s - wave, width: 2 * s, height: 5 * s)), with: .color(color))

        // 星星（交替闪烁）
        let star1 = gentlePulse
        let star2 = 1 - gentlePulse
        context.fill(RoundedRectangle(cornerRadius: 0.3 * s).path(in: CGRect(x: 0, y: 0, width: 1.5 * s, height: 1.5 * s)), with: .color(Color(hex: "fbbf24").opacity(star1)))
        context.fill(RoundedRectangle(cornerRadius: 0.3 * s).path(in: CGRect(x: 18 * s, y: 0, width: 1.5 * s, height: 1.5 * s)), with: .color(Color(hex: "fbbf24").opacity(star2)))
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
        .init(status: .working, statusText: "工作中...", lastMessage: "", sessionTitle: "测试", elapsedSeconds: 45, completedTasks: 1, totalTasks: 2)
    }
    fileprivate static var idle: ClaudeActivityAttributes.ContentState {
        .init(status: .idle, statusText: "休闲中", lastMessage: "", sessionTitle: "测试", elapsedSeconds: 0, completedTasks: 0, totalTasks: 1)
    }
    fileprivate static var completed: ClaudeActivityAttributes.ContentState {
        .init(status: .completed, statusText: "已完成", lastMessage: "完成", sessionTitle: "测试", elapsedSeconds: 120, completedTasks: 2, totalTasks: 2)
    }
}

#Preview("Notification", as: .content, using: ClaudeActivityAttributes.preview) {
    ClaudeWidgetLiveActivity()
} contentStates: {
    ClaudeActivityAttributes.ContentState.idle
    ClaudeActivityAttributes.ContentState.working
    ClaudeActivityAttributes.ContentState.completed
}
