import { useState } from 'react'
import { Tabs, usePathname, useRouter } from 'expo-router'
import { View, StyleSheet } from 'react-native'
import { useTheme } from '@/utils/theme'
import { SegmentedTab } from '@/components/SegmentedTab'

export default function TabsLayout() {
  const { colors, isDark } = useTheme()
  const pathname = usePathname()
  const router = useRouter()

  const tabs = [
    { key: 'sessions', label: '会话', icon: '💬' },
    { key: 'settings', label: '设置', icon: '⚙️' },
  ]

  // Get current tab from pathname
  const currentTab = pathname.split('/')[1] || 'sessions'

  const handleTabPress = (key: string) => {
    router.push(`/${key}`)
  }

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      {/* Page content */}
      <Tabs
        screenOptions={{
          tabBarStyle: { display: 'none' },
          headerShown: false,
          contentStyle: { backgroundColor: 'transparent' },
        }}
      >
        <Tabs.Screen name="sessions" />
        <Tabs.Screen name="settings" />
      </Tabs>

      {/* Bottom Segmented Tab */}
      <View style={styles.tabContainer}>
        <SegmentedTab
          tabs={tabs}
          activeTab={currentTab}
          onTabPress={handleTabPress}
        />
      </View>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  tabContainer: {
    paddingBottom: 20,
    paddingTop: 8,
  },
})
