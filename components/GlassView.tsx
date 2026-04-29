import React from 'react'
import { Platform, View, StyleSheet } from 'react-native'
import { BlurView } from 'expo-blur'
import type { ViewStyle } from 'react-native'

export interface GlassViewProps {
  children: React.ReactNode
  style?: ViewStyle
  /** 玻璃效果强度 (0-100)，默认 60 */
  intensity?: number
  /** 模糊色调：light / dark / default，默认 default */
  tint?: 'light' | 'dark' | 'default'
  /** 底层色调 */
  tintColor?: string
  /** 圆角 */
  cornerRadius?: number
  /** 是否显示边框高光，默认 true */
  showBorder?: boolean
  /** 边框颜色 */
  borderColor?: string
}

/**
 * 统一玻璃视图组件
 *
 * - iOS: BlurView 毛玻璃效果
 * - Android 12+: BlurView 支持
 * - Android 12以下: 降级为半透明 View
 */
export function GlassView({
  children,
  style,
  intensity = 60,
  tint = 'default',
  tintColor,
  cornerRadius,
  showBorder = true,
  borderColor = 'rgba(255, 255, 255, 0.12)',
}: GlassViewProps) {
  // Android 11 以下降级为半透明 View
  if (Platform.OS === 'android' && Platform.Version < 31) {
    return (
      <View
        style={[
          styles.glass,
          cornerRadius !== undefined ? { borderRadius: cornerRadius } : undefined,
          showBorder && borderColor ? { borderColor, borderWidth: 0.5 } : undefined,
          { backgroundColor: tintColor || 'rgba(10, 10, 20, 0.6)' },
          style,
        ]}
      >
        <View style={styles.content} pointerEvents="box-none">
          {children}
        </View>
      </View>
    )
  }

  return (
    <View
      style={[
        styles.glass,
        cornerRadius !== undefined ? { borderRadius: cornerRadius } : undefined,
        showBorder && borderColor ? { borderColor, borderWidth: 0.5 } : undefined,
        style,
      ]}
    >
      {/* 半透明底层（可选） */}
      {tintColor && (
        <View
          style={[StyleSheet.absoluteFillObject, { backgroundColor: tintColor }]}
          pointerEvents="none"
        />
      )}

      {/* 毛砂模糊 */}
      <BlurView
        intensity={intensity}
        tint={tint}
        style={StyleSheet.absoluteFillObject}
        pointerEvents="none"
      />

      {/* 内容层 — 最上方 */}
      <View style={styles.content} pointerEvents="box-none">
        {children}
      </View>
    </View>
  )
}

const styles = StyleSheet.create({
  glass: {
    overflow: 'hidden',
  },
  content: {
    flex: 1,
  },
})
