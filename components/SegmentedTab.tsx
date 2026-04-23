import React, { useEffect } from 'react'
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native'
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
} from 'react-native-reanimated'
import { useTheme } from '@/utils/theme'

type SegmentedTabProps = {
  tabs: { key: string; label: string; icon: string }[]
  activeTab: string
  onTabPress: (key: string) => void
}

export function SegmentedTab({ tabs, activeTab, onTabPress }: SegmentedTabProps) {
  const { colors, isDark } = useTheme()

  // Animation values
  const translateX = useSharedValue(0)
  const scale = useSharedValue(1)

  // Update animation when active tab changes
  useEffect(() => {
    const index = tabs.findIndex(t => t.key === activeTab)
    if (index !== -1) {
      translateX.value = withSpring(index, {
        damping: 20,
        stiffness: 300,
        mass: 0.8,
      })
    }
  }, [activeTab, tabs.length])

  // Animated style for the sliding indicator
  const indicatorStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value * 100 + '%' as any },
      { scale: scale.value },
    ],
  }))

  // Handle press with bounce effect
  const handlePress = (key: string, index: number) => {
    // Bounce animation
    scale.value = withSpring(0.95, { damping: 15, stiffness: 400 }, () => {
      scale.value = withSpring(1, { damping: 15, stiffness: 400 })
    })
    onTabPress(key)
  }

  return (
    <View style={[
      styles.container,
      {
        backgroundColor: isDark ? 'rgba(255, 255, 255, 0.08)' : 'rgba(0, 0, 0, 0.05)',
      }
    ]}>
      {/* Sliding indicator */}
      <Animated.View
        style={[
          styles.indicator,
          {
            backgroundColor: colors.primary,
          },
          indicatorStyle,
        ]}
      />

      {/* Tab buttons */}
      {tabs.map((tab, index) => {
        const isActive = tab.key === activeTab

        const animatedTextStyle = useAnimatedStyle(() => {
          return {
            opacity: withTiming(isActive ? 1 : 0.6, { duration: 150 }),
            transform: [{ scale: withTiming(isActive ? 1 : 0.95, { duration: 150 }) }],
          }
        })

        return (
          <TouchableOpacity
            key={tab.key}
            style={styles.tab}
            onPress={() => handlePress(tab.key, index)}
            activeOpacity={0.7}
          >
            <Animated.View style={styles.tabContent}>
              <Text style={styles.icon}>{tab.icon}</Text>
              <Animated.Text
                style={[
                  styles.label,
                  { color: isActive ? '#fff' : colors.text },
                  animatedTextStyle,
                ]}
              >
                {tab.label}
              </Animated.Text>
            </Animated.View>
          </TouchableOpacity>
        )
      })}
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    borderRadius: 25,
    padding: 4,
    marginHorizontal: 16,
    height: 44,
  },
  indicator: {
    position: 'absolute',
    height: 36,
    width: '50%',
    borderRadius: 20,
    top: 4,
    left: 4,
    shadowColor: '#6366f1',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 4,
  },
  tab: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    height: 36,
    zIndex: 1,
  },
  tabContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  icon: {
    fontSize: 16,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
  },
})
