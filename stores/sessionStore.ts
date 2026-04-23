import { create } from 'zustand'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { apiClient, type RecentProject } from '@/api/client'
import type { Session, Message, SessionStatus } from '@/types/session'

const STORAGE_KEY_PREFIX = 'cc_chat_messages_'

// AsyncStorage helpers for deleted sessions
const saveDeletedSession = async (sessionId: string) => {
  try {
    const key = `${STORAGE_KEY_PREFIX}deleted_`
    const existing = await AsyncStorage.getItem(key) || '[]'
    const deleted = JSON.parse(existing) as string[]
    if (!deleted.includes(sessionId)) {
      deleted.push(sessionId)
      await AsyncStorage.setItem(key, JSON.stringify(deleted))
    }
  } catch (err) {
    console.error('Failed to save deleted session:', err)
  }
}

const isSessionDeleted = async (sessionId: string): Promise<boolean> => {
  try {
    const key = `${STORAGE_KEY_PREFIX}deleted_`
    const data = await AsyncStorage.getItem(key)
    if (!data) return false
    const deleted = JSON.parse(data) as string[]
    return deleted.includes(sessionId)
  } catch (err) {
    return false
  }
}

// Remove a session from the deleted list (used when re-importing)
const removeDeletedSession = async (sessionId: string) => {
  try {
    const key = `${STORAGE_KEY_PREFIX}deleted_`
    const data = await AsyncStorage.getItem(key)
    if (!data) return
    const deleted = JSON.parse(data) as string[]
    const filtered = deleted.filter(id => id !== sessionId)
    if (filtered.length !== deleted.length) {
      await AsyncStorage.setItem(key, JSON.stringify(filtered))
    }
  } catch (err) {
    console.error('Failed to remove deleted session:', err)
  }
}

type SessionState = {
  sessions: Session[]
  currentSessionId: string | null
  messages: Record<string, Message[]>
  sessionStatuses: Record<string, SessionStatus>
  recentProjects: RecentProject[]
  isLoading: boolean
  isCreating: boolean
  error: string | null

  fetchSessions: () => Promise<void>
  setCurrentSession: (id: string | null) => void
  fetchMessages: (sessionId: string) => Promise<void>
  refreshMessages: (sessionId: string) => Promise<void>
  addMessage: (sessionId: string, message: Message) => void
  updateMessage: (sessionId: string, messageId: string, updates: Partial<Message>) => void
  updateSessionStatus: (sessionId: string, status: SessionStatus) => void
  createSession: (workDir?: string) => Promise<string | null>
  deleteSession: (sessionId: string) => Promise<void>
  importSessions: (sessionIds: string[], sessionInfos?: Session[]) => Promise<number>
  fetchRecentProjects: () => Promise<void>
  updateSessionTitle: (sessionId: string, title: string) => void
  clearError: () => void
}

export const useSessionStore = create<SessionState>((set, get) => ({
  sessions: [],
  currentSessionId: null,
  messages: {},
  sessionStatuses: {},
  recentProjects: [],
  isLoading: false,
  isCreating: false,
  error: null,

  fetchSessions: async () => {
    // Silent refresh if we already have data, to avoid UI flicker
    const hasExistingData = get().sessions.length > 0
    if (!hasExistingData) {
      set({ isLoading: true })
    }
    set({ error: null })
    try {
      const sessions = await apiClient.getSessions()
      console.log('[Store] Raw sessions from server:', sessions.length)
      // Filter out deleted sessions
      const filteredSessions = []
      for (const session of sessions) {
        if (session && !(await isSessionDeleted(session.id))) {
          filteredSessions.push(session)
        }
      }
      console.log('[Store] Filtered sessions:', filteredSessions.length)
      set({ sessions: filteredSessions, isLoading: false })
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
    // Silent refresh - don't set isLoading to avoid UI flicker
    try {
      const messages = await apiClient.getMessages(sessionId)
      set((state) => ({
        messages: { ...state.messages, [sessionId]: messages },
      }))
    } catch (err) {
      console.error('Failed to refresh messages:', err)
    }
  },

  addMessage: (sessionId, message) => {
    set((state) => {
      const existing = state.messages[sessionId] || []
      // 避免重复添加相同 ID 的消息
      if (existing.some(m => m.id === message.id)) {
        console.log('[Store] Message already exists, skipping:', message.id)
        return state
      }
      return {
        messages: {
          ...state.messages,
          [sessionId]: [...existing, message],
        },
      }
    })
  },

  updateMessage: (sessionId, messageId, updates) => {
    set((state) => {
      const existing = state.messages[sessionId]
      if (!existing) return state
      const idx = existing.findIndex(m => m.id === messageId)
      if (idx === -1) return state
      const updated = [...existing]
      updated[idx] = { ...updated[idx], ...updates }
      return {
        messages: {
          ...state.messages,
          [sessionId]: updated,
        },
      }
    })
  },

  updateSessionStatus: (sessionId, status) => {
    set((state) => ({
      sessionStatuses: {
        ...state.sessionStatuses,
        [sessionId]: status,
      },
    }))
  },

  createSession: async (workDir) => {
    set({ isCreating: true, error: null })
    try {
      const result = await apiClient.createSession(workDir)
      console.log('Created session:', result.sessionId)
      // Remove from deleted list so fetchSessions won't filter it out
      await removeDeletedSession(result.sessionId)
      await get().fetchSessions()
      set({ isCreating: false })
      return result.sessionId
    } catch (err) {
      const message = err instanceof Error ? err.message : '创建失败'
      set({ error: message, isCreating: false })
      return null
    }
  },

  // 删除对话 - 只删除本地显示，不影响桌面端
  deleteSession: async (sessionId: string) => {
    try {
      // 保存到已删除列表
      await saveDeletedSession(sessionId)
      // 从本地状态移除
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
  importSessions: async (sessionIds: string[], sessionInfos?: Session[]) => {
    let importedCount = 0
    for (let i = 0; i < sessionIds.length; i++) {
      const sessionId = sessionIds[i]
      try {
        const messages = await apiClient.getMessages(sessionId)
        const sessionInfo = sessionInfos?.find(s => s.id === sessionId)

        // Remove from deleted list so fetchSessions won't filter it out
        await removeDeletedSession(sessionId)

        set((state) => {
          const newMessages = { ...state.messages, [sessionId]: messages }
          // 如果提供了会话信息，直接添加到会话列表
          let newSessions = state.sessions
          if (sessionInfo && !state.sessions.some(s => s?.id === sessionId)) {
            newSessions = [...state.sessions, sessionInfo]
          }
          return {
            messages: newMessages,
            sessions: newSessions,
          }
        })
        importedCount++
      } catch (err) {
        console.error(`Failed to import session ${sessionId}:`, err)
      }
    }
    return importedCount
  },

  fetchRecentProjects: async () => {
    try {
      const projects = await apiClient.getRecentProjects()
      set({ recentProjects: projects })
    } catch (err) {
      console.log('Recent projects not available:', err instanceof Error ? err.message : 'unknown')
      set({ recentProjects: [] })
    }
  },

  clearError: () => set({ error: null }),

  updateSessionTitle: (sessionId, title) => {
    set((state) => ({
      sessions: state.sessions.map(s =>
        s?.id === sessionId ? { ...s, title } : s
      ),
    }))
  },
}))
