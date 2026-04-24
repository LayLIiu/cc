import React, { useEffect } from 'react'
import { View, StyleSheet } from 'react-native'
import Animated, {
  useSharedValue,
  useAnimatedProps,
  withRepeat,
  withSequence,
  withTiming,
  Easing,
} from 'react-native-reanimated'
import Svg, { Rect, G, Circle, Line, Ellipse } from 'react-native-svg'

const AnimatedRect = Animated.createAnimatedComponent(Rect)
const AnimatedCircle = Animated.createAnimatedComponent(Circle)
const AnimatedEllipse = Animated.createAnimatedComponent(Ellipse)

type ProviderMascotProps = {
  size?: number
  color?: string
  isActive?: boolean
}

// 像素风服务器吉祥物
export function ProviderMascot({ size = 28, color = '#D97706', isActive = false }: ProviderMascotProps) {
  // 动画值
  const pulse = useSharedValue(1)
  const glowOpacity = useSharedValue(0.3)
  const dataFlow = useSharedValue(0)

  useEffect(() => {
    // 脉冲动画
    pulse.value = withRepeat(
      withSequence(
        withTiming(1.05, { duration: 1000, easing: Easing.inOut(Easing.quad) }),
        withTiming(1, { duration: 1000, easing: Easing.inOut(Easing.quad) })
      ),
      -1,
      true
    )

    // 发光动画
    glowOpacity.value = withRepeat(
      withSequence(
        withTiming(0.6, { duration: 800 }),
        withTiming(0.3, { duration: 800 })
      ),
      -1,
      true
    )

    // 数据流动画
    dataFlow.value = withRepeat(
      withTiming(1, { duration: 1500, easing: Easing.linear }),
      -1,
      false
    )
  }, [])

  const s = size / 16 // 缩放比例
  const centerX = size / 2
  const centerY = size / 2

  // 服务器颜色
  const serverColor = isActive ? '#10B981' : color // 激活时绿色，否则橙色
  const screenColor = '#1F2937'
  const lightColor = isActive ? '#34D399' : '#FBBF24'
  const cloudColor = '#6366F1'

  return (
    <View style={[styles.container, { width: size, height: size }]}>
      <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <G>
          {/* 云朵背景 */}
          <Ellipse
            cx={centerX}
            cy={centerY - 2 * s}
            rx={6 * s}
            ry={3 * s}
            fill={cloudColor}
            opacity={0.2}
          />

          {/* 服务器机箱 - 上层 */}
          <Rect
            x={centerX - 5 * s}
            y={centerY - 4 * s}
            width={10 * s}
            height={3 * s}
            rx={0.5 * s}
            fill={serverColor}
          />

          {/* 服务器机箱 - 下层 */}
          <Rect
            x={centerX - 5 * s}
            y={centerY + 1 * s}
            width={10 * s}
            height={3 * s}
            rx={0.5 * s}
            fill={serverColor}
            opacity={0.8}
          />

          {/* 屏幕/指示灯 - 上层 */}
          <Rect
            x={centerX - 3.5 * s}
            y={centerY - 3.2 * s}
            width={2 * s}
            height={1.4 * s}
            rx={0.2 * s}
            fill={screenColor}
          />
          <AnimatedCircle
            cx={centerX + 2.5 * s}
            cy={centerY - 2.5 * s}
            r={0.5 * s}
            fill={lightColor}
            opacity={glowOpacity as any}
          />
          <AnimatedCircle
            cx={centerX + 3.5 * s}
            cy={centerY - 2.5 * s}
            r={0.5 * s}
            fill={lightColor}
            opacity={glowOpacity as any}
          />

          {/* 屏幕/指示灯 - 下层 */}
          <Rect
            x={centerX - 3.5 * s}
            y={centerY + 1.8 * s}
            width={2 * s}
            height={1.4 * s}
            rx={0.2 * s}
            fill={screenColor}
          />
          <AnimatedCircle
            cx={centerX + 2.5 * s}
            cy={centerY + 2.5 * s}
            r={0.5 * s}
            fill={lightColor}
            opacity={glowOpacity as any}
          />
          <AnimatedCircle
            cx={centerX + 3.5 * s}
            cy={centerY + 2.5 * s}
            r={0.5 * s}
            fill={lightColor}
            opacity={glowOpacity as any}
          />

          {/* 连接线/数据流 */}
          <Line
            x1={centerX}
            y1={centerY - 1 * s}
            x2={centerX}
            y2={centerY + 1 * s}
            stroke={lightColor}
            strokeWidth={0.5 * s}
            opacity={0.5}
          />

          {/* 像素风装饰点 */}
          <Circle
            cx={centerX - 4 * s}
            cy={centerY}
            r={0.4 * s}
            fill={lightColor}
            opacity={0.3}
          />
          <Circle
            cx={centerX + 4 * s}
            cy={centerY}
            r={0.4 * s}
            fill={lightColor}
            opacity={0.3}
          />
        </G>
      </Svg>
    </View>
  )
}

// 包装组件
type ProviderMascotWidgetProps = {
  size?: number
  isActive?: boolean
}

export function ProviderMascotWidget({ size = 28, isActive = false }: ProviderMascotWidgetProps) {
  return <ProviderMascot size={size} isActive={isActive} />
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
})
