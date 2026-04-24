// hooks/useSharedWebSocket.ts

import { useEffect, useRef, useCallback, useMemo, useState } from 'react'
import { useAuthStore } from '@/stores/authStore'
import { useSessionStore } from '@/stores/sessionStore'
import { apiClient } from '@/api/client'

type ServerMessage = {
  type: string
  [key: string]: any
}

type Connection = {
  ws: WebSocket | null
  status: 'connecting' | 'connected' | 'disconnected' | 'error'
  handlers: Set<(msg: ServerMessage) => void>
  reconnectAttempts: number
  reconnectTimer: ReturnType<typeof setTimeout> | null
  lastActivity: number
}

// 全局 WebSocket 连接管理器
class WebSocketManager {
  private connections = new Map<string, Connection>()
  private cleanupInterval: ReturnType<typeof setInterval> | null = null

  // 订阅消息
  onMessage(sessionId: string, handler: (msg: ServerMessage) => void): () => void {
    let conn = this.connections.get(sessionId)
    if (!conn) {
      conn = this.connect(sessionId)
    }
    conn.handlers.add(handler)
    conn.lastActivity = Date.now()

    // 返回取消订阅函数
    return () => {
      const c = this.connections.get(sessionId)
      if (c) {
        c.handlers.delete(handler)
      }
    }
  }

  // 发送消息
  send(sessionId: string, message: Record<string, unknown>): boolean {
    const conn = this.connections.get(sessionId)
    if (!conn || !conn.ws || conn.ws.readyState !== WebSocket.OPEN) {
      console.log(`[SharedWS] Cannot send to ${sessionId}, ws not ready (readyState=${conn?.ws?.readyState})`)
      return false
    }
    conn.ws.send(JSON.stringify(message))
    conn.lastActivity = Date.now()
    return true
  }

  // 发送消息，如果连接未就绪则延迟重试
  sendWithRetry(sessionId: string, message: Record<string, unknown>, maxRetries = 5): void {
    let attempt = 0
    const trySend = () => {
      attempt++
      if (this.send(sessionId, message)) {
        return
      }
      if (attempt < maxRetries) {
        setTimeout(trySend, 500 * attempt)
      } else {
        console.log(`[SharedWS] Failed to send to ${sessionId} after ${maxRetries} retries`)
      }
    }
    trySend()
  }

  // 断开连接
  disconnect(sessionId: string) {
    const conn = this.connections.get(sessionId)
    if (conn) {
      conn.handlers.clear()
    }
  }

  // 获取连接状态
  getConnection(sessionId: string): Connection | null {
    return this.connections.get(sessionId) || null
  }

  // 连接到会话
  private connect(sessionId: string): Connection {
    const serverUrl = useAuthStore.getState().serverUrl
    const isHydrated = useAuthStore.getState().isHydrated

    const conn: Connection = {
      ws: null,
      status: 'connecting',
      handlers: new Set(),
      reconnectAttempts: 0,
      reconnectTimer: null,
      lastActivity: Date.now(),
    }

    this.connections.set(sessionId, conn)

    if (isHydrated && serverUrl) {
      this.establishConnection(sessionId, conn)
    } else {
      // 如果还没准备好，延迟重试
      console.log(`[SharedWS] Not ready to connect ${sessionId}, will retry...`)
      setTimeout(() => {
        const c = this.connections.get(sessionId)
        if (c && !c.ws) {
          const url = useAuthStore.getState().serverUrl
          const hydrated = useAuthStore.getState().isHydrated
          if (hydrated && url) {
            this.establishConnection(sessionId, c)
          }
        }
      }, 1000)
    }

    return conn
  }

  private establishConnection(sessionId: string, conn: Connection) {
    const serverUrl = useAuthStore.getState().serverUrl

    if (!serverUrl || (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://'))) {
      return
    }

    const wsUrl = serverUrl
      .replace('http://', 'ws://')
      .replace('https://', 'wss://') + `/ws/${sessionId}`

    console.log(`[SharedWS] Connecting to session:`, sessionId)

    try {
      const ws = new WebSocket(wsUrl)

      ws.onopen = () => {
        console.log(`[SharedWS] Session ${sessionId} connected`)
        conn.status = 'connected'
        conn.reconnectAttempts = 0
        conn.ws = ws
        conn.lastActivity = Date.now()
      }

      ws.onmessage = (event) => {
        try {
          const msg: ServerMessage = JSON.parse(event.data)
          // 广播给所有订阅者
          for (const handler of conn.handlers) {
            handler(msg)
          }
          conn.lastActivity = Date.now()
        } catch (e) {
          console.error(`[SharedWS] Parse error for ${sessionId}:`, e)
        }
      }

      ws.onclose = () => {
        console.log(`[SharedWS] Session ${sessionId} disconnected`)
        conn.status = 'disconnected'
        conn.ws = null
        this.scheduleReconnect(sessionId, conn)
      }

      ws.onerror = () => {
        console.error(`[SharedWS] Session ${sessionId} error`)
        conn.status = 'error'
      }

      conn.ws = ws
    } catch (e) {
      console.error(`[SharedWS] Failed to connect to ${sessionId}:`, e)
      conn.status = 'error'
    }
  }

  private scheduleReconnect(sessionId: string, conn: Connection) {
    // 如果没有订阅者，不需要重连
    if (conn.handlers.size === 0) {
      console.log(`[SharedWS] No handlers for ${sessionId}, not reconnecting`)
      return
    }

    if (conn.reconnectAttempts >= 5) {
      console.log(`[SharedWS] Max reconnect attempts for ${sessionId}`)
      return
    }

    conn.reconnectAttempts++
    const delay = Math.min(1000 * Math.pow(2, conn.reconnectAttempts - 1), 10000)

    console.log(`[SharedWS] Reconnecting to ${sessionId} in ${delay}ms`)

    conn.reconnectTimer = setTimeout(() => {
      if (this.connections.get(sessionId) === conn) {
        this.establishConnection(sessionId, conn)
      }
    }, delay)
  }

  // 定期清理空闲连接
  startCleanup() {
    if (this.cleanupInterval) return

    this.cleanupInterval = setInterval(() => {
      const now = Date.now()
      const toDelete: string[] = []

      for (const [sessionId, conn] of this.connections) {
        // 如果超过 5 分钟没有活动且没有订阅者，关闭连接
        if (conn.handlers.size === 0 && now - conn.lastActivity > 300000) {
          console.log(`[SharedWS] Cleaning up idle connection: ${sessionId}`)
          if (conn.ws) {
            try {
              conn.ws.close()
            } catch (e) {}
          }
          toDelete.push(sessionId)
        }
      }

      for (const sessionId of toDelete) {
        this.connections.delete(sessionId)
      }
    }, 60000) // 每分钟检查一次
  }

  stopCleanup() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval)
      this.cleanupInterval = null
    }
  }
}

// 单例实例
const wsManager = new WebSocketManager()

// 启动清理任务
wsManager.startCleanup()

// 使用共享 WebSocket 的 hook - 兼容旧的 useWebSocket 接口
export function useSharedWebSocket(sessionId: string | null) {
  const [status, setStatus] = useState<'connecting' | 'connected' | 'disconnected' | 'error'>('disconnected')
  const [lastMessage, setLastMessage] = useState<ServerMessage | null>(null)
  const isMounted = useRef(true)

  const send = useCallback((message: Record<string, unknown>) => {
    if (!sessionId) return false
    return wsManager.send(sessionId, message)
  }, [sessionId])

  const clearLastMessage = useCallback(() => {
    setLastMessage(null)
  }, [])

  const disconnect = useCallback(() => {
    if (sessionId) {
      wsManager.disconnect(sessionId)
    }
  }, [sessionId])

  useEffect(() => {
    isMounted.current = true

    if (sessionId) {
      // 订阅消息
      const unsubscribe = wsManager.onMessage(sessionId, (msg) => {
        if (!isMounted.current) return
        if (msg.type === 'pong') return
        setLastMessage(msg)
      })

      // 监听连接状态
      const statusInterval = setInterval(() => {
        const conn = wsManager.getConnection(sessionId)
        if (conn) {
          setStatus(conn.status)
        }
      }, 100)

      return () => {
        unsubscribe()
        clearInterval(statusInterval)
        isMounted.current = false
      }
    } else {
      setStatus('disconnected')
    }
  }, [sessionId])

  return {
    status,
    lastMessage,
    clearLastMessage,
    send,
    disconnect,
    connect: () => {}, // 共享管理器自动连接
  }
}


// 全局状态 hook - 使用共享 WebSocket
export function useGlobalStatus() {
  const updateSessionStatus = useSessionStore((state) => state.updateSessionStatus)
  const clearStaleSessionStatuses = useSessionStore((state) => state.clearStaleSessionStatuses)
  const sessionStatuses = useSessionStore((state) => state.sessionStatuses)
  const sessionStatusTimestamps = useSessionStore((state) => state.sessionStatusTimestamps)
  const serverUrl = useAuthStore((state) => state.serverUrl)
  const isHydrated = useAuthStore((state) => state.isHydrated)
  const subscribedRef = useRef<Set<string>>(new Set())
  const unsubscribesRef = useRef<Map<string, () => void>>(new Map())
  const prevServerUrlRef = useRef<string>('')
  const lastSubscribeTimeRef = useRef<number>(0)
  const idleTimersRef = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map())

  // 检查并清除过期的 completed 状态（1 分钟后自动变为 idle）
  const checkAndClearCompletedStatus = useCallback(() => {
    const now = Date.now()
    const completedTimeout = 60 * 1000 // 1 分钟

    for (const [sessionId, status] of Object.entries(sessionStatuses)) {
      if (status === 'completed') {
        const timestamp = sessionStatusTimestamps[sessionId] || 0
        if (now - timestamp > completedTimeout) {
          console.log(`[GlobalStatus] Clearing completed status for ${sessionId}`)
          updateSessionStatus(sessionId, 'idle')
        }
      }
    }
  }, [sessionStatuses, sessionStatusTimestamps, updateSessionStatus])

  // 获取所有会话并订阅
  const subscribeAllSessions = useCallback(async () => {
    if (!isHydrated || !serverUrl) {
      console.log('[GlobalStatus] Not ready:', { isHydrated, serverUrl: !!serverUrl })
      return
    }

    // 如果服务器 URL 变化，清除之前的订阅
    if (prevServerUrlRef.current && prevServerUrlRef.current !== serverUrl) {
      console.log('[GlobalStatus] Server URL changed, clearing subscriptions')
      // 取消所有旧的订阅
      for (const [sid, unsub] of unsubscribesRef.current) {
        unsub()
      }
      unsubscribesRef.current.clear()
      subscribedRef.current.clear()
    }
    prevServerUrlRef.current = serverUrl

    // 限制订阅频率，避免频繁重连
    const now = Date.now()
    if (now - lastSubscribeTimeRef.current < 5000) {
      return
    }
    lastSubscribeTimeRef.current = now

    try {
      const sessions = await apiClient.getSessions()
      console.log(`[GlobalStatus] Found ${sessions?.length || 0} sessions`)

      for (const session of sessions || []) {
        if (session?.id && !subscribedRef.current.has(session.id)) {
          subscribedRef.current.add(session.id)
          console.log(`[GlobalStatus] Subscribing to session: ${session.id}`)

          // 使用共享管理器订阅状态消息，保存取消订阅函数
          const unsubscribe = wsManager.onMessage(session.id, (msg) => {
            console.log(`[GlobalStatus] Received message for ${session.id}:`, msg.type, msg.state)

            if (msg.type === 'status' && msg.state) {
              const workingStates = ['thinking', 'tool_executing', 'streaming', 'permission_pending']
              const newState = msg.state

              // 如果收到工作状态，立即更新并清除待处理的 idle 定时器
              if (workingStates.includes(newState)) {
                const timer = idleTimersRef.current.get(session.id)
                if (timer) {
                  clearTimeout(timer)
                  idleTimersRef.current.delete(session.id)
                }
                updateSessionStatus(session.id, newState as any)
              } else if (newState === 'idle') {
                // 如果当前是工作状态，延迟 2 秒再切换到 idle
                const currentStatuses = useSessionStore.getState().sessionStatuses
                const currentStatus = currentStatuses[session.id]
                if (workingStates.includes(currentStatus)) {
                  // 清除之前的定时器
                  const existingTimer = idleTimersRef.current.get(session.id)
                  if (existingTimer) {
                    clearTimeout(existingTimer)
                  }
                  // 设置新的延迟更新
                  const timer = setTimeout(() => {
                    updateSessionStatus(session.id, 'idle')
                    idleTimersRef.current.delete(session.id)
                  }, 2000)
                  idleTimersRef.current.set(session.id, timer)
                } else {
                  // 当前不是工作状态，直接更新
                  updateSessionStatus(session.id, 'idle')
                }
              } else if (newState === 'completed') {
                // completed 状态直接更新
                const timer = idleTimersRef.current.get(session.id)
                if (timer) {
                  clearTimeout(timer)
                  idleTimersRef.current.delete(session.id)
                }
                updateSessionStatus(session.id, 'completed')
              }
            } else if (msg.type === 'permission_request') {
              const timer = idleTimersRef.current.get(session.id)
              if (timer) {
                clearTimeout(timer)
                idleTimersRef.current.delete(session.id)
              }
              updateSessionStatus(session.id, 'permission_pending')
            } else if (msg.type === 'message_complete') {
              // 消息完成时设置为 completed 状态，1 分钟后自动变为 idle
              const timer = idleTimersRef.current.get(session.id)
              if (timer) {
                clearTimeout(timer)
                idleTimersRef.current.delete(session.id)
              }
              updateSessionStatus(session.id, 'completed')
            }
          })
          unsubscribesRef.current.set(session.id, unsubscribe)

          // 连接建立后请求当前状态（仅一次，不使用重试）
          wsManager.send(session.id, { type: 'get_status' })
        }
      }
    } catch (e) {
      console.error('[GlobalStatus] Failed to get sessions:', e)
    }
  }, [updateSessionStatus, isHydrated, serverUrl])

  useEffect(() => {
    // 重置订阅当服务器 URL 变化
    if (serverUrl) {
      subscribedRef.current.clear()
    }

    // 立即订阅所有会话
    subscribeAllSessions()

    // 每 10 秒检查新会话（降低频率，减少状态更新冲突）
    const interval = setInterval(() => {
      subscribeAllSessions()
    }, 10000)

    // 定期清理过期状态（包括 completed 状态）
    const statusCleanupInterval = setInterval(() => {
      clearStaleSessionStatuses()
      checkAndClearCompletedStatus()
    }, 5000)

    return () => {
      clearInterval(interval)
      clearInterval(statusCleanupInterval)
      // 清除所有 idle 定时器
      for (const timer of idleTimersRef.current.values()) {
        clearTimeout(timer)
      }
      idleTimersRef.current.clear()
      // 取消所有 WebSocket 消息订阅，防止处理器累积
      for (const [sid, unsub] of unsubscribesRef.current) {
        unsub()
      }
      unsubscribesRef.current.clear()
      subscribedRef.current.clear()
    }
  }, [subscribeAllSessions, clearStaleSessionStatuses, checkAndClearCompletedStatus, serverUrl])

  return {}
}
