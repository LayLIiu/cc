// 像素风格吉祥物

import SwiftUI

enum MascotStatus {
    case idle
    case processing
    case waitingApproval
    case completed
}

struct PixelMascot: View {
    var size: CGFloat = 27
    var status: MascotStatus = .idle
    var bodyColor: Color = Color(hex: "E86B4A")

    let eyeColor = Color(hex: "1a1a1a")
    let alertColor = Color(hex: "FF3D00")
    let kbBaseColor = Color(hex: "616e7a")
    let kbKeyColor = Color(hex: "9aa8b4")
    let successColor = Color(hex: "22c55e")
    let starColor = Color(hex: "fbbf24")

    var body: some View {
        ZStack {
            TimelineView(.animation) { timeline in
                Canvas { context, canvasSize in
                    let time = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100)

                    switch status {
                    case .idle:
                        drawSleepingMascot(context: context, size: size, time: time, bodyColor: bodyColor, eyeColor: eyeColor)
                    case .processing:
                        drawWorkingMascot(context: context, size: size, time: CGFloat(time), bodyColor: bodyColor, eyeColor: eyeColor, kbBaseColor: kbBaseColor, kbKeyColor: kbKeyColor)
                    case .waitingApproval:
                        drawAlertMascot(context: context, size: size, time: CGFloat(time), bodyColor: bodyColor, eyeColor: eyeColor, alertColor: alertColor)
                    case .completed:
                        drawCompletedMascot(context: context, size: size, time: CGFloat(time), bodyColor: bodyColor, eyeColor: eyeColor, successColor: successColor, starColor: starColor)
                    }
                }
            }

            // ZZZ 睡眠符号 (idle 状态)
            if status == .idle {
                ZzzView(size: size)
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - 睡眠状态绘制

    private func drawSleepingMascot(context: GraphicsContext, size: CGFloat, time: TimeInterval, bodyColor: Color, eyeColor: Color) {
        let s = size / 17
        let ox = (size - 17 * s) / 2
        let oy = (size - 7 * s) / 2 - 4 * s  // 往上移 2s

        // 呼吸动画 - 周期 2 秒
        let breathe = (sin(time * .pi) + 1) / 2
        let puff = breathe * 0.25

        // 影子
        context.fill(
            Path(roundedRect: CGRect(x: ox, y: oy + 15 * s, width: 17 * s, height: s), cornerRadius: 0),
            with: .color(.black.opacity(0.35))
        )

        // 腿
        for x in [3, 5, 9, 11] {
            context.fill(
                Path(roundedRect: CGRect(x: ox + CGFloat(x) * s, y: oy + 8.5 * s, width: s, height: 1.5 * s), cornerRadius: 0),
                with: .color(bodyColor)
            )
        }

        // 身体 - 呼吸效果
        let torsoH = 5 * (1.0 + puff)
        let torsoY = 15 - torsoH
        let torsoW = 13 * (1.0 + breathe * 0.015)
        let torsoX = 1 - (torsoW - 13) / 2

        context.fill(
            Path(roundedRect: CGRect(x: ox + torsoX * s, y: oy + torsoY * s, width: torsoW * s, height: torsoH * s), cornerRadius: 0),
            with: .color(bodyColor)
        )

        // 手臂
        context.fill(
            Path(roundedRect: CGRect(x: ox - s, y: oy + 13 * s, width: 2 * s, height: 2 * s), cornerRadius: 0),
            with: .color(bodyColor)
        )
        context.fill(
            Path(roundedRect: CGRect(x: ox + 14 * s, y: oy + 13 * s, width: 2 * s, height: 2 * s), cornerRadius: 0),
            with: .color(bodyColor)
        )

        // 眼睛（闭着的）
        let eyeY = 12.2 - puff * 2.5
        context.fill(
            Path(roundedRect: CGRect(x: ox + 3 * s, y: oy + eyeY * s, width: 2.5 * s, height: s), cornerRadius: 0),
            with: .color(eyeColor)
        )
        context.fill(
            Path(roundedRect: CGRect(x: ox + 9.5 * s, y: oy + eyeY * s, width: 2.5 * s, height: s), cornerRadius: 0),
            with: .color(eyeColor)
        )
    }

    // MARK: - 工作状态绘制

    private func drawWorkingMascot(context: GraphicsContext, size: CGFloat, time: CGFloat, bodyColor: Color, eyeColor: Color, kbBaseColor: Color, kbKeyColor: Color) {
        let s = size / 16
        let ox = (size - 16 * s) / 2
        let oy = (size - 11 * s) / 2 - 2 * s

        let bounce = sin(time * 2 * .pi * 4) * 1.5

        // 影子
        context.fill(
            Path(roundedRect: CGRect(x: ox + 3 * s, y: oy + 15 * s, width: 9 * s, height: s), cornerRadius: 0),
            with: .color(.black.opacity(0.4))
        )

        // 腿
        for x in [3, 5, 9, 11] {
            context.fill(
                Path(roundedRect: CGRect(x: ox + CGFloat(x) * s, y: oy + 13 * s, width: s, height: 2 * s), cornerRadius: 0),
                with: .color(bodyColor)
            )
        }

        // 身体
        context.fill(
            Path(roundedRect: CGRect(x: ox + 2 * s, y: oy + (6 + bounce) * s, width: 11 * s, height: 7 * s), cornerRadius: 0),
            with: .color(bodyColor)
        )

        // 眼睛
        context.fill(
            Path(roundedRect: CGRect(x: ox + 4 * s, y: oy + (8 + bounce) * s, width: s, height: s), cornerRadius: 0),
            with: .color(eyeColor)
        )
        context.fill(
            Path(roundedRect: CGRect(x: ox + 10 * s, y: oy + (8 + bounce) * s, width: s, height: s), cornerRadius: 0),
            with: .color(eyeColor)
        )

        // 键盘底座
        context.fill(
            Path(roundedRect: CGRect(x: ox - 0.5 * s, y: oy + 11.8 * s, width: 16 * s, height: 3.5 * s), cornerRadius: 0),
            with: .color(kbBaseColor)
        )

        // 键盘按键
        for col in 0...5 {
            let keyX = ox + (0.3 + CGFloat(col) * 2.5) * s
            context.fill(
                Path(roundedRect: CGRect(x: keyX, y: oy + 12.2 * s, width: 2 * s, height: 0.7 * s), cornerRadius: 0),
                with: .color(kbKeyColor)
            )
            context.fill(
                Path(roundedRect: CGRect(x: keyX, y: oy + 13.2 * s, width: 2 * s, height: 0.7 * s), cornerRadius: 0),
                with: .color(kbKeyColor)
            )
        }

        // 手臂
        context.fill(
            Path(roundedRect: CGRect(x: ox, y: oy + (9 + bounce) * s, width: 2 * s, height: 2 * s), cornerRadius: 0),
            with: .color(bodyColor)
        )
        context.fill(
            Path(roundedRect: CGRect(x: ox + 13 * s, y: oy + (9 + bounce) * s, width: 2 * s, height: 2 * s), cornerRadius: 0),
            with: .color(bodyColor)
        )
    }

    // MARK: - 警告状态绘制

    private func drawAlertMascot(context: GraphicsContext, size: CGFloat, time: CGFloat, bodyColor: Color, eyeColor: Color, alertColor: Color) {
        let s = size / 15
        let ox = (size - 15 * s) / 2
        let oy = (size - 12 * s) / 2 - 2 * s

        // 计算跳跃 - 周期 1.75 秒
        let pct = (time.truncatingRemainder(dividingBy: 1.75)) / 1.75
        let jumpY = interpolateKeyframes(pct: pct, keyframes: [
            (0, 0), (0.03, 0), (0.10, -1), (0.15, 1.5),
            (0.175, -10), (0.20, -10), (0.25, 1.5),
            (0.275, -8), (0.30, -8), (0.35, 1.2),
            (0.375, -5), (0.40, -5), (0.45, 1.0),
            (0.475, -3), (0.50, -3), (0.55, 0.5),
            (0.62, 0), (1.0, 0)
        ])

        // 影子
        context.fill(
            Path(roundedRect: CGRect(x: ox + 3 * s, y: oy + 15 * s, width: 9 * s, height: s), cornerRadius: 0),
            with: .color(.black.opacity(0.4))
        )

        // 腿
        for x in [3, 5, 9, 11] {
            context.fill(
                Path(roundedRect: CGRect(x: ox + CGFloat(x) * s, y: oy + (11 + jumpY) * s, width: s, height: 4 * s), cornerRadius: 0),
                with: .color(bodyColor)
            )
        }

        // 身体
        context.fill(
            Path(roundedRect: CGRect(x: ox + 2 * s, y: oy + (6 + jumpY) * s, width: 11 * s, height: 7 * s), cornerRadius: 0),
            with: .color(bodyColor)
        )

        // 大眼睛
        context.fill(
            Path(roundedRect: CGRect(x: ox + 4 * s, y: oy + (8 + jumpY) * s, width: s, height: 2.5 * s), cornerRadius: 0),
            with: .color(eyeColor)
        )
        context.fill(
            Path(roundedRect: CGRect(x: ox + 10 * s, y: oy + (8 + jumpY) * s, width: s, height: 2.5 * s), cornerRadius: 0),
            with: .color(eyeColor)
        )

        // 手臂
        context.fill(
            Path(roundedRect: CGRect(x: ox, y: oy + (4 + jumpY) * s, width: 2 * s, height: 2 * s), cornerRadius: 0),
            with: .color(bodyColor)
        )
        context.fill(
            Path(roundedRect: CGRect(x: ox + 13 * s, y: oy + (4 + jumpY) * s, width: 2 * s, height: 2 * s), cornerRadius: 0),
            with: .color(bodyColor)
        )

        // 警告符号
        let bangOpacity = (pct >= 0.03 && pct < 0.55) ? 1.0 : 0.0
        context.fill(
            Path(roundedRect: CGRect(x: ox + 13 * s, y: oy + 2 * s, width: 2 * s, height: 3.5 * s), cornerRadius: 0),
            with: .color(alertColor.opacity(bangOpacity))
        )
        context.fill(
            Path(roundedRect: CGRect(x: ox + 13 * s, y: oy + 6 * s, width: 2 * s, height: 1.5 * s), cornerRadius: 0),
            with: .color(alertColor.opacity(bangOpacity))
        )
    }

    // MARK: - 完成状态绘制

    private func drawCompletedMascot(context: GraphicsContext, size: CGFloat, time: CGFloat, bodyColor: Color, eyeColor: Color, successColor: Color, starColor: Color) {
        let s = size / 17
        let ox = (size - 17 * s) / 2
        let oy = (size - 14 * s) / 2 - 1 * s

        let bounce = sin(time * 2 * .pi / 1.5) * 1
        let armWave = sin(time * 2 * .pi / 0.6) * 0.5

        // 影子
        context.fill(
            Path(roundedRect: CGRect(x: ox + 3 * s, y: oy + 15 * s, width: 9 * s, height: s), cornerRadius: 0),
            with: .color(.black.opacity(0.3))
        )

        // 腿
        for x in [3, 5, 9, 11] {
            context.fill(
                Path(roundedRect: CGRect(x: ox + CGFloat(x) * s, y: oy + (11 + bounce * 0.3) * s, width: s, height: 3 * s), cornerRadius: 0),
                with: .color(bodyColor)
            )
        }

        // 身体
        context.fill(
            Path(roundedRect: CGRect(x: ox + 2 * s, y: oy + (6 + bounce) * s, width: 11 * s, height: 6 * s), cornerRadius: 0),
            with: .color(bodyColor)
        )

        // 开心的眼睛
        context.fill(
            Path(roundedRect: CGRect(x: ox + 3.5 * s, y: oy + (8 + bounce) * s, width: s, height: s), cornerRadius: 0),
            with: .color(eyeColor)
        )
        context.fill(
            Path(roundedRect: CGRect(x: ox + 4.5 * s, y: oy + (7.5 + bounce) * s, width: 0.5 * s, height: 0.5 * s), cornerRadius: 0),
            with: .color(eyeColor)
        )
        context.fill(
            Path(roundedRect: CGRect(x: ox + 9.5 * s, y: oy + (8 + bounce) * s, width: s, height: s), cornerRadius: 0),
            with: .color(eyeColor)
        )
        context.fill(
            Path(roundedRect: CGRect(x: ox + 9 * s, y: oy + (7.5 + bounce) * s, width: 0.5 * s, height: 0.5 * s), cornerRadius: 0),
            with: .color(eyeColor)
        )

        // 微笑
        context.fill(
            Path(roundedRect: CGRect(x: ox + 6 * s, y: oy + (10 + bounce) * s, width: 3 * s, height: 0.8 * s), cornerRadius: 0.4 * s),
            with: .color(eyeColor)
        )

        // 举起的手臂 - 庆祝
        context.fill(
            Path(roundedRect: CGRect(x: ox - s, y: oy + (2 + bounce + armWave) * s, width: 2 * s, height: 5 * s), cornerRadius: 0),
            with: .color(bodyColor)
        )
        context.fill(
            Path(roundedRect: CGRect(x: ox + 14 * s, y: oy + (2 + bounce - armWave) * s, width: 2 * s, height: 5 * s), cornerRadius: 0),
            with: .color(bodyColor)
        )

        // 星星
        let starOpacity = 0.5 + sin(time * 2 * .pi / 0.3) * 0.5
        context.fill(
            Path(roundedRect: CGRect(x: ox - 2 * s, y: oy + s, width: s, height: s), cornerRadius: 0),
            with: .color(starColor.opacity(starOpacity))
        )
        context.fill(
            Path(roundedRect: CGRect(x: ox + 16 * s, y: oy, width: 1.2 * s, height: 1.2 * s), cornerRadius: 0),
            with: .color(starColor.opacity(starOpacity))
        )
    }

    // MARK: - 辅助函数

    private func interpolateKeyframes(pct: CGFloat, keyframes: [(CGFloat, CGFloat)]) -> CGFloat {
        for i in 1..<keyframes.count {
            if pct <= keyframes[i].0 {
                let t = (pct - keyframes[i-1].0) / (keyframes[i].0 - keyframes[i-1].0)
                return keyframes[i-1].1 + (keyframes[i].1 - keyframes[i-1].1) * t
            }
        }
        return keyframes.last?.1 ?? 0
    }
}

// MARK: - ZZZ 睡眠动画

struct ZzzView: View {
    let size: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                // 第一个 z
                let phase0 = (time.truncatingRemainder(dividingBy: 3)) / 3
                let p0 = max(0, min(1, phase0))
                Text("z")
                    .font(.system(size: size * 0.22, weight: .black))
                    .foregroundColor(.white)
                    .opacity(p0 < 0.8 ? 0.7 : (1 - p0) * 3.5 * 0.7)
                    .offset(
                        x: size * 0.35 - size * 0.1,
                        y: -size * 0.1 - p0 * size * 0.5
                    )

                // 第二个 z
                let phase1 = max(0, (time - 0.9).truncatingRemainder(dividingBy: 3)) / 3
                let p1 = min(1, phase1)
                Text("z")
                    .font(.system(size: size * 0.18, weight: .black))
                    .foregroundColor(.white)
                    .opacity(p1 < 0.8 ? 0.6 : (1 - p1) * 3.5 * 0.6)
                    .offset(
                        x: size * 0.45 - size * 0.1,
                        y: -size * 0.1 - p1 * size * 0.5
                    )

                // 第三个 z
                let phase2 = max(0, (time - 1.8).truncatingRemainder(dividingBy: 3)) / 3
                let p2 = min(1, phase2)
                Text("z")
                    .font(.system(size: size * 0.14, weight: .black))
                    .foregroundColor(.white)
                    .opacity(p2 < 0.8 ? 0.5 : (1 - p2) * 3.5 * 0.5)
                    .offset(
                        x: size * 0.55 - size * 0.1,
                        y: -size * 0.1 - p2 * size * 0.5
                    )
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        PixelMascot(status: .idle)
        PixelMascot(status: .processing)
        PixelMascot(status: .waitingApproval)
        PixelMascot(status: .completed)
    }
    .padding()
}
