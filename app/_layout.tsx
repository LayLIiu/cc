import { useEffect } from 'react'
import { Stack } from 'expo-router'
import { StatusBar } from 'expo-status-bar'
import * as NavigationBar from 'expo-navigation-bar'
import { Platform } from 'react-native'
import { useTheme } from '@/utils/theme'
import { setWindowBackground } from '@/utils/windowBackground'

export default function RootLayout() {
  const { isDark, colors, isGlass } = useTheme()

  // Android 系统导航栏颜色跟随主题
  useEffect(() => {
    if (Platform.OS === 'android') {
      NavigationBar.setBackgroundColorAsync(colors.surface)
      NavigationBar.setButtonStyleAsync(isDark ? 'light' : 'dark')
      setWindowBackground(colors.background)
    }
  }, [isDark, colors.background, colors.surface])

  // glass 模式：透明背景 + 深色原生模糊/液态玻璃
  // 始终使用深色调，呈现深灰玻璃质感
  const glassScreenOptions = {
    headerTransparent: true,
    headerTintColor: '#f5f5f5',
    headerStyle: {
      backgroundColor: 'rgba(13, 13, 13, 0.7)',
    },
    contentStyle: {
      backgroundColor: '#1a1a1a',
    },
  } as const

  // 普通模式：不透明纯色背景
  const solidScreenOptions = {
    headerStyle: {
      backgroundColor: colors.surface,
    },
    headerTintColor: colors.text,
    contentStyle: {
      backgroundColor: colors.background,
    },
  } as const

  return (
    <>
      <StatusBar style={isDark || isGlass ? 'light' : 'dark'} />
      <Stack screenOptions={isGlass ? glassScreenOptions : solidScreenOptions}>
        <Stack.Screen name="index" options={{ headerShown: false }} />
        <Stack.Screen name="(auth)" options={{ headerShown: false }} />
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen name="chat/[id]" options={{ headerTitle: '对话' }} />
      </Stack>
    </>
  )
}
