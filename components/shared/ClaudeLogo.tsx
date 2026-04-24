import React, { useEffect, useMemo } from 'react'
import { View, StyleSheet } from 'react-native'
import Svg, { Path, Circle } from 'react-native-svg'
import Animated, {
  useSharedValue,
  useAnimatedProps,
  withRepeat,
  withTiming,
  withSequence,
  Easing,
  cancelAnimation,
  interpolate,
  Extrapolation,
} from 'react-native-reanimated'

const AnimatedPath = Animated.createAnimatedComponent(Path)

// 核心数据
const CORE_RADIUS = 27.2
const ROOT_WIDTH_SCALE = 1.1
const TIP_WIDTH_SCALE = 1.3

const INITIAL_TENTACLES = [
  { id: 1, angle: -176.8, length: 82.0, baseW: 10.0, tipW: 11.2 },
  { id: 2, angle: -144.1, length: 83.6, baseW: 16.5, tipW: 19.1 },
  { id: 3, angle: -117.6, length: 89.2, baseW: 17.9, tipW: 23.6 },
  { id: 4, angle: -82.1, length: 73.2, baseW: 13.2, tipW: 16.6 },
  { id: 5, angle: -50.8, length: 73.4, baseW: 26.5, tipW: 21.5 },
  { id: 6, angle: -10.9, length: 67.7, baseW: 15.2, tipW: 13.7 },
  { id: 7, angle: 9.1, length: 69.3, baseW: 9.8, tipW: 18.2 },
  { id: 8, angle: 40.6, length: 71.1, baseW: 13.4, tipW: 8.9 },
  { id: 9, angle: 56.2, length: 68.2, baseW: 18.0, tipW: 15.3 },
  { id: 10, angle: 98.5, length: 73.8, baseW: 9.8, tipW: 15.7 },
  { id: 11, angle: 128.1, length: 77.6, baseW: 13.5, tipW: 11.8 },
  { id: 12, angle: 148.1, length: 75.0, baseW: 13.6, tipW: 14.4 },
].map((t) => ({
  ...t,
  baseW: t.baseW * ROOT_WIDTH_SCALE,
  tipW: t.tipW * TIP_WIDTH_SCALE,
}))

export interface ClaudeLogoProps {
  size?: number
  color?: string
  mode?: 'idle' | 'thinking' | 'waiting'
}

// 生成触手路径
function generateTentaclePath(
  angle: number,
  animLength: number,
  animBaseW: number,
  animTipW: number
): string {
  'worklet'
  const fillet = 6.0
  const rad = (angle * Math.PI) / 180
  const dirX = Math.cos(rad)
  const dirY = Math.sin(rad)
  const normX = -Math.sin(rad)
  const normY = Math.cos(rad)
  const rRoot = CORE_RADIUS
  const rTip = CORE_RADIUS + Math.max(0, animLength)

  const hw = Math.min(animBaseW / 2, rRoot * 0.95)
  const theta = Math.asin(hw / rRoot)

  const B1 = { x: rRoot * Math.cos(rad + theta), y: rRoot * Math.sin(rad + theta) }
  const B2 = { x: rRoot * Math.cos(rad - theta), y: rRoot * Math.sin(rad - theta) }

  const Tip1 = {
    x: dirX * rTip + normX * (animTipW / 2),
    y: dirY * rTip + normY * (animTipW / 2),
  }
  const Tip2 = {
    x: dirX * rTip - normX * (animTipW / 2),
    y: dirY * rTip - normY * (animTipW / 2),
  }

  const len1 = Math.hypot(Tip1.x - B1.x, Tip1.y - B1.y) || 1
  const U1 = { x: (Tip1.x - B1.x) / len1, y: (Tip1.y - B1.y) / len1 }
  const len2 = Math.hypot(Tip2.x - B2.x, Tip2.y - B2.y) || 1
  const U2 = { x: (Tip2.x - B2.x) / len2, y: (Tip2.y - B2.y) / len2 }

  const segments = 3 + (Math.floor(angle) % 3)

  const parts: string[] = []
  const startAngle = rad + theta + fillet / rRoot
  parts.push(`M ${rRoot * Math.cos(startAngle)} ${rRoot * Math.sin(startAngle)}`)
  parts.push(`Q ${B1.x} ${B1.y} ${B1.x + U1.x * fillet} ${B1.y + U1.y * fillet}`)
  parts.push(`L ${Tip1.x} ${Tip1.y}`)

  for (let i = 1; i < segments; i++) {
    const ang = (rad + Math.PI / 2) + (-Math.PI) * (i / segments)
    parts.push(
      `L ${dirX * rTip + Math.cos(ang) * (animTipW / 2)} ${dirY * rTip + Math.sin(ang) * (animTipW / 2)}`
    )
  }

  parts.push(`L ${Tip2.x} ${Tip2.y}`)
  parts.push(`L ${B2.x + U2.x * fillet} ${B2.y + U2.y * fillet}`)
  const endAngle = rad - theta - fillet / rRoot
  parts.push(`Q ${B2.x} ${B2.y} ${rRoot * Math.cos(endAngle)} ${rRoot * Math.sin(endAngle)}`)
  parts.push('Z')

  return parts.join(' ')
}

// 单个触手组件
const Tentacle: React.FC<{
  tentacle: typeof INITIAL_TENTACLES[0]
  progress: Animated.SharedValue<number>
  breathe: Animated.SharedValue<number>
  color: string
  mode: 'idle' | 'thinking' | 'waiting'
}> = ({ tentacle, progress, breathe, color, mode }) => {
  const animatedProps = useAnimatedProps(() => {
    'worklet'
    let animLength = tentacle.length
    let animBaseW = tentacle.baseW
    let animTipW = tentacle.tipW

    if (mode === 'thinking') {
      // 螺旋效果 - 每条触手根据角度有不同的相位
      const angleRad = (tentacle.angle * Math.PI) / 180
      const rotSpeed = progress.value * Math.PI * 2
      const spiralPhase = ((angleRad - rotSpeed) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2)
      const normPhase = spiralPhase / (Math.PI * 2)

      let smoothK: number
      if (normPhase < 0.85) {
        smoothK = 0.45 + 0.85 * (normPhase / 0.85)
      } else {
        const p = (normPhase - 0.85) / 0.15
        smoothK = 1.3 - 0.85 * p
      }

      animLength = tentacle.length * smoothK
      const w_k = 0.9 + 0.25 * (smoothK - 0.45)
      animBaseW = tentacle.baseW * w_k
      animTipW = tentacle.tipW * w_k
    } else if (mode === 'waiting') {
      // 呼吸效果
      animLength = tentacle.length * breathe.value
    }

    const path = generateTentaclePath(tentacle.angle, animLength, animBaseW, animTipW)
    return { d: path }
  })

  return <AnimatedPath animatedProps={animatedProps} fill={color} />
}

const ClaudeLogo: React.FC<ClaudeLogoProps> = ({
  size = 40,
  color = '#D97757',
  mode = 'idle',
}) => {
  const progress = useSharedValue(0)
  const breathe = useSharedValue(1)

  useEffect(() => {
    cancelAnimation(progress)
    cancelAnimation(breathe)

    if (mode === 'thinking') {
      progress.value = withRepeat(
        withTiming(1, { duration: 800, easing: Easing.linear }),
        -1,
        false
      )
    } else if (mode === 'waiting') {
      breathe.value = withRepeat(
        withSequence(
          withTiming(0.3, { duration: 250, easing: Easing.out(Easing.quad) }),
          withTiming(1, { duration: 550, easing: Easing.inOut(Easing.quad) }),
          withTiming(1, { duration: 250 })
        ),
        -1,
        false
      )
    } else {
      progress.value = 0
      breathe.value = 1
    }
  }, [mode])

  const maxRadius = Math.max(...INITIAL_TENTACLES.map((t) => t.length)) + CORE_RADIUS + 20
  const viewBox = `${-maxRadius} ${-maxRadius} ${maxRadius * 2} ${maxRadius * 2}`

  return (
    <View style={[styles.container, { width: size, height: size }]}>
      <Svg width={size} height={size} viewBox={viewBox}>
        {INITIAL_TENTACLES.map((tentacle) => (
          <Tentacle
            key={tentacle.id}
            tentacle={tentacle}
            progress={progress}
            breathe={breathe}
            color={color}
            mode={mode}
          />
        ))}
        <Circle cx={0} cy={0} r={CORE_RADIUS} fill={color} />
      </Svg>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
})

export default ClaudeLogo
