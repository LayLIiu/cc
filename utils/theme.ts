import { useColorScheme } from 'react-native'

export const colors = {
  light: {
    background: '#f5f5f5',
    surface: '#ffffff',
    surfaceHover: '#f0f0f0',
    text: '#000000',
    textSecondary: '#666666',
    textTertiary: '#999999',
    border: '#e5e5e5',
    primary: '#6366f1',
    error: '#ef4444',
    success: '#22c55e',
  },
  dark: {
    background: '#0a0a0a',
    surface: '#1a1a1a',
    surfaceHover: '#252525',
    text: '#ffffff',
    textSecondary: '#a0a0a0',
    textTertiary: '#666666',
    border: '#333333',
    primary: '#818cf8',
    error: '#f87171',
    success: '#4ade80',
  },
}

export function useTheme() {
  const colorScheme = useColorScheme()
  const isDark = colorScheme === 'dark'
  return {
    isDark,
    colors: isDark ? colors.dark : colors.light,
  }
}
