// 戴安娜 Logo 动画组件
// Claude Logo with tentacle animation

import SwiftUI

// MARK: - Claude Logo Widget

struct ClaudeLogoWidget: View {
    var size: CGFloat = 40
    var color: Color = Color(red: 0.851, green: 0.467, blue: 0.341) // #D97757
    var mode: ClaudeLogoMode = .idle

    var body: some View {
        ClaudeLogo(size: size, color: color, mode: mode)
    }
}

// MARK: - Logo Mode

enum ClaudeLogoMode {
    case idle      // 静态
    case thinking  // 螺旋旋转
    case waiting   // 呼吸效果
}

// MARK: - Claude Logo

struct ClaudeLogo: View {
    let size: CGFloat
    let color: Color
    let mode: ClaudeLogoMode

    // 动画状态
    @State private var progress: Double = 0
    @State private var breathe: Double = 1

    // 核心参数
    private let coreRadius: CGFloat = 27.2
    private let rootWidthScale: CGFloat = 1.1
    private let tipWidthScale: CGFloat = 1.3

    // 触手初始数据
    private var initialTentacles: [TentacleData] {
        [
        TentacleData(id: 1, angle: -176.8, length: 82.0, baseW: 10.0, tipW: 11.2),
        TentacleData(id: 2, angle: -144.1, length: 83.6, baseW: 16.5, tipW: 19.1),
        TentacleData(id: 3, angle: -117.6, length: 89.2, baseW: 17.9, tipW: 23.6),
        TentacleData(id: 4, angle: -82.1, length: 73.2, baseW: 13.2, tipW: 16.6),
        TentacleData(id: 5, angle: -50.8, length: 73.4, baseW: 26.5, tipW: 21.5),
        TentacleData(id: 6, angle: -10.9, length: 67.7, baseW: 15.2, tipW: 13.7),
        TentacleData(id: 7, angle: 9.1, length: 69.3, baseW: 9.8, tipW: 18.2),
        TentacleData(id: 8, angle: 40.6, length: 71.1, baseW: 13.4, tipW: 8.9),
        TentacleData(id: 9, angle: 56.2, length: 68.2, baseW: 18.0, tipW: 15.3),
        TentacleData(id: 10, angle: 98.5, length: 73.8, baseW: 9.8, tipW: 15.7),
        TentacleData(id: 11, angle: 128.1, length: 77.6, baseW: 13.5, tipW: 11.8),
        TentacleData(id: 12, angle: 148.1, length: 75.0, baseW: 13.6, tipW: 14.4)
    ].map { TentacleData(
        id: $0.id,
        angle: $0.angle,
        length: $0.length,
        baseW: $0.baseW * rootWidthScale,
        tipW: $0.tipW * tipWidthScale
    )}
    }

    private var maxRadius: CGFloat {
        (initialTentacles.map { $0.length }.max() ?? 80) + coreRadius + 20
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / (maxRadius * 2)
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

            var transformedContext = context
            transformedContext.translateBy(x: center.x, y: center.y)
            transformedContext.scaleBy(x: scale, y: scale)

            // 绘制触手
            for tentacle in initialTentacles {
                let path = generateTentaclePath(
                    tentacle: tentacle,
                    progress: progress,
                    breathe: breathe,
                    mode: mode
                )
                transformedContext.fill(path, with: .color(color))
            }

            // 绘制核心圆
            let corePath = Path { p in
                p.addEllipse(in: CGRect(
                    x: -coreRadius,
                    y: -coreRadius,
                    width: coreRadius * 2,
                    height: coreRadius * 2
                ))
            }
            transformedContext.fill(corePath, with: .color(color))
        }
        .frame(width: size, height: size)
        .onAppear {
            startAnimation()
        }
        .onChange(of: mode) { _, _ in
            startAnimation()
        }
    }

    private func startAnimation() {
        switch mode {
        case .idle:
            withAnimation(.easeOut(duration: 0.3)) {
                progress = 0
                breathe = 1
            }
        case .thinking:
            // 螺旋旋转动画
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                progress = 1
            }
        case .waiting:
            // 呼吸动画
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
            ) {
                breathe = 0.7
            }
        }
    }

    private func generateTentaclePath(
        tentacle: TentacleData,
        progress: Double,
        breathe: Double,
        mode: ClaudeLogoMode
    ) -> Path {
        var animLength = tentacle.length
        var animBaseW = tentacle.baseW
        var animTipW = tentacle.tipW

        if mode == .thinking {
            // 螺旋效果
            let angleRad = tentacle.angle * .pi / 180
            let rotSpeed = progress * .pi * 2
            let spiralPhase = ((angleRad - rotSpeed).truncatingRemainder(dividingBy: .pi * 2) + .pi * 2).truncatingRemainder(dividingBy: .pi * 2)
            let normPhase = spiralPhase / (.pi * 2)

            var smoothK: Double
            if normPhase < 0.85 {
                smoothK = 0.45 + 0.85 * (normPhase / 0.85)
            } else {
                let p = (normPhase - 0.85) / 0.15
                smoothK = 1.3 - 0.85 * p
            }

            animLength = tentacle.length * smoothK
            let w_k = 0.9 + 0.25 * (smoothK - 0.45)
            animBaseW = tentacle.baseW * w_k
            animTipW = tentacle.tipW * w_k
        } else if mode == .waiting {
            // 呼吸效果
            animLength = tentacle.length * breathe
        }

        return createTentaclePath(
            angle: tentacle.angle,
            length: animLength,
            baseW: animBaseW,
            tipW: animTipW
        )
    }

    private func createTentaclePath(
        angle: Double,
        length: Double,
        baseW: Double,
        tipW: Double
    ) -> Path {
        let fillet: CGFloat = 6.0
        let rad = angle * .pi / 180
        let dirX = cos(rad)
        let dirY = sin(rad)
        let normX = -sin(rad)
        let normY = cos(rad)
        let rRoot = coreRadius
        let rTip = coreRadius + max(0, length)

        let hw = min(baseW / 2, rRoot * 0.95)
        let theta = asin(hw / rRoot)

        let B1 = CGPoint(
            x: rRoot * cos(rad + theta),
            y: rRoot * sin(rad + theta)
        )
        let B2 = CGPoint(
            x: rRoot * cos(rad - theta),
            y: rRoot * sin(rad - theta)
        )

        let Tip1 = CGPoint(
            x: dirX * rTip + normX * (tipW / 2),
            y: dirY * rTip + normY * (tipW / 2)
        )
        let Tip2 = CGPoint(
            x: dirX * rTip - normX * (tipW / 2),
            y: dirY * rTip - normY * (tipW / 2)
        )

        let len1 = max(1, sqrt(pow(Tip1.x - B1.x, 2) + pow(Tip1.y - B1.y, 2)))
        let U1 = CGPoint(x: (Tip1.x - B1.x) / len1, y: (Tip1.y - B1.y) / len1)
        let len2 = max(1, sqrt(pow(Tip2.x - B2.x, 2) + pow(Tip2.y - B2.y, 2)))
        let U2 = CGPoint(x: (Tip2.x - B2.x) / len2, y: (Tip2.y - B2.y) / len2)

        let segments = 3 + Int(angle) % 3

        var path = Path()
        let startAngle = rad + theta + fillet / rRoot
        path.move(to: CGPoint(
            x: rRoot * cos(startAngle),
            y: rRoot * sin(startAngle)
        ))

        // 曲线到 B1
        path.addQuadCurve(
            to: CGPoint(x: B1.x + U1.x * fillet, y: B1.y + U1.y * fillet),
            control: B1
        )

        // 直线到 Tip1
        path.addLine(to: Tip1)

        // 顶端的弧
        for i in 1..<segments {
            let ang = (rad + .pi / 2) + (-.pi) * Double(i) / Double(segments)
            path.addLine(to: CGPoint(
                x: dirX * rTip + cos(ang) * (tipW / 2),
                y: dirY * rTip + sin(ang) * (tipW / 2)
            ))
        }

        // 直线到 Tip2
        path.addLine(to: Tip2)

        // 直线到 B2
        path.addLine(to: CGPoint(x: B2.x + U2.x * fillet, y: B2.y + U2.y * fillet))

        // 曲线回到起点
        let endAngle = rad - theta - fillet / rRoot
        path.addQuadCurve(
            to: CGPoint(
                x: rRoot * cos(endAngle),
                y: rRoot * sin(endAngle)
            ),
            control: B2
        )

        path.closeSubpath()

        return path
    }
}

// MARK: - Tentacle Data

struct TentacleData {
    let id: Int
    let angle: Double
    let length: Double
    let baseW: Double
    let tipW: Double
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // 静态
        VStack {
            ClaudeLogoWidget(size: 60, mode: .idle)
            Text("Idle")
                .font(.caption)
                .foregroundColor(.secondary)
        }

        // 思考中
        VStack {
            ClaudeLogoWidget(size: 60, mode: .thinking)
            Text("Thinking")
                .font(.caption)
                .foregroundColor(.secondary)
        }

        // 等待中
        VStack {
            ClaudeLogoWidget(size: 60, mode: .waiting)
            Text("Waiting")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
}
