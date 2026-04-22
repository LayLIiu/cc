import { useColorScheme } from 'react-native'

export const colors = {
  light: {
    background: '#ffffff',
    surface: '#f7f7f8',
    surfaceHover: '#ececec',
    surfaceContainer: '#f0f0f0',
    text: '#1a1a1a',
    textSecondary: '#6b6b6b',
    textTertiary: '#9a9a9a',
    border: '#e5e5e5',
    primary: '#6366f1',
    accent: '#8b5cf6',
    error: '#dc2626',
    success: '#16a34a',
    warning: {
      primary: '#ca8a04',
      secondary: '#fef3c7',
    },
  },
  dark: {
    background: '#0d0d0d',
    surface: '#1a1a1a',
    surfaceHover: '#262626',
    surfaceContainer: '#202020',
    text: '#f5f5f5',
    textSecondary: '#a0a0a0',
    textTertiary: '#666666',
    border: '#2a2a2a',
    primary: '#818cf8',
    accent: '#a78bfa',
    error: '#f87171',
    success: '#4ade80',
    warning: {
      primary: '#facc15',
      secondary: '#422006',
    },
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
