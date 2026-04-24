import React from 'react'
import { View, StyleSheet } from 'react-native'
import Svg, { Circle } from 'react-native-svg'

interface ContextRingProps {
  size?: number
  strokeWidth?: number
  percentage: number // 0-100
  color?: string
  backgroundColor?: string
}

/**
 * ContextRing - 圆形进度环，显示上下文容量使用情况
 *
 * @param size - 圆形大小
 * @param strokeWidth - 线条宽度
 * @param percentage - 使用百分比 (0-100)
 * @param color - 进度条颜色（会根据百分比自动变化）
 * @param backgroundColor - 背景圆环颜色
 */
export const ContextRing: React.FC<ContextRingProps> = ({
  size = 16,
  strokeWidth = 2,
  percentage,
  color,
  backgroundColor = 'rgba(255, 255, 255, 0.2)',
}) => {
  // 根据百分比自动选择颜色
  const getProgressColor = () => {
    if (color) return color
    if (percentage < 50) return '#22c55e' // 绿色 - 安全
    if (percentage < 75) return '#eab308' // 黄色 - 接近
    if (percentage < 90) return '#f97316' // 橙色 - 警告
    return '#ef4444' // 红色 - 危险
  }

  const radius = (size - strokeWidth) / 2
  const circumference = 2 * Math.PI * radius
  const strokeDashoffset = circumference - (percentage / 100) * circumference

  const progressColor = getProgressColor()

  return (
    <View style={[styles.container, { width: size, height: size }]}>
      <Svg width={size} height={size}>
        {/* 背景圆环 */}
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={backgroundColor}
          strokeWidth={strokeWidth}
          fill="none"
        />
        {/* 进度圆环 */}
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={progressColor}
          strokeWidth={strokeWidth}
          fill="none"
          strokeDasharray={circumference}
          strokeDashoffset={strokeDashoffset}
          strokeLinecap="round"
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
        />
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

export default ContextRing
