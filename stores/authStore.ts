import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import AsyncStorage from '@react-native-async-storage/async-storage'

type User = {
  id: string
  email: string
  name: string
}

type AuthState = {
  user: User | null
  token: string | null
  serverUrl: string
  isLoggedIn: boolean
  isHydrated: boolean

  login: (user: User, token: string) => void
  logout: () => void
  setServerUrl: (url: string) => void
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      serverUrl: 'http://127.0.0.1:3456',
      isLoggedIn: false,
      isHydrated: false,

      login: (user, token) => set({ user, token, isLoggedIn: true }),

      logout: () => set({ user: null, token: null, isLoggedIn: false }),

      setServerUrl: (url) => set({ serverUrl: url }),
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => AsyncStorage),
      onRehydrateStorage: () => (state) => {
        state!.isHydrated = true
      },
    }
  )
)
