import { Tabs, usePathname, useRouter } from 'expo-router'
import { View, StyleSheet, Keyboard, Platform } from 'react-native'
import { BlurView } from 'expo-blur'
import { useTheme } from '@/utils/theme'
import { SegmentedTab, TabItem } from '@/components/SegmentedTab'
import { MascotWidget } from '@/components/shared/MascotWidget'
import { ProviderMascotWidget } from '@/components/shared/ProviderMascot'
import { SettingsMascotWidget } from '@/components/shared/SettingsMascot'
import { useSessionStore } from '@/stores/sessionStore'
import { useGlobalStatus } from '@/hooks/useSharedWebSocket'
import { useMemo, useState, useEffect } from 'react'
import { useSafeAreaInsets } from 'react-native-safe-area-context'

export default function TabsLayout() {
  const { colors, isDark, isGlass } = useTheme()
  const pathname = usePathname()
  const router = useRouter()
  const sessionStatuses = useSessionStore((state) => state.sessionStatuses)
  const insets = useSafeAreaInsets()
  const [keyboardVisible, setKeyboardVisible] = useState(false)

  // 全局状态监听
  useGlobalStatus()

  // 监听键盘状态
  useEffect(() => {
    const showSubscription = Keyboard.addListener('keyboardWillShow', () => {
      setKeyboardVisible(true)
    })
    const hideSubscription = Keyboard.addListener('keyboardWillHide', () => {
      setKeyboardVisible(false)
    })

    return () => {
      showSubscription.remove()
      hideSubscription.remove()
    }
  }, [])

  // 计算整体会话状态
  const globalStatus = useMemo(() => {
    const statuses = Object.values(sessionStatuses)

    // 有任何对话等待权限 → alertScene
    if (statuses.includes('permission_pending')) {
      return 'waitingApproval'
    }

    // 有任何对话工作中 → workScene（优先级最高）
    const workingStatuses = ['thinking', 'tool_executing', 'streaming']
    if (statuses.some(s => workingStatuses.includes(s))) {
      return 'processing'
    }

    // 有任何对话已完成 → completed
    if (statuses.includes('completed')) {
      return 'completed'
    }

    // 所有对话都空闲 → sleepScene
    return 'idle'
  }, [sessionStatuses])

  const tabs: TabItem[] = [
    {
      key: 'sessions',
      iconComponent: <MascotWidget size={28} status={globalStatus} />,
    },
    {
      key: 'providers',
      iconComponent: <ProviderMascotWidget size={26} />,
    },
    {
      key: 'settings',
      iconComponent: <SettingsMascotWidget size={26} />,
    },
  ]

  // Get current tab from pathname
  const currentTab = pathname.split('/')[1] || 'sessions'

  const handleTabPress = (key: string) => {
    router.push(`/(tabs)/${key}` as any)
  }

  // 计算 tab 栏底部位置 - 固定值，不随内容变化
  const tabBarBottom = keyboardVisible ? -100 : (insets.bottom + 8)

  return (
    <View style={styles.container}>
      {/* Page content */}
      <Tabs
        screenOptions={{
          tabBarStyle: { display: 'none' },
          headerShown: false,
        }}
      >
        <Tabs.Screen name="sessions" />
        <Tabs.Screen name="providers" />
        <Tabs.Screen name="settings" />
      </Tabs>

      {/* Bottom Tab Bar - iOS Style */}
      {isGlass ? (
        // glass 模式：BlurView 毛玻璃/液态玻璃效果
        <BlurView
          intensity={80}
          tint="dark"
          style={[
            styles.tabBarContainer,
            { bottom: tabBarBottom },
          ]}
          pointerEvents={keyboardVisible ? 'none' : 'auto'}
        >
          <SegmentedTab
            tabs={tabs}
            activeTab={currentTab}
            onTabPress={handleTabPress}
          />
        </BlurView>
      ) : (
        // 普通模式：半透明纯色背景
        <View
          style={[
            styles.tabBarContainer,
            {
              bottom: tabBarBottom,
              backgroundColor: isDark
                ? 'rgba(30, 30, 30, 0.85)'
                : 'rgba(255, 255, 255, 0.85)',
            },
          ]}
          pointerEvents={keyboardVisible ? 'none' : 'auto'}
        >
          <SegmentedTab
            tabs={tabs}
            activeTab={currentTab}
            onTabPress={handleTabPress}
          />
        </View>
      )}
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  tabBarContainer: {
    position: 'absolute',
    left: 16,
    right: 16,
    borderRadius: 28,
    borderWidth: 0.5,
    borderColor: 'rgba(255, 255, 255, 0.3)',
    overflow: 'hidden',
  },
})
