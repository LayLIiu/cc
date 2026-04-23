import { useEffect } from 'react'
import { Stack } from 'expo-router'
import { StatusBar } from 'expo-status-bar'
import * as NavigationBar from 'expo-navigation-bar'
import { Platform, useColorScheme } from 'react-native'
import { useTheme } from '@/utils/theme'

export default function RootLayout() {
  const { isDark, colors } = useTheme()
  const systemColorScheme = useColorScheme()

  // 优先使用主题颜色，如果主题还未加载则使用系统主题
  const effectiveIsDark = isDark ?? (systemColorScheme === 'dark')
  const effectiveBackground = effectiveIsDark ? '#0d0d0d' : '#ffffff'

  // Android 系统导航栏颜色跟随主题
  useEffect(() => {
    if (Platform.OS === 'android') {
      NavigationBar.setBackgroundColorAsync(colors.surface)
      NavigationBar.setButtonStyleAsync(effectiveIsDark ? 'light' : 'dark')
    }
  }, [effectiveIsDark, colors.surface])

  return (
    <>
      <StatusBar style={effectiveIsDark ? 'light' : 'dark'} />
      <Stack
        screenOptions={{
          headerStyle: {
            backgroundColor: colors.surface,
          },
          headerTintColor: colors.text,
          contentStyle: {
            backgroundColor: effectiveBackground,
          },
          animation: 'none',
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
