import { useEffect, useRef, useCallback, useState } from 'react'
import { useAuthStore } from '@/stores/authStore'

// WebSocket Hook 版本
const WS_VERSION = 'v1.0.4'

type WebSocketStatus = 'connecting' | 'connected' | 'disconnected' | 'error'

type ServerMessage = {
  type: string
  [key: string]: any
}

export function useWebSocket(sessionId: string | null) {
  const [status, setStatus] = useState<WebSocketStatus>('disconnected')
  const [lastMessage, setLastMessage] = useState<ServerMessage | null>(null)

  const wsRef = useRef<WebSocket | null>(null)
  const reconnectAttempts = useRef(0)
  const reconnectTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const messageQueue = useRef<ServerMessage[]>([])
  const isProcessing = useRef(false)
  const isClosedByUser = useRef(false)

  const serverUrl = useAuthStore((state) => state.serverUrl)
  const isHydrated = useAuthStore((state) => state.isHydrated)

  const processQueue = useCallback(() => {
    if (isProcessing.current || messageQueue.current.length === 0) return

    isProcessing.current = true
    const msg = messageQueue.current.shift()
    if (msg) {
      console.log('WebSocket processing:', msg.type, msg.type === 'user_message_echo' ? '(user_message_echo)' : '')
      setLastMessage(msg)
    }
  }, [])

  // 清理旧 WebSocket 连接，防止连接泄漏
  const cleanupWs = useCallback(() => {
    const ws = wsRef.current
    if (ws) {
      // 移除事件处理器，防止 onclose 触发重连
      ws.onopen = null
      ws.onmessage = null
      ws.onclose = null
      ws.onerror = null
      if (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING) {
        try {
          ws.close()
        } catch (e) {
          // 忽略关闭时的错误
        }
      }
      wsRef.current = null
    }
  }, [])

  const connect = useCallback(() => {
    if (!sessionId) return

    // 等待 store rehydrate 完成，避免用默认值连接
    if (!isHydrated) {
      console.log(`[WebSocket ${WS_VERSION}] Waiting for store rehydration...`)
      return
    }

    // 校验 serverUrl 有效性
    if (!serverUrl || (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://'))) {
      console.warn(`[WebSocket ${WS_VERSION}] Invalid serverUrl:`, serverUrl)
      return
    }

    // 如果已经在连接或已连接，不重复创建
    const currentWs = wsRef.current
    if (currentWs && (currentWs.readyState === WebSocket.OPEN || currentWs.readyState === WebSocket.CONNECTING)) {
      console.log(`[WebSocket ${WS_VERSION}] Already connected or connecting, skip`)
      return
    }

    const wsUrl = serverUrl
      .replace('http://', 'ws://')
      .replace('https://', 'wss://') + `/ws/${sessionId}`

    console.log(`[WebSocket ${WS_VERSION}] Connecting to:`, wsUrl)
    console.log(`[WebSocket ${WS_VERSION}] SessionId:`, sessionId)
    isClosedByUser.current = false

    // 清理旧连接
    cleanupWs()

    setStatus('connecting')

    try {
      const ws = new WebSocket(wsUrl)

      ws.onopen = () => {
        console.log('[WebSocket] Connected')
        setStatus('connected')
        reconnectAttempts.current = 0
      }

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data)
          if (msg.type === 'pong') return

          console.log('[WebSocket] Received:', msg.type)

          // Add to queue and process
          messageQueue.current.push(msg)
          processQueue()
        } catch (e) {
          console.error('[WebSocket] Parse error:', e)
        }
      }

      ws.onclose = (event) => {
        console.log('[WebSocket] Disconnected:', event.code, event.reason)
        wsRef.current = null
        if (!isClosedByUser.current) {
          setStatus('disconnected')
          scheduleReconnect()
        }
      }

      ws.onerror = (error) => {
        console.error('[WebSocket] Error:', error)
        // onerror 之后通常会触发 onclose，但某些平台可能不会
        // 先设 error 状态，在 onclose 中处理重连
        setStatus('error')
      }

      wsRef.current = ws
    } catch (e) {
      console.error('[WebSocket] Connection failed:', e)
      setStatus('error')
      scheduleReconnect()
    }
  }, [sessionId, serverUrl, isHydrated, processQueue, cleanupWs])

  const scheduleReconnect = useCallback(() => {
    if (reconnectAttempts.current >= 5) {
      console.log(`[WebSocket ${WS_VERSION}] Max reconnect attempts reached`)
      return
    }

    reconnectAttempts.current++
    const delay = Math.min(1000 * Math.pow(2, reconnectAttempts.current - 1), 30000)
    console.log(`[WebSocket ${WS_VERSION}] Reconnecting in ${delay}ms (attempt ${reconnectAttempts.current}/5)`)

    reconnectTimer.current = setTimeout(() => {
      connect()
    }, delay)
  }, [connect])

  const disconnect = useCallback(() => {
    isClosedByUser.current = true
    if (reconnectTimer.current) {
      clearTimeout(reconnectTimer.current)
      reconnectTimer.current = null
    }
    cleanupWs()
    reconnectAttempts.current = 0
    setStatus('disconnected')
  }, [cleanupWs])

  const send = useCallback((message: Record<string, unknown>) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      console.log('[WebSocket] Sending:', message.type)
      wsRef.current.send(JSON.stringify(message))
      return true
    }
    console.log('[WebSocket] Cannot send, not connected')
    return false
  }, [])

  // Clear last message after it's been processed - allows next message to be processed
  const clearLastMessage = useCallback(() => {
    setLastMessage(null)
    isProcessing.current = false
    // Process next message in queue
    setTimeout(processQueue, 0)
  }, [processQueue])

  useEffect(() => {
    if (sessionId && isHydrated) {
      connect()
    }
    return () => {
      disconnect()
    }
  }, [sessionId, serverUrl, isHydrated, connect, disconnect])

  return {
    status,
    lastMessage,
    clearLastMessage,
    send,
    connect,
    disconnect,
  }
}
