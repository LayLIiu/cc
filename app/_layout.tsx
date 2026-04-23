import { useEffect } from 'react'
import { Stack } from 'expo-router'
import { StatusBar } from 'expo-status-bar'
import * as NavigationBar from 'expo-navigation-bar'
import { Platform } from 'react-native'
import { useTheme } from '@/utils/theme'
import { setWindowBackground } from '@/utils/windowBackground'

export default function RootLayout() {
  const { isDark, colors } = useTheme()

  // Android 系统导航栏颜色跟随主题
  useEffect(() => {
    if (Platform.OS === 'android') {
      NavigationBar.setBackgroundColorAsync(colors.surface)
      NavigationBar.setButtonStyleAsync(isDark ? 'light' : 'dark')
      // 设置原生窗口背景色，解决深色模式下页面跳转白色闪烁
      setWindowBackground(colors.background)
    }
  }, [isDark, colors.background, colors.surface])

  return (
    <>
      <StatusBar style={isDark ? 'light' : 'dark'} />
      <Stack
        screenOptions={{
          headerStyle: {
            backgroundColor: colors.surface,
          },
          headerTintColor: colors.text,
          contentStyle: {
            backgroundColor: colors.background,
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
