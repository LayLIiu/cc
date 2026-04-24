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
import Svg, { G, Circle, Rect } from 'react-native-svg'

type SettingsMascotProps = {
  size?: number
  color?: string
}

// 像素风齿轮吉祥物
export function SettingsMascot({ size = 26, color = '#6B7280' }: SettingsMascotProps) {
  // 脉冲动画
  const pulse = useSharedValue(1)

  useEffect(() => {
    // 轻微脉冲
    pulse.value = withRepeat(
      withSequence(
        withTiming(1.05, { duration: 2000, easing: Easing.inOut(Easing.quad) }),
        withTiming(1, { duration: 2000, easing: Easing.inOut(Easing.quad) })
      ),
      -1,
      true
    )
  }, [])

  const s = size / 16 // 缩放比例
  const centerX = size / 2
  const centerY = size / 2

  // 颜色
  const gearColor = '#6B7280' // 灰色齿轮
  const innerColor = '#374151'
  const highlightColor = '#9CA3AF'

  return (
    <View style={[styles.container, { width: size, height: size }]}>
      <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <G>
          {/* 齿轮齿 - 上 */}
          <Rect
            x={centerX - 1.5 * s}
            y={centerY - 6 * s}
            width={3 * s}
            height={2 * s}
            fill={gearColor}
          />

          {/* 齿轮齿 - 右上 */}
          <Rect
            x={centerX + 3 * s}
            y={centerY - 4 * s}
            width={2 * s}
            height={3 * s}
            fill={gearColor}
          />

          {/* 齿轮齿 - 右下 */}
          <Rect
            x={centerX + 3 * s}
            y={centerY + 1 * s}
            width={2 * s}
            height={3 * s}
            fill={gearColor}
          />

          {/* 齿轮齿 - 下 */}
          <Rect
            x={centerX - 1.5 * s}
            y={centerY + 4 * s}
            width={3 * s}
            height={2 * s}
            fill={gearColor}
          />

          {/* 齿轮齿 - 左下 */}
          <Rect
            x={centerX - 5 * s}
            y={centerY + 1 * s}
            width={2 * s}
            height={3 * s}
            fill={gearColor}
          />

          {/* 齿轮齿 - 左上 */}
          <Rect
            x={centerX - 5 * s}
            y={centerY - 4 * s}
            width={2 * s}
            height={3 * s}
            fill={gearColor}
          />

          {/* 中心圆 - 外 */}
          <Circle
            cx={centerX}
            cy={centerY}
            r={4 * s}
            fill={gearColor}
          />

          {/* 中心圆 - 内 */}
          <Circle
            cx={centerX}
            cy={centerY}
            r={2.5 * s}
            fill={innerColor}
          />

          {/* 中心点 */}
          <Circle
            cx={centerX}
            cy={centerY}
            r={1 * s}
            fill={highlightColor}
          />

          {/* 装饰点 */}
          <Circle
            cx={centerX}
            cy={centerY - 1.5 * s}
            r={0.4 * s}
            fill={highlightColor}
            opacity={0.5}
          />
          <Circle
            cx={centerX + 1.3 * s}
            cy={centerY + 0.75 * s}
            r={0.4 * s}
            fill={highlightColor}
            opacity={0.5}
          />
          <Circle
            cx={centerX - 1.3 * s}
            cy={centerY + 0.75 * s}
            r={0.4 * s}
            fill={highlightColor}
            opacity={0.5}
          />
        </G>
      </Svg>
    </View>
  )
}

// 包装组件
type SettingsMascotWidgetProps = {
  size?: number
}

export function SettingsMascotWidget({ size = 26 }: SettingsMascotWidgetProps) {
  return <SettingsMascot size={size} />
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
})
