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
  messageIds: Record<string, Set<string>> // 快速查重
  // 状态和时间戳作为单一对象存储，确保原子更新
  sessionStatuses: Record<string, SessionStatus>
  sessionStatusTimestamps: Record<string, number>
  // completed 状态的定时器引用（用于 1 分钟后自动清除）
  completedTimers: Record<string, ReturnType<typeof setTimeout>> // timerId 用于清理
  // 上下文容量使用百分比（来自桌面端真实数据）
  contextUsages: Record<string, number>
  // 加载状态
  isLoading: boolean
  isCreating: boolean
  error: string | null
  recentProjects: RecentProject[]

  fetchSessions: () => Promise<void>
  setCurrentSession: (id: string | null) => void
  fetchMessages: (sessionId: string) => Promise<void>
  refreshMessages: (sessionId: string) => Promise<void>
  addMessage: (sessionId: string, message: Message) => void
  updateMessage: (sessionId: string, messageId: string, updates: Partial<Message>) => void
  updateSessionStatus: (sessionId: string, status: SessionStatus) => void
  clearStaleSessionStatuses: () => void
  clearCompletedTimer: (sessionId: string) => void
  setCompletedTimer: (sessionId: string, timerId: ReturnType<typeof setTimeout>) => void
  setContextUsage: (sessionId: string, percentage: number) => void
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
  messageIds: {},
  sessionStatuses: {},
  sessionStatusTimestamps: {},
  completedTimers: {},
  contextUsages: {},
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
      // 清理 contextUsages：保留仅存在于当前会话列表中的条目
      const validIds = new Set(filteredSessions.map(s => s!.id))
      const cleanedContextUsages: Record<string, number> = {}
      const existingUsages = get().contextUsages
      for (const id of Object.keys(existingUsages)) {
        if (validIds.has(id)) {
          cleanedContextUsages[id] = existingUsages[id]
        }
      }
      set({ sessions: filteredSessions, isLoading: false, contextUsages: cleanedContextUsages })
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
      // 创建消息 ID Set 用于快速查重
      const ids = new Set(messages.map(m => m.id))
      set((state) => ({
        messages: { ...state.messages, [sessionId]: messages },
        messageIds: { ...state.messageIds, [sessionId]: ids },
      }))
    } catch (err) {
      console.error('Failed to fetch messages:', err)
    }
  },

  refreshMessages: async (sessionId) => {
    try {
      const messages = await apiClient.getMessages(sessionId)
      const ids = new Set(messages.map(m => m.id))
      set((state) => ({
        messages: { ...state.messages, [sessionId]: messages },
        messageIds: { ...state.messageIds, [sessionId]: ids },
      }))
    } catch (err) {
      console.error('Failed to refresh messages:', err)
    }
  },

  addMessage: (sessionId, message) => {
    set((state) => {
      const ids = state.messageIds[sessionId] || new Set()
      // 快速查重
      if (ids.has(message.id)) {
        return state
      }
      const existing = state.messages[sessionId] || []
      const newIds = new Set(ids)
      newIds.add(message.id)
      return {
        messages: {
          ...state.messages,
          [sessionId]: [...existing, message],
        },
        messageIds: {
          ...state.messageIds,
          [sessionId]: newIds,
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
    const now = Date.now()
    set((state) => {
      // 如果状态变为非 completed，清除对应的定时器
      if (status !== 'completed' && state.completedTimers[sessionId]) {
        clearTimeout(state.completedTimers[sessionId])
      }

      return {
        sessionStatuses: {
          ...state.sessionStatuses,
          [sessionId]: status,
        },
        sessionStatusTimestamps: {
          ...state.sessionStatusTimestamps,
          [sessionId]: now,
        },
        // 如果不是 completed 状态，清除定时器
        completedTimers: status !== 'completed'
          ? Object.fromEntries(Object.entries(state.completedTimers).filter(([id]) => id !== sessionId))
          : state.completedTimers,
      }
    })
  },

  setCompletedTimer: (sessionId, timerId) => {
    set((state) => ({
      completedTimers: {
        ...state.completedTimers,
        [sessionId]: timerId,
      },
    }))
  },

  clearCompletedTimer: (sessionId) => {
    set((state) => {
      const timerId = state.completedTimers[sessionId]
      if (timerId) {
        clearTimeout(timerId)
      }
      const newTimers = { ...state.completedTimers }
      delete newTimers[sessionId]
      return { completedTimers: newTimers }
    })
  },

  setContextUsage: (sessionId, percentage) => {
    set((state) => ({
      contextUsages: {
        ...state.contextUsages,
        [sessionId]: percentage,
      },
    }))
  },

  // 清除超过 10 分钟未更新的状态（给桌面端足够长的时间完成思考）
  clearStaleSessionStatuses: () => {
    const now = Date.now()
    const staleThreshold = 10 * 60 * 1000 // 10 分钟 - 确保长时间思考不会被错误清理

    set((state) => {
      const newStatuses: Record<string, SessionStatus> = {}
      const newTimestamps: Record<string, number> = {}
      const newTimers: Record<string, ReturnType<typeof setTimeout>> = {}
      const newContextUsages: Record<string, number> = {}

      for (const [sessionId, status] of Object.entries(state.sessionStatuses)) {
        const timestamp = state.sessionStatusTimestamps[sessionId] || 0
        // 保留所有在阈值内更新的状态（包括工作状态）
        if (now - timestamp < staleThreshold) {
          newStatuses[sessionId] = status
          newTimestamps[sessionId] = timestamp
          // 保留对应的定时器
          if (state.completedTimers[sessionId]) {
            newTimers[sessionId] = state.completedTimers[sessionId]
          }
          // 保留对应的上下文容量
          if (state.contextUsages[sessionId] !== undefined) {
            newContextUsages[sessionId] = state.contextUsages[sessionId]
          }
        } else {
          // 清理过期状态时，同时清理对应的定时器
          const timer = state.completedTimers[sessionId]
          if (timer) {
            clearTimeout(timer)
          }
        }
      }

      // 保留 contextUsages 中未被 sessionStatuses 覆盖的条目
      // （token_usage 消息可能在被 useGlobalStatus 接收到时，还没有对应的 sessionStatus）
      for (const [sessionId, usage] of Object.entries(state.contextUsages)) {
        if (newContextUsages[sessionId] === undefined) {
          newContextUsages[sessionId] = usage
        }
      }

      return {
        sessionStatuses: newStatuses,
        sessionStatusTimestamps: newTimestamps,
        completedTimers: newTimers,
        contextUsages: newContextUsages,
      }
    })
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
      await saveDeletedSession(sessionId)
      set((state) => {
        const newSessions = state.sessions.filter(s => s?.id !== sessionId)
        const newMessages = { ...state.messages }
        const newMessageIds = { ...state.messageIds }
        const newContextUsages = { ...state.contextUsages }
        delete newMessages[sessionId]
        delete newMessageIds[sessionId]
        delete newContextUsages[sessionId]
        return {
          sessions: newSessions,
          messages: newMessages,
          messageIds: newMessageIds,
          contextUsages: newContextUsages,
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
        const sessionInfo = sessionInfos?.find(s => s?.id === sessionId)

        await removeDeletedSession(sessionId)

        const ids = new Set(messages.map(m => m.id))
        set((state) => {
          const newMessages = { ...state.messages, [sessionId]: messages }
          const newMessageIds = { ...state.messageIds, [sessionId]: ids }
          let newSessions = state.sessions
          if (sessionInfo && !state.sessions.some(s => s?.id === sessionId)) {
            newSessions = [...state.sessions, sessionInfo]
          }
          return {
            messages: newMessages,
            messageIds: newMessageIds,
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
