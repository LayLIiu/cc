import React, { useEffect } from 'react'
import { View, StyleSheet, Text } from 'react-native'
import Svg, { Rect } from 'react-native-svg'
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

  const bounce = useDerivedValue(() => {
    return Math.sin(time.value * 2 * Math.PI / 0.25) * 1.5
  })

  const leftHit = useDerivedValue(() => {
    return Math.sin(time.value * 2 * Math.PI / 0.1) > 0.3 ? 1 : 0
  })

  const rightHit = useDerivedValue(() => {
    return Math.sin(time.value * 2 * Math.PI / 0.08) > 0.3 ? 1 : 0
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

  const jumpY = useDerivedValue(() => {
    const cycle = time.value % 1.75
    const pct = cycle / 1.75

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
    const cycle = time.value % 1.75
    const pct = cycle / 1.75

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

const PixelMascot: React.FC<PixelMascotProps> = ({
  size = 27,
  status = 'idle',
  color = BODY_COLOR,
}) => {
  const time = useSharedValue(0)
  const breathe = useSharedValue(0)
  const completedScale = useSharedValue(0)

  useEffect(() => {
    cancelAnimation(time)
    cancelAnimation(breathe)

    if (status === 'idle' || status === 'completed') {
      breathe.value = withRepeat(
        withSequence(
          withTiming(1, { duration: 800, easing: Easing.inOut(Easing.sin) }),
          withTiming(0, { duration: 1200, easing: Easing.inOut(Easing.sin) })
        ),
        -1,
        false
      )
      time.value = withRepeat(
        withTiming(100, { duration: 50000, easing: Easing.linear }),
        -1,
        false
      )
    } else {
      time.value = withRepeat(
        withTiming(100, { duration: 50000, easing: Easing.linear }),
        -1,
        false
      )
    }

    // 当状态变为 completed 时，播放弹跳动画
    if (status === 'completed') {
      completedScale.value = withSequence(
        withTiming(1.3, { duration: 200, easing: Easing.out(Easing.quad) }),
        withTiming(1, { duration: 200, easing: Easing.in(Easing.quad) })
      )
    } else {
      completedScale.value = 0
    }
  }, [status])

  // Z animated styles
  const z0Style = useAnimatedStyle(() => {
    const t = time.value
    const cycle = 2.8
    const phase = (t % cycle) / cycle
    const p = Math.max(0, phase)

    return {
      opacity: p < 0.8 ? 0.7 : (1 - p) * 3.5 * 0.7,
      transform: [{ translateY: -size * 0.1 - p * size * 0.5 }],
    }
  })

  const z1Style = useAnimatedStyle(() => {
    const t = time.value
    const delayVal = 0.9
    const cycle = 3.1
    const phase = ((t - delayVal) % cycle) / cycle
    const p = Math.max(0, phase)

    return {
      opacity: p < 0.8 ? 0.6 : (1 - p) * 3.5 * 0.6,
      transform: [{ translateY: -size * 0.1 - p * size * 0.5 }],
    }
  })

  const z2Style = useAnimatedStyle(() => {
    const t = time.value
    const delayVal = 1.8
    const cycle = 3.4
    const phase = ((t - delayVal) % cycle) / cycle
    const p = Math.max(0, phase)

    return {
      opacity: p < 0.8 ? 0.5 : (1 - p) * 3.5 * 0.5,
      transform: [{ translateY: -size * 0.1 - p * size * 0.5 }],
    }
  })

  const completedBadgeStyle = useAnimatedStyle(() => {
    return {
      transform: [{ scale: completedScale.value }],
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
        <>
          <SleepingMascot size={size} breathe={breathe} bodyColor={color} />
          <Animated.View style={[styles.completedBadge, completedBadgeStyle, { top: size * -0.1 }]}>
            <Text style={styles.completedBadgeText}>✓</Text>
          </Animated.View>
        </>
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
  completedBadge: {
    position: 'absolute',
    width: 16,
    height: 16,
    borderRadius: 8,
    backgroundColor: '#22c55e',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 20,
  },
  completedBadgeText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '700',
    lineHeight: 16,
  },
})

export default PixelMascot
