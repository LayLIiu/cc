import React from 'react'
import { View, StyleSheet } from 'react-native'
import Svg, { Path, Circle, G } from 'react-native-svg'

type IconProps = {
  size?: number
  color?: string
}

export const Copy = ({ size = 24, color = '#000' }: IconProps) => (
  <View style={[styles.container, { width: size, height: size }]}>
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <Path
        d="M8 4H14C14.5304 4 15.0391 4.21071 15.4142 4.58579C15.7893 4.96086 16 5.46957 16 6V18"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <Path
        d="M16 18H10C9.46957 18 8.96086 17.7893 8.58579 17.4142C8.21071 17.0391 8 16.5304 8 16V6C8 5.46957 8.21071 4.96086 8.58579 4.58579C8.96086 4.21071 9.46957 4 10 4"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  </View>
)

export const Check = ({ size = 24, color = '#000' }: IconProps) => (
  <View style={[styles.container, { width: size, height: size }]}>
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <Path
        d="M20 6L9 17L4 12"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  </View>
)

export const ChevronDown = ({ size = 24, color = '#000' }: IconProps) => (
  <View style={[styles.container, { width: size, height: size }]}>
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <Path
        d="M6 9L12 15L18 9"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  </View>
)

export const ChevronRight = ({ size = 24, color = '#000' }: IconProps) => (
  <View style={[styles.container, { width: size, height: size }]}>
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <Path
        d="M9 6L15 12L9 18"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  </View>
)

export const Spinner = ({ size = 24, color = '#000' }: IconProps) => (
  <View style={[styles.container, { width: size, height: size }]}>
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <Circle
        cx="12"
        cy="12"
        r="10"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        opacity={0.25}
      />
      <Path
        d="M12 2C6.48 2 2 6.48 2 12"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
      />
    </Svg>
  </View>
)

export const Tool = ({ size = 24, color = '#000' }: IconProps) => (
  <View style={[styles.container, { width: size, height: size }]}>
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <Path
        d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  </View>
)

export const Brain = ({ size = 24, color = '#000' }: IconProps) => (
  <View style={[styles.container, { width: size, height: size }]}>
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <Path
        d="M9.5 2A2.5 2.5 0 0 1 12 4.5v15a2.5 2.5 0 0 1-4.96.96.96.96 0 0 0 .04-.11L8 12.38a6 6 0 1 1-6 0l2.96-5.27a.96.96 0 0 0 .04-.11V2A2.5 2.5 0 0 1 9.5 2"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <Path
        d="M14.5 2A2.5 2.5 0 0 0 12 4.5v15a2.5 2.5 0 0 0 4.96.96.96.96 0 0 0-.04-.11L16 12.38a6 6 0 1 0 6 0l-2.96-5.27a.96.96 0 0 0-.04-.11V2A2.5 2.5 0 0 0 14.5 2"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  </View>
)

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
})
