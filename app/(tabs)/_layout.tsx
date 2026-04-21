import { Tabs } from 'expo-router'
import { useColorScheme } from 'react-native'

export default function TabsLayout() {
  const colorScheme = useColorScheme()

  return (
    <Tabs
      screenOptions={{
        tabBarStyle: {
          backgroundColor: colorScheme === 'dark' ? '#1a1a1a' : '#ffffff',
          borderTopColor: colorScheme === 'dark' ? '#333' : '#e5e5e5',
        },
        tabBarActiveTintColor: '#6366f1',
        tabBarInactiveTintColor: colorScheme === 'dark' ? '#666' : '#999',
        headerStyle: {
          backgroundColor: colorScheme === 'dark' ? '#1a1a1a' : '#ffffff',
        },
        headerTintColor: colorScheme === 'dark' ? '#ffffff' : '#000000',
      }}
    >
      <Tabs.Screen
        name="sessions"
        options={{
          title: '会话',
          tabBarIcon: ({ color }) => (
            <TabBarIcon name="chatbubbles" color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: '设置',
          tabBarIcon: ({ color }) => (
            <TabBarIcon name="settings" color={color} />
          ),
        }}
      />
    </Tabs>
  )
}

function TabBarIcon({ name, color }: { name: string; color: string }) {
  // Using simple text icons for now, can replace with react-native-vector-icons later
  return null
}
