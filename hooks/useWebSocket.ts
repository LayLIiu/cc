import { useEffect, useRef, useCallback, useState } from 'react'
import { useAuthStore } from '@/stores/authStore'

// WebSocket Hook 版本
const WS_VERSION = 'v1.0.3'

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

  const serverUrl = useAuthStore((state) => state.serverUrl)

  const processQueue = useCallback(() => {
    if (isProcessing.current || messageQueue.current.length === 0) return

    isProcessing.current = true
    const msg = messageQueue.current.shift()
    if (msg) {
      console.log('WebSocket processing:', msg.type, msg.type === 'user_message_echo' ? '(user_message_echo)' : '')
      setLastMessage(msg)
    }
  }, [])

  const connect = useCallback(() => {
    if (!sessionId) return

    const wsUrl = serverUrl
      .replace('http://', 'ws://')
      .replace('https://', 'wss://') + `/ws/${sessionId}`

    console.log(`[WebSocket ${WS_VERSION}] Connecting to:`, wsUrl)
    console.log(`[WebSocket ${WS_VERSION}] SessionId:`, sessionId)
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
        setStatus('disconnected')
        scheduleReconnect()
      }

      ws.onerror = (error) => {
        console.error('[WebSocket] Error:', error)
        setStatus('error')
      }

      wsRef.current = ws
    } catch (e) {
      console.error('[WebSocket] Connection failed:', e)
      setStatus('error')
      scheduleReconnect()
    }
  }, [sessionId, serverUrl, processQueue])

  const scheduleReconnect = useCallback(() => {
    if (reconnectAttempts.current >= 5) return

    reconnectAttempts.current++
    const delay = Math.min(1000 * Math.pow(2, reconnectAttempts.current - 1), 30000)

    reconnectTimer.current = setTimeout(() => {
      connect()
    }, delay)
  }, [connect])

  const disconnect = useCallback(() => {
    if (reconnectTimer.current) {
      clearTimeout(reconnectTimer.current)
    }
    wsRef.current?.close()
    wsRef.current = null
    setStatus('disconnected')
  }, [])

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
    if (sessionId) {
      connect()
    }
    return () => {
      disconnect()
    }
  }, [sessionId, connect, disconnect])

  return {
    status,
    lastMessage,
    clearLastMessage,
    send,
    connect,
    disconnect,
  }
}
