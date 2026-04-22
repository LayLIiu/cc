import { create } from 'zustand'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { apiClient, type RecentProject } from '@/api/client'
import type { Session, Message } from '@/types/session'

const STORAGE_KEY_PREFIX = 'cc_chat_messages_'

// AsyncStorage helpers
const saveMessagesToStorage = async (sessionId: string, messages: Message[]) => {
  try {
    const key = `${STORAGE_KEY_PREFIX}${sessionId}`
    await AsyncStorage.setItem(key, JSON.stringify(messages))
  } catch (err) {
    console.error('Failed to save messages to storage:', err)
  }
}

const getMessagesFromStorage = async (sessionId: string): Promise<Message[] | null> => {
  try {
    const key = `${STORAGE_KEY_PREFIX}${sessionId}`
    const data = await AsyncStorage.getItem(key)
    return data ? JSON.parse(data) : null
  } catch (err) {
    console.error('Failed to get messages from storage:', err)
    return null
  }
}

const clearMessagesFromStorage = async (sessionId: string) => {
  try {
    const key = `${STORAGE_KEY_PREFIX}${sessionId}`
    await AsyncStorage.removeItem(key)
  } catch (err) {
    console.error('Failed to clear messages from storage:', err)
  }
}

type SessionState = {
  sessions: Session[]
  currentSessionId: string | null
  messages: Record<string, Message[]>
  recentProjects: RecentProject[]
  isLoading: boolean
  isRefreshing: boolean
  isCreating: boolean
  error: string | null

  fetchSessions: () => Promise<void>
  setCurrentSession: (id: string | null) => void
  fetchMessages: (sessionId: string) => Promise<void>
  refreshMessages: (sessionId: string) => Promise<void>
  addMessage: (sessionId: string, message: Message) => void
  updateLastAssistantMessage: (sessionId: string, content: string) => void
  createSession: (workDir?: string) => Promise<string | null>
  deleteSession: (sessionId: string) => Promise<void>
  importSessions: (sessionIds: string[]) => Promise<number>
  fetchRecentProjects: () => Promise<void>
  clearError: () => void
  clearSessionMessages: (sessionId: string) => void
}

export const useSessionStore = create<SessionState>((set, get) => ({
  sessions: [],
  currentSessionId: null,
  messages: {},
  recentProjects: [],
  isLoading: false,
  isRefreshing: false,
  isCreating: false,
  error: null,

  fetchSessions: async () => {
    set({ isLoading: true, error: null })
    try {
      const sessions = await apiClient.getSessions()
      const uniqueSessions = sessions.filter((s, i, arr) =>
        i === arr.findIndex(x => x?.id === s?.id)
      )
      set({ sessions: uniqueSessions, isLoading: false })
    } catch (err) {
      console.log('Sessions not available:', err instanceof Error ? err.message : 'unknown')
      set({
        error: '无法连接服务器，请检查网络设置',
        sessions: [],
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

  refreshMessages: async (sessionId) => {
    set({ isRefreshing: true })
    try {
      const messages = await apiClient.getMessages(sessionId)
      set((state) => ({
        messages: { ...state.messages, [sessionId]: messages },
        isRefreshing: false,
      }))
    } catch (err) {
      console.error('Failed to refresh messages:', err)
      set({ isRefreshing: false })
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

  updateLastAssistantMessage: (sessionId, content) => {
    set((state) => {
      const existing = state.messages[sessionId] || []
      if (existing.length === 0) return state

      const lastMsg = existing[existing.length - 1]
      if (lastMsg.type !== 'assistant_text') return state

      const updated = [...existing]
      updated[updated.length - 1] = { ...lastMsg, content }

      return {
        messages: { ...state.messages, [sessionId]: updated },
      }
    })
  },

  createSession: async (workDir) => {
    set({ isCreating: true, error: null })
    try {
      const result = await apiClient.createSession(workDir)
      console.log('Created session:', result.sessionId)

      // Refresh sessions list
      await get().fetchSessions()

      set({ isCreating: false })
      return result.sessionId
    } catch (err) {
      const message = err instanceof Error ? err.message : '创建失败'
      set({ error: message, isCreating: false })
      return null
    }
  },

  deleteSession: async (sessionId: string) => {
    try {
      // Call API to delete session from server
      await apiClient.deleteSession(sessionId)
      // Clear local messages
      await clearMessagesFromStorage(sessionId)
      // Remove from local state
      set((state) => {
        const newSessions = state.sessions.filter(s => s?.id !== sessionId)
        const newMessages = { ...state.messages }
        delete newMessages[sessionId]
        return {
          sessions: newSessions,
          messages: newMessages,
        }
      })
    } catch (err) {
      console.error('Failed to delete session:', err)
      throw err
    }
  },

  // 导入选中的对话（从服务器获取消息并保存到本地）
  importSessions: async (sessionIds: string[]) => {
    let importedCount = 0
    for (const sessionId of sessionIds) {
      try {
        // 从服务器获取消息
        const messages = await apiClient.getMessages(sessionId)
        // 保存到本地
        await saveMessagesToStorage(sessionId, messages)
        importedCount++
      } catch (err) {
        console.error(`Failed to import session ${sessionId}:`, err)
      }
    }
    // 刷新会话列表
    await useSessionStore.getState().fetchSessions()
    return importedCount
  },

  fetchRecentProjects: async () => {
    try {
      const projects = await apiClient.getRecentProjects()
      set({ recentProjects: projects })
    } catch (err) {
      // 静默处理，不影响主功能
      console.log('Recent projects not available:', err instanceof Error ? err.message : 'unknown')
      set({ recentProjects: [] })
    }
  },

  clearError: () => set({ error: null }),

  clearSessionMessages: async (sessionId) => {
    await clearMessagesFromStorage(sessionId)
    set((state) => {
      const newMessages = { ...state.messages }
      delete newMessages[sessionId]
      return { messages: newMessages }
    })
  },
}))
