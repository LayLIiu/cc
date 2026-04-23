import React, { useEffect, useMemo } from 'react'
import { View, Text, StyleSheet, TouchableOpacity, Platform } from 'react-native'
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  interpolate,
  Easing,
} from 'react-native-reanimated'
import { useTheme } from '@/utils/theme'

type SegmentedTabProps = {
  tabs: { key: string; label: string; icon: string }[]
  activeTab: string
  onTabPress: (key: string) => void
}

const AnimatedTouchable = Animated.createAnimatedComponent(TouchableOpacity)

export function SegmentedTab({ tabs, activeTab, onTabPress }: SegmentedTabProps) {
  const { colors, isDark } = useTheme()

  // Animation values
  const translateX = useSharedValue(0)
  const scale = useSharedValue(1)

  // Calculate tab width based on number of tabs
  const tabWidth = 160 / tabs.length

  // Pre-compute animated text styles for each tab (fixed: moved outside the loop to comply with React Hooks rules!)
  const tabAnimatedStyles = useMemo(() => {
    return tabs.map((tab) => {
      const isActive = tab.key === activeTab
      return {
        opacity: isActive ? 1 : 0.6,
        transform: [{ scale: isActive ? 1 : 0.95 }],
      }
    })
  }, [tabs, activeTab])

  // Update animation when active tab changes
  useEffect(() => {
    const index = tabs.findIndex(t => t.key === activeTab)
    if (index !== -1) {
      translateX.value = withSpring(index * tabWidth, {
        damping: 20,
        stiffness: 300,
        mass: 0.8,
      })
    }
  }, [activeTab, tabs.length])

  // Animated style for the sliding indicator
  const indicatorStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
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
            width: tabWidth,
            backgroundColor: colors.primary,
          },
          indicatorStyle,
        ]}
      />

      {/* Tab buttons */}
      {tabs.map((tab, index) => {
        const isActive = tab.key === activeTab

        return (
          <TouchableOpacity
            key={tab.key}
            style={[styles.tab, { width: tabWidth }]}
            onPress={() => handlePress(tab.key, index)}
            activeOpacity={0.7}
          >
            <Animated.View style={styles.tabContent}>
              <Text style={styles.icon}>{tab.icon}</Text>
              <Animated.Text
                style={[
                  styles.label,
                  { color: isActive ? '#fff' : colors.text },
                  tabAnimatedStyles[index],
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
    marginVertical: 8,
    height: 44,
  },
  indicator: {
    position: 'absolute',
    height: 36,
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
