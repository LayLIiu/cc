import React, { useEffect, useMemo, useState, ReactNode } from 'react'
import { View, Text, StyleSheet, TouchableOpacity, LayoutChangeEvent } from 'react-native'
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
} from 'react-native-reanimated'
import { useTheme } from '@/utils/theme'

export type TabItem = {
  key: string
  label?: string
  icon?: string
  iconComponent?: ReactNode // 自定义图标组件
}

type SegmentedTabProps = {
  tabs: TabItem[]
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
          backgroundColor: 'transparent',
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
              backgroundColor: isDark ? 'rgba(100, 100, 100, 0.6)' : 'rgba(150, 150, 150, 0.6)',
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
              {tab.iconComponent ? (
                tab.iconComponent
              ) : (
                <Text style={styles.icon}>{tab.icon}</Text>
              )}
              {tab.label && (
                <Animated.Text
                  style={[
                    styles.label,
                    { color: isActive ? '#fff' : colors.text },
                    tabAnimatedStyles[index],
                  ]}
                >
                  {tab.label}
                </Animated.Text>
              )}
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
    borderRadius: 24,
    padding: 4,
    marginHorizontal: 0,
    marginVertical: 4,
    height: 52,
  },
  indicator: {
    position: 'absolute',
    height: 44,
    borderRadius: 22,
    top: 4,
    left: 4,
    backgroundColor: 'rgba(120, 120, 120, 0.3)',
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
