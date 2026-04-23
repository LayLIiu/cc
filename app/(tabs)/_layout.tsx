import { Tabs } from 'expo-router'
import { useTheme } from '@/utils/theme'
import { TabIcon } from '@/components/TabIcon'

export default function TabsLayout() {
  const { colors, isDark } = useTheme()

  return (
    <Tabs
      screenOptions={{
        tabBarStyle: {
          backgroundColor: colors.surface,
          borderTopColor: colors.border,
          borderTopWidth: 1,
          height: 90,
          paddingBottom: 8,
          paddingTop: 8,
        },
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.textTertiary,
        headerStyle: {
          backgroundColor: colors.background,
        },
        headerTintColor: colors.text,
        headerTitleStyle: {
          fontWeight: '600',
        },
        headerShadowVisible: false,
      }}
    >
      <Tabs.Screen
        name="sessions"
        options={{
          title: 'Claude Code',
          tabBarLabel: () => null,
          tabBarIcon: ({ color, focused }) => (
            <TabIcon icon="💬" label="会话" color={color} focused={focused} />
          ),
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: '设置',
          tabBarLabel: () => null,
          tabBarIcon: ({ color, focused }) => (
            <TabIcon icon="⚙️" label="设置" color={color} focused={focused} />
          ),
        }}
      />
    </Tabs>
  )
}

