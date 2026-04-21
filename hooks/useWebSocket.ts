import { useEffect, useRef, useCallback, useState } from 'react'
import { useAuthStore } from '@/stores/authStore'

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

  const serverUrl = useAuthStore((state) => state.serverUrl)

  const connect = useCallback(() => {
    if (!sessionId) return

    const wsUrl = serverUrl
      .replace('http://', 'ws://')
      .replace('https://', 'wss://') + `/ws/${sessionId}`

    setStatus('connecting')

    try {
      const ws = new WebSocket(wsUrl)

      ws.onopen = () => {
        setStatus('connected')
        reconnectAttempts.current = 0
      }

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data)
          if (msg.type === 'pong') return
          setLastMessage(msg)
        } catch (e) {
          console.error('Failed to parse WebSocket message:', e)
        }
      }

      ws.onclose = () => {
        setStatus('disconnected')
        scheduleReconnect()
      }

      ws.onerror = () => {
        setStatus('error')
      }

      wsRef.current = ws
    } catch (e) {
      setStatus('error')
      scheduleReconnect()
    }
  }, [sessionId, serverUrl])

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
      wsRef.current.send(JSON.stringify(message))
      return true
    }
    return false
  }, [])

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
    send,
    connect,
    disconnect,
  }
}
