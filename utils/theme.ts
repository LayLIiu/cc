import { useColorScheme, Appearance } from 'react-native'
import { useAuthStore, type ThemeMode } from '@/stores/authStore'

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

/**
 * 根据 themeMode 解析出实际的 isDark 值
 * glass 模式始终使用深色（深灰玻璃质感）
 */
function resolveIsDark(mode: ThemeMode, systemScheme: string | null): boolean {
  switch (mode) {
    case 'light':
      return false
    case 'dark':
      return true
    case 'glass':
      return true
    case 'system':
    default:
      return systemScheme === 'dark'
  }
}

/**
 * 同步系统级别的 colorScheme（影响系统导航栏、状态栏等）
 * glass 模式强制深色，确保原生 UI 也是深色调
 */
function syncSystemAppearance(mode: ThemeMode) {
  if (mode === 'light') {
    Appearance.setColorScheme('light')
  } else if (mode === 'dark' || mode === 'glass') {
    Appearance.setColorScheme('dark')
  } else {
    Appearance.setColorScheme(null)
  }
}

export function useTheme() {
  const systemColorScheme = useColorScheme()
  const themeMode = useAuthStore((state) => state.themeMode)
  const isHydrated = useAuthStore((state) => state.isHydrated)

  // store 还没恢复时，先用系统值
  const effectiveMode = isHydrated ? themeMode : 'system'
  const isDark = resolveIsDark(effectiveMode, systemColorScheme)

  // 同步系统级外观
  syncSystemAppearance(effectiveMode)

  const isGlass = effectiveMode === 'glass'

  return {
    isDark,
    colors: isDark ? colors.dark : colors.light,
    themeMode: effectiveMode,
    isGlass,
  }
}
