import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import AsyncStorage from '@react-native-async-storage/async-storage'

type User = {
  id: string
  email: string
  name: string
}

export type ThemeMode = 'light' | 'dark' | 'system' | 'glass'

export type ServerMode = 'lan' | 'tunnel'

type AuthState = {
  user: User | null
  token: string | null
  // 当前使用的服务器地址（动态计算）
  serverUrl: string
  // 局域网地址
  lanUrl: string
  // 公网地址
  tunnelUrl: string
  // 当前模式
  serverMode: ServerMode
  isLoggedIn: boolean
  isHydrated: boolean
  themeMode: ThemeMode

  login: (user: User, token: string) => void
  logout: () => void
  setLanUrl: (url: string) => void
  setTunnelUrl: (url: string) => void
  setServerMode: (mode: ServerMode) => void
  setHydrated: () => void
  setThemeMode: (mode: ThemeMode) => void
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      token: null,
      serverUrl: '',
      lanUrl: '',
      tunnelUrl: '',
      serverMode: 'lan',
      isLoggedIn: false,
      isHydrated: false,
      themeMode: 'system',

      login: (user, token) => set({ user, token, isLoggedIn: true }),

      logout: () => set({ user: null, token: null, isLoggedIn: false }),

      setLanUrl: (url) => {
        // 设置局域网地址，并自动切换到局域网模式
        set({
          lanUrl: url,
          serverMode: 'lan',
          serverUrl: url
        })
      },

      setTunnelUrl: (url) => {
        // 设置公网地址，并自动切换到公网模式
        set({
          tunnelUrl: url,
          serverMode: 'tunnel',
          serverUrl: url
        })
      },

      setServerMode: (mode) => {
        const { lanUrl, tunnelUrl } = get()
        set({
          serverMode: mode,
          serverUrl: mode === 'lan' ? lanUrl : tunnelUrl
        })
      },

      setHydrated: () => set({ isHydrated: true }),

      setThemeMode: (mode) => set({ themeMode: mode }),
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => AsyncStorage),
      onRehydrateStorage: () => (state) => {
        if (state) {
          state.isHydrated = true
          // 恢复后根据模式设置正确的 serverUrl
          if (state.lanUrl || state.tunnelUrl) {
            state.serverUrl = state.serverMode === 'lan' ? state.lanUrl : state.tunnelUrl
          }
        }
      },
      partialize: (state) => ({
        user: state.user,
        token: state.token,
        lanUrl: state.lanUrl,
        tunnelUrl: state.tunnelUrl,
        serverMode: state.serverMode,
        isLoggedIn: state.isLoggedIn,
        themeMode: state.themeMode,
      }),
    }
  )
)
