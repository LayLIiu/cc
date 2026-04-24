import React, { useEffect } from 'react'
import { View, StyleSheet, Text } from 'react-native'
import Svg, { Rect, Circle } from 'react-native-svg'
import Animated, {
  useSharedValue,
  useDerivedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  withSequence,
  Easing,
  cancelAnimation,
  withSpring,
  withDelay,
} from 'react-native-reanimated'

const AnimatedRect = Animated.createAnimatedComponent(Rect)

export type MascotStatus = 'idle' | 'processing' | 'waitingApproval' | 'completed'

interface PixelMascotProps {
  size?: number
  status?: MascotStatus
  color?: string
}

// Colors from CodeIsland
const BODY_COLOR = '#DE886D'
const EYE_COLOR = '#1a1a1a'
const ALERT_COLOR = '#FF3D00'
const KB_BASE_COLOR = '#616e7a'
const KB_KEY_COLOR = '#9aa8b4'
const KB_HI_COLOR = '#ffffff'
const SUCCESS_COLOR = '#22c55e'
const STAR_COLOR = '#fbbf24'

// Sleeping mascot
const SleepingMascot = ({
  size,
  breathe,
  bodyColor,
}: {
  size: number
  breathe: Animated.SharedValue<number>
  bodyColor: string
}) => {
  const svgW = 17
  const svgH = 7
  const svgY0 = 9
  const s = Math.min(size / svgW, size / svgH)
  const ox = (size - svgW * s) / 2
  const oy = (size - svgH * s) / 2

  const torsoH = useDerivedValue(() => {
    const puff = Math.max(0, breathe.value) * 0.25
    return 5 * (1.0 + puff)
  })

  const torsoY = useDerivedValue(() => {
    const puff = Math.max(0, breathe.value) * 0.25
    return 15 - 5 * (1.0 + puff)
  })

  const torsoW = useDerivedValue(() => {
    return 13 * (1.0 + breathe.value * 0.015)
  })

  const torsoX = useDerivedValue(() => {
    const w = 13 * (1.0 + breathe.value * 0.015)
    return 1 - (w - 13) / 2
  })

  const eyeY = useDerivedValue(() => {
    const puff = Math.max(0, breathe.value) * 0.25
    return 12.2 - puff * 2.5
  })

  return (
    <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      {/* Shadow */}
      <Rect
        x={ox + -1 * s}
        y={oy + (15 - svgY0) * s}
        width={17 * s}
        height={s}
        fill="black"
        opacity={0.35}
      />

      {/* Legs */}
      {[3, 5, 9, 11].map((x) => (
        <Rect
          key={`leg-${x}`}
          x={ox + x * s}
          y={oy + (8.5 - svgY0) * s}
          width={s}
          height={1.5 * s}
          fill={bodyColor}
        />
      ))}

      {/* Torso */}
      <AnimatedRect
        x={useDerivedValue(() => ox + torsoX.value * s) as any}
        y={useDerivedValue(() => oy + (torsoY.value - svgY0) * s) as any}
        width={useDerivedValue(() => torsoW.value * s) as any}
        height={useDerivedValue(() => torsoH.value * s) as any}
        fill={bodyColor}
      />

      {/* Arms */}
      <Rect
        x={ox + -1 * s}
        y={oy + (13 - svgY0) * s}
        width={2 * s}
        height={2 * s}
        fill={bodyColor}
      />
      <Rect
        x={ox + 14 * s}
        y={oy + (13 - svgY0) * s}
        width={2 * s}
        height={2 * s}
        fill={bodyColor}
      />

      {/* Eyes */}
      <AnimatedRect
        x={ox + 3 * s}
        y={useDerivedValue(() => oy + (eyeY.value - svgY0) * s) as any}
        width={2.5 * s}
        height={s}
        fill={EYE_COLOR}
      />
      <AnimatedRect
        x={ox + 9.5 * s}
        y={useDerivedValue(() => oy + (eyeY.value - svgY0) * s) as any}
        width={2.5 * s}
        height={s}
        fill={EYE_COLOR}
      />
    </Svg>
  )
}

// Working mascot
const WorkingMascot = ({
  size,
  time,
  bodyColor,
}: {
  size: number
  time: Animated.SharedValue<number>
  bodyColor: string
}) => {
  const svgW = 16
  const svgH = 11
  const svgY0 = 5.5
  const s = Math.min(size / svgW, size / svgH)
  const ox = (size - svgW * s) / 2
  const oy = (size - svgH * s) / 2

  // time 从 0 到 1，周期 1 秒
  // bounce: 每秒 4 次跳动
  const bounce = useDerivedValue(() => {
    return Math.sin(time.value * 2 * Math.PI * 4) * 1.5
  })

  // 键盘按键闪烁
  const leftHit = useDerivedValue(() => {
    return Math.sin(time.value * 2 * Math.PI * 10) > 0.3 ? 1 : 0
  })

  const rightHit = useDerivedValue(() => {
    return Math.sin(time.value * 2 * Math.PI * 12) > 0.3 ? 1 : 0
  })

  return (
    <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <AnimatedRect
        x={ox + 3 * s}
        y={oy + (15 - svgY0) * s}
        width={9 * s}
        height={s}
        fill="black"
        opacity={0.4}
      />

      {[3, 5, 9, 11].map((x) => (
        <Rect
          key={`leg-${x}`}
          x={ox + x * s}
          y={oy + (13 - svgY0) * s}
          width={s}
          height={2 * s}
          fill={bodyColor}
        />
      ))}

      <AnimatedRect
        x={ox + 2 * s}
        y={useDerivedValue(() => oy + (6 + bounce.value - svgY0) * s) as any}
        width={11 * s}
        height={7 * s}
        fill={bodyColor}
      />

      <AnimatedRect
        x={ox + 4 * s}
        y={useDerivedValue(() => oy + (8 + bounce.value - svgY0) * s) as any}
        width={s}
        height={s}
        fill={EYE_COLOR}
      />
      <AnimatedRect
        x={ox + 10 * s}
        y={useDerivedValue(() => oy + (8 + bounce.value - svgY0) * s) as any}
        width={s}
        height={s}
        fill={EYE_COLOR}
      />

      <Rect
        x={ox + -0.5 * s}
        y={oy + (11.8 - svgY0) * s}
        width={16 * s}
        height={3.5 * s}
        fill={KB_BASE_COLOR}
      />

      {[0, 1, 2, 3, 4, 5].map((col) => (
        <React.Fragment key={`key-col-${col}`}>
          <Rect
            x={ox + (0.3 + col * 2.5) * s}
            y={oy + (12.2 - svgY0) * s}
            width={2 * s}
            height={0.7 * s}
            fill={KB_KEY_COLOR}
          />
          <Rect
            x={ox + (0.3 + col * 2.5) * s}
            y={oy + (13.2 - svgY0) * s}
            width={2 * s}
            height={0.7 * s}
            fill={KB_KEY_COLOR}
          />
          <Rect
            x={ox + (0.3 + col * 2.5) * s}
            y={oy + (14.2 - svgY0) * s}
            width={2 * s}
            height={0.7 * s}
            fill={KB_KEY_COLOR}
          />
        </React.Fragment>
      ))}

      <AnimatedRect
        x={ox + 0.3 * s}
        y={oy + (12.2 - svgY0) * s}
        width={2 * s}
        height={0.7 * s}
        fill={KB_HI_COLOR}
        opacity={leftHit as any}
      />
      <AnimatedRect
        x={ox + 7.8 * s}
        y={oy + (12.2 - svgY0) * s}
        width={2 * s}
        height={0.7 * s}
        fill={KB_HI_COLOR}
        opacity={rightHit as any}
      />

      <AnimatedRect
        x={ox + 0 * s}
        y={useDerivedValue(() => oy + (9 + bounce.value - svgY0) * s) as any}
        width={2 * s}
        height={2 * s}
        fill={bodyColor}
      />
      <AnimatedRect
        x={ox + 13 * s}
        y={useDerivedValue(() => oy + (9 + bounce.value - svgY0) * s) as any}
        width={2 * s}
        height={2 * s}
        fill={bodyColor}
      />
    </Svg>
  )
}

// Alert mascot
const AlertMascot = ({
  size,
  time,
  bodyColor,
}: {
  size: number
  time: Animated.SharedValue<number>
  bodyColor: string
}) => {
  const svgW = 15
  const svgH = 12
  const svgY0 = 4
  const s = Math.min(size / svgW, size / svgH)
  const ox = (size - svgW * s) / 2
  const oy = (size - svgH * s) / 2

  // time 从 0 到 1.75，周期 1.75 秒
  const jumpY = useDerivedValue(() => {
    const pct = time.value / 1.75

    const keyframes = [
      [0, 0], [0.03, 0], [0.10, -1], [0.15, 1.5],
      [0.175, -10], [0.20, -10], [0.25, 1.5],
      [0.275, -8], [0.30, -8], [0.35, 1.2],
      [0.375, -5], [0.40, -5], [0.45, 1.0],
      [0.475, -3], [0.50, -3], [0.55, 0.5],
      [0.62, 0], [1.0, 0],
    ]

    for (let i = 1; i < keyframes.length; i++) {
      if (pct <= keyframes[i][0]) {
        const t = (pct - keyframes[i-1][0]) / (keyframes[i][0] - keyframes[i-1][0])
        return keyframes[i-1][1] + (keyframes[i][1] - keyframes[i-1][1]) * t
      }
    }
    return 0
  })

  const bangOpacity = useDerivedValue(() => {
    const pct = time.value / 1.75

    if (pct < 0.03) return 0
    if (pct < 0.55) return 1
    if (pct < 0.62) return 0
    return 0
  })

  return (
    <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <AnimatedRect
        x={ox + 3 * s}
        y={oy + (15 - svgY0) * s}
        width={9 * s}
        height={s}
        fill="black"
        opacity={0.4}
      />

      {[3, 5, 9, 11].map((x) => (
        <AnimatedRect
          key={`leg-${x}`}
          x={ox + x * s}
          y={useDerivedValue(() => oy + (11 + jumpY.value - svgY0) * s) as any}
          width={s}
          height={4 * s}
          fill={bodyColor}
        />
      ))}

      <AnimatedRect
        x={ox + 2 * s}
        y={useDerivedValue(() => oy + (6 + jumpY.value - svgY0) * s) as any}
        width={11 * s}
        height={7 * s}
        fill={bodyColor}
      />

      <AnimatedRect
        x={ox + 4 * s}
        y={useDerivedValue(() => oy + (8 + jumpY.value - svgY0) * s) as any}
        width={s}
        height={2.5 * s}
        fill={EYE_COLOR}
      />
      <AnimatedRect
        x={ox + 10 * s}
        y={useDerivedValue(() => oy + (8 + jumpY.value - svgY0) * s) as any}
        width={s}
        height={2.5 * s}
        fill={EYE_COLOR}
      />

      <AnimatedRect
        x={ox + 0 * s}
        y={useDerivedValue(() => oy + (4 + jumpY.value - svgY0) * s) as any}
        width={2 * s}
        height={2 * s}
        fill={bodyColor}
      />
      <AnimatedRect
        x={ox + 13 * s}
        y={useDerivedValue(() => oy + (4 + jumpY.value - svgY0) * s) as any}
        width={2 * s}
        height={2 * s}
        fill={bodyColor}
      />

      <AnimatedRect
        x={ox + 13 * s}
        y={oy + (2 - svgY0) * s}
        width={2 * s}
        height={3.5 * s}
        fill={ALERT_COLOR}
        opacity={bangOpacity as any}
      />
      <AnimatedRect
        x={ox + 13 * s}
        y={oy + (6 - svgY0) * s}
        width={2 * s}
        height={1.5 * s}
        fill={ALERT_COLOR}
        opacity={bangOpacity as any}
      />
    </Svg>
  )
}

// Completed mascot - celebrating with raised arms
const CompletedMascot = ({
  size,
  time,
  bodyColor,
}: {
  size: number
  time: Animated.SharedValue<number>
  bodyColor: string
}) => {
  const svgW = 17
  const svgH = 14
  const svgY0 = 2
  const s = Math.min(size / svgW, size / svgH)
  const ox = (size - svgW * s) / 2
  const oy = (size - svgH * s) / 2

  // Bounce animation
  const bounce = useDerivedValue(() => {
    return Math.sin(time.value * 2 * Math.PI / 1.5) * 1
  })

  // Arm wave animation
  const armWave = useDerivedValue(() => {
    return Math.sin(time.value * 2 * Math.PI / 0.6) * 0.5
  })

  // Star twinkle
  const starOpacity = useDerivedValue(() => {
    return 0.5 + Math.sin(time.value * 2 * Math.PI / 0.3) * 0.5
  })

  return (
    <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      {/* Shadow */}
      <AnimatedRect
        x={ox + 3 * s}
        y={oy + (15 - svgY0) * s}
        width={9 * s}
        height={s}
        fill="black"
        opacity={0.3}
      />

      {/* Legs */}
      {[3, 5, 9, 11].map((x) => (
        <AnimatedRect
          key={`leg-${x}`}
          x={ox + x * s}
          y={useDerivedValue(() => oy + (11 + bounce.value * 0.3 - svgY0) * s) as any}
          width={s}
          height={3 * s}
          fill={bodyColor}
        />
      ))}

      {/* Body */}
      <AnimatedRect
        x={ox + 2 * s}
        y={useDerivedValue(() => oy + (6 + bounce.value - svgY0) * s) as any}
        width={11 * s}
        height={6 * s}
        fill={bodyColor}
      />

      {/* Happy eyes - curved lines (^_^) */}
      {/* Left eye */}
      <AnimatedRect
        x={ox + 3.5 * s}
        y={useDerivedValue(() => oy + (8 + bounce.value - svgY0) * s) as any}
        width={s}
        height={s}
        fill={EYE_COLOR}
      />
      <AnimatedRect
        x={ox + 4.5 * s}
        y={useDerivedValue(() => oy + (7.5 + bounce.value - svgY0) * s) as any}
        width={s * 0.5}
        height={s * 0.5}
        fill={EYE_COLOR}
      />
      {/* Right eye */}
      <AnimatedRect
        x={ox + 9.5 * s}
        y={useDerivedValue(() => oy + (8 + bounce.value - svgY0) * s) as any}
        width={s}
        height={s}
        fill={EYE_COLOR}
      />
      <AnimatedRect
        x={ox + 9 * s}
        y={useDerivedValue(() => oy + (7.5 + bounce.value - svgY0) * s) as any}
        width={s * 0.5}
        height={s * 0.5}
        fill={EYE_COLOR}
      />

      {/* Smile */}
      <AnimatedRect
        x={ox + 6 * s}
        y={useDerivedValue(() => oy + (10 + bounce.value - svgY0) * s) as any}
        width={3 * s}
        height={s * 0.8}
        fill={EYE_COLOR}
        rx={s * 0.4}
      />

      {/* Raised arms - celebrating! */}
      {/* Left arm */}
      <AnimatedRect
        x={ox + -1 * s}
        y={useDerivedValue(() => oy + (2 + bounce.value + armWave.value - svgY0) * s) as any}
        width={2 * s}
        height={5 * s}
        fill={bodyColor}
      />
      {/* Right arm */}
      <AnimatedRect
        x={ox + 14 * s}
        y={useDerivedValue(() => oy + (2 + bounce.value - armWave.value - svgY0) * s) as any}
        width={2 * s}
        height={5 * s}
        fill={bodyColor}
      />

      {/* Sparkles/stars around */}
      <AnimatedRect
        x={ox + -2 * s}
        y={oy + (1 - svgY0) * s}
        width={s}
        height={s}
        fill={STAR_COLOR}
        opacity={starOpacity as any}
      />
      <AnimatedRect
        x={ox + 16 * s}
        y={oy + (0 - svgY0) * s}
        width={s * 1.2}
        height={s * 1.2}
        fill={STAR_COLOR}
        opacity={useDerivedValue(() => 0.5 + Math.sin(time.value * 2 * Math.PI / 0.4 + 1) * 0.5) as any}
      />
      <AnimatedRect
        x={ox + 7 * s}
        y={oy + (-1 - svgY0) * s}
        width={s * 0.8}
        height={s * 0.8}
        fill={STAR_COLOR}
        opacity={useDerivedValue(() => 0.5 + Math.sin(time.value * 2 * Math.PI / 0.5 + 2) * 0.5) as any}
      />

      {/* Green glow ring */}
      <Rect
        x={ox + -1 * s}
        y={oy + (-1 - svgY0) * s}
        width={17 * s}
        height={14 * s}
        fill="none"
        stroke={SUCCESS_COLOR}
        strokeWidth={s * 0.3}
        opacity={0.4}
        rx={s * 2}
      />
    </Svg>
  )
}

const PixelMascot: React.FC<PixelMascotProps> = ({
  size = 27,
  status = 'idle',
  color = BODY_COLOR,
}) => {
  const time = useSharedValue(0)
  const breathe = useSharedValue(0)

  useEffect(() => {
    // 取消之前的动画
    cancelAnimation(time)
    cancelAnimation(breathe)

    // 重置值
    time.value = 0
    breathe.value = 0

    if (status === 'idle') {
      // 呼吸动画
      breathe.value = withRepeat(
        withSequence(
          withTiming(1, { duration: 800, easing: Easing.inOut(Easing.sin) }),
          withTiming(0, { duration: 1200, easing: Easing.inOut(Easing.sin) })
        ),
        -1,
        false
      )
      // 时间动画 - 用于 z 字母动画，周期为 3 秒
      time.value = withRepeat(
        withTiming(3, { duration: 3000, easing: Easing.linear }),
        -1,
        false
      )
    } else if (status === 'processing') {
      // 工作状态 - 时间动画周期为 1 秒
      time.value = withRepeat(
        withTiming(1, { duration: 1000, easing: Easing.linear }),
        -1,
        false
      )
    } else if (status === 'waitingApproval') {
      // 警告状态 - 时间动画周期为 1.75 秒
      time.value = withRepeat(
        withTiming(1.75, { duration: 1750, easing: Easing.linear }),
        -1,
        false
      )
    } else if (status === 'completed') {
      // 完成状态 - 时间动画周期为 1.5 秒
      time.value = withRepeat(
        withTiming(1.5, { duration: 1500, easing: Easing.linear }),
        -1,
        false
      )
    }
  }, [status])

  // Z animated styles - time 从 0 到 3 秒
  const z0Style = useAnimatedStyle(() => {
    const t = time.value
    // 第一个 z 从 0 秒开始，周期 3 秒
    const phase = t / 3
    const p = Math.max(0, Math.min(1, phase))

    return {
      opacity: p < 0.8 ? 0.7 : (1 - p) * 3.5 * 0.7,
      transform: [{ translateY: -size * 0.1 - p * size * 0.5 }],
    }
  })

  const z1Style = useAnimatedStyle(() => {
    const t = time.value
    // 第二个 z 从 0.9 秒开始
    const phase = Math.max(0, (t - 0.9) / 3)
    const p = Math.min(1, phase)

    return {
      opacity: p < 0.8 ? 0.6 : (1 - p) * 3.5 * 0.6,
      transform: [{ translateY: -size * 0.1 - p * size * 0.5 }],
    }
  })

  const z2Style = useAnimatedStyle(() => {
    const t = time.value
    // 第三个 z 从 1.8 秒开始
    const phase = Math.max(0, (t - 1.8) / 3)
    const p = Math.min(1, phase)

    return {
      opacity: p < 0.8 ? 0.5 : (1 - p) * 3.5 * 0.5,
      transform: [{ translateY: -size * 0.1 - p * size * 0.5 }],
    }
  })

  return (
    <View style={[styles.container, { width: size, height: size }]}>
      {status === 'idle' && (
        <>
          <SleepingMascot size={size} breathe={breathe} bodyColor={color} />
          <Animated.Text
            style={[
              {
                position: 'absolute',
                left: size * 0.35,
                fontWeight: '900',
                color: 'white',
                fontFamily: 'monospace',
                fontSize: size * 0.2,
                zIndex: 10,
              },
              z0Style,
            ] as any}
          >
            z
          </Animated.Text>
          <Animated.Text
            style={[
              {
                position: 'absolute',
                left: size * 0.45,
                fontWeight: '900',
                color: 'white',
                fontFamily: 'monospace',
                fontSize: size * 0.18,
                zIndex: 10,
              },
              z1Style,
            ] as any}
          >
            z
          </Animated.Text>
          <Animated.Text
            style={[
              {
                position: 'absolute',
                left: size * 0.55,
                fontWeight: '900',
                color: 'white',
                fontFamily: 'monospace',
                fontSize: size * 0.16,
                zIndex: 10,
              },
              z2Style,
            ] as any}
          >
            z
          </Animated.Text>
        </>
      )}

      {status === 'processing' && (
        <WorkingMascot size={size} time={time} bodyColor={color} />
      )}

      {status === 'waitingApproval' && (
        <View style={styles.alertContainer}>
          <View style={[styles.alertBg, { width: size * 0.8, height: size * 0.8 }]} />
          <AlertMascot size={size} time={time} bodyColor={color} />
        </View>
      )}

      {status === 'completed' && (
        <CompletedMascot size={size} time={time} bodyColor={color} />
      )}
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  alertContainer: {
    position: 'relative',
    alignItems: 'center',
    justifyContent: 'center',
  },
  alertBg: {
    position: 'absolute',
    borderRadius: 100,
    backgroundColor: 'rgba(255, 61, 0, 0.12)',
  },
})

export default PixelMascot
