import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import AsyncStorage from '@react-native-async-storage/async-storage'

type User = {
  id: string
  email: string
  name: string
}

export type ThemeMode = 'light' | 'dark' | 'system'

type AuthState = {
  user: User | null
  token: string | null
  serverUrl: string
  tunnelUrl: string | null
  isLoggedIn: boolean
  isHydrated: boolean
  themeMode: ThemeMode

  login: (user: User, token: string) => void
  logout: () => void
  setServerUrl: (url: string) => void
  setTunnelUrl: (url: string) => void
  setHydrated: () => void
  setThemeMode: (mode: ThemeMode) => void
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      serverUrl: 'http://192.168.3.33:3456',
      tunnelUrl: null,
      isLoggedIn: false,
      isHydrated: false,
      themeMode: 'system',

      login: (user, token) => set({ user, token, isLoggedIn: true }),

      logout: () => set({ user: null, token: null, isLoggedIn: false }),

      setServerUrl: (url) => set({ serverUrl: url }),

      setTunnelUrl: (url) => set({ tunnelUrl: url }),

      setHydrated: () => set({ isHydrated: true }),

      setThemeMode: (mode) => set({ themeMode: mode }),
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => AsyncStorage),
      onRehydrateStorage: () => (state) => {
        if (state) {
          state.isHydrated = true
        }
      },
      partialize: (state) => ({
        user: state.user,
        token: state.token,
        serverUrl: state.serverUrl,
        tunnelUrl: state.tunnelUrl,
        isLoggedIn: state.isLoggedIn,
        themeMode: state.themeMode,
      }),
    }
  )
)
