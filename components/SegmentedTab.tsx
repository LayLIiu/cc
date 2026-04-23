import React, { useEffect, useMemo, useState } from 'react'
import { View, Text, StyleSheet, TouchableOpacity, LayoutChangeEvent } from 'react-native'
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
} from 'react-native-reanimated'
import { useTheme } from '@/utils/theme'

type SegmentedTabProps = {
  tabs: { key: string; label: string; icon: string }[]
  activeTab: string
  onTabPress: (key: string) => void
}

export function SegmentedTab({ tabs, activeTab, onTabPress }: SegmentedTabProps) {
  const { colors, isDark } = useTheme()
  const [containerWidth, setContainerWidth] = useState(0)

  // Animation value for sliding indicator
  const translateX = useSharedValue(0)
  const scale = useSharedValue(1)

  // 计算每个tab的宽度
  const tabWidth = containerWidth > 0 ? (containerWidth - 8) / tabs.length : 0 // 8 = padding

  // Pre-compute animated text styles for each tab
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
    if (index !== -1 && tabWidth > 0) {
      translateX.value = withSpring(index * tabWidth, {
        damping: 20,
        stiffness: 300,
        mass: 0.8,
      })
    }
  }, [activeTab, tabs.length, tabWidth])

  // Animated style for the sliding indicator
  const indicatorStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { scale: scale.value },
    ],
  }))

  // Handle press with bounce effect
  const handlePress = (key: string) => {
    scale.value = withSpring(0.95, { damping: 15, stiffness: 400 }, () => {
      scale.value = withSpring(1, { damping: 15, stiffness: 400 })
    })
    onTabPress(key)
  }

  // 获取容器宽度
  const handleLayout = (event: LayoutChangeEvent) => {
    setContainerWidth(event.nativeEvent.layout.width)
  }

  return (
    <View
      style={[
        styles.container,
        {
          backgroundColor: isDark ? 'rgba(255, 255, 255, 0.08)' : 'rgba(0, 0, 0, 0.05)',
        }
      ]}
      onLayout={handleLayout}
    >
      {/* Sliding indicator */}
      {tabWidth > 0 && (
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
      )}

      {/* Tab buttons - 平分宽度 */}
      {tabs.map((tab, index) => {
        const isActive = tab.key === activeTab

        return (
          <TouchableOpacity
            key={tab.key}
            style={styles.tab}
            onPress={() => handlePress(tab.key)}
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
    borderRadius: 28,
    padding: 4,
    marginHorizontal: 16,
    marginVertical: 8,
    height: 52,
  },
  indicator: {
    position: 'absolute',
    height: 44,
    borderRadius: 24,
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
    height: 44,
    zIndex: 1,
  },
  tabContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  icon: {
    fontSize: 18,
  },
  label: {
    fontSize: 15,
    fontWeight: '600',
  },
})
