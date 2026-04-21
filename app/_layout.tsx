import { Stack } from 'expo-router'
import { StatusBar } from 'expo-status-bar'
import { useColorScheme } from 'react-native'

export default function RootLayout() {
  const colorScheme = useColorScheme()

  return (
    <>
      <StatusBar style="auto" />
      <Stack
        screenOptions={{
          headerStyle: {
            backgroundColor: colorScheme === 'dark' ? '#1a1a1a' : '#ffffff',
          },
          headerTintColor: colorScheme === 'dark' ? '#ffffff' : '#000000',
          contentStyle: {
            backgroundColor: colorScheme === 'dark' ? '#0a0a0a' : '#f5f5f5',
          },
        }}
      >
        <Stack.Screen name="index" options={{ headerShown: false }} />
        <Stack.Screen name="(auth)" options={{ headerShown: false }} />
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen name="chat/[id]" options={{ headerTitle: '对话' }} />
      </Stack>
    </>
  )
}
