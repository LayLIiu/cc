import { create } from 'zustand'
import { apiClient } from '@/api/client'
import type { Session, Message } from '@/types/session'

type SessionState = {
  sessions: Session[]
  currentSessionId: string | null
  messages: Record<string, Message[]>
  isLoading: boolean
  error: string | null

  fetchSessions: () => Promise<void>
  setCurrentSession: (id: string | null) => void
  fetchMessages: (sessionId: string) => Promise<void>
  addMessage: (sessionId: string, message: Message) => void
  clearError: () => void
}

export const useSessionStore = create<SessionState>((set, get) => ({
  sessions: [],
  currentSessionId: null,
  messages: {},
  isLoading: false,
  error: null,

  fetchSessions: async () => {
    set({ isLoading: true, error: null })
    try {
      const sessions = await apiClient.getSessions()
      set({ sessions, isLoading: false })
    } catch (err) {
      set({
        error: err instanceof Error ? err.message : '加载失败',
        isLoading: false,
      })
    }
  },

  setCurrentSession: (id) => {
    set({ currentSessionId: id })
    if (id && !get().messages[id]) {
      get().fetchMessages(id)
    }
  },

  fetchMessages: async (sessionId) => {
    try {
      const messages = await apiClient.getMessages(sessionId)
      set((state) => ({
        messages: { ...state.messages, [sessionId]: messages },
      }))
    } catch (err) {
      console.error('Failed to fetch messages:', err)
    }
  },

  addMessage: (sessionId, message) => {
    set((state) => {
      const existing = state.messages[sessionId] || []
      return {
        messages: {
          ...state.messages,
          [sessionId]: [...existing, message],
        },
      }
    })
  },

  clearError: () => set({ error: null }),
}))
