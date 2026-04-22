import { useEffect, useState, useCallback, useRef } from 'react'
import {
  View,
  FlatList,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  ActivityIndicator,
  Text,
  RefreshControl,
} from 'react-native'
import { useLocalSearchParams, Stack } from 'expo-router'
import { useSessionStore } from '@/stores/sessionStore'
import { useWebSocket } from '@/hooks/useWebSocket'
import { MessageBubble } from '@/components/MessageBubble'
import { ChatInput } from '@/components/ChatInput'
import { useTheme } from '@/utils/theme'
import type { Message } from '@/types/session'

// 版本信息
const SCREEN_VERSION = 'v1.0.7 - 00:35'

export default function ChatScreen() {
  const { id } = useLocalSearchParams<{ id: string }>()
  const { colors } = useTheme()

  const {
    messages,
    fetchMessages,
    refreshMessages,
    addMessage,
    updateLastAssistantMessage,
    sessions,
    fetchSessions,
    isRefreshing,
  } = useSessionStore()

  // Debug: log sessions and current id
  useEffect(() => {
    console.log('[Chat] Current session id:', id)
    console.log('[Chat] Sessions count:', sessions.length)
    console.log('[Chat] Sessions:', sessions.map(s => ({ id: s?.id, title: s?.title })))
  }, [id, sessions])

  const session = sessions.find((s): s is NonNullable<typeof s> => s?.id === id)

  // Debug: log found session
  useEffect(() => {
    if (session) {
      console.log('[Chat] Found session:', session.id, session.title)
    } else {
      console.log('[Chat] Session not found for id:', id)
    }
  }, [session, id])

  // Fetch sessions to get title
  useEffect(() => {
    if (id && sessions.length === 0) {
      fetchSessions()
    }
  }, [id, sessions.length, fetchSessions])

  const [isLoading, setIsLoading] = useState(false)
  const [streamingText, setStreamingText] = useState('')

  const flatListRef = useRef<FlatList>(null)
  const processedIds = useRef(new Set<string>())
  const currentAssistantId = useRef<string | null>(null)

  const { status, lastMessage, clearLastMessage, send } = useWebSocket(id)

  // Fetch messages on mount
  useEffect(() => {
    if (id) {
      setIsLoading(true)
      fetchMessages(id).finally(() => setIsLoading(false))
    }
  }, [id, fetchMessages])

  // Handle WebSocket messages
  useEffect(() => {
    if (!lastMessage) return

    const msgId = JSON.stringify(lastMessage)
    if (processedIds.current.has(msgId)) {
      clearLastMessage()
      return
    }
    processedIds.current.add(msgId)
    if (processedIds.current.size > 50) {
      processedIds.current = new Set(Array.from(processedIds.current).slice(-30))
    }

    console.log(`[Chat ${SCREEN_VERSION}] WS received:`, lastMessage.type, lastMessage.content?.substring?.(0, 50) || '')

    switch (lastMessage.type) {
      case 'connected':
        // Connection established, refresh messages to sync
        console.log('[Chat] Connected, refreshing messages for session:', id)
        if (id) {
          refreshMessages(id)
        }
        break

      case 'content_delta':
        if (lastMessage.text) {
          setStreamingText(prev => prev + lastMessage.text)
        }
        break

      case 'message_complete':
        // Save the complete assistant message
        const content = lastMessage.content || streamingText
        if (content) {
          const assistantMsg: Message = {
            id: lastMessage.id || `assistant-${Date.now()}`,
            type: 'assistant_text',
            content: typeof content === 'string' ? content : '',
            timestamp: String(Date.now()),
          }
          addMessage(id!, assistantMsg)
          setStreamingText('')
        }
        break

      case 'user_message_echo':
        // User message from another client - refresh to get full history
        console.log('[Chat] Received user_message_echo, refreshing messages')
        if (id) {
          refreshMessages(id)
        }
        break

      case 'assistant_text':
        // Full assistant message (from another client or history)
        if (lastMessage.content && id) {
          const assistantMsg: Message = {
            id: lastMessage.id || `assistant-${Date.now()}`,
            type: 'assistant_text',
            content: lastMessage.content,
            timestamp: lastMessage.timestamp || String(Date.now()),
          }
          addMessage(id, assistantMsg)
        }
        break

      case 'status':
        // Status update (thinking, idle, etc.)
        console.log('[Chat] Status:', lastMessage.state)
        break

      case 'error':
        console.error('[Chat] Server error:', lastMessage.message)
        break

      default:
        console.log('[Chat] Unknown message type:', lastMessage.type)
    }

    clearLastMessage()
  }, [lastMessage, id, addMessage, streamingText, clearLastMessage, refreshMessages])

  const handleSend = useCallback((content: string) => {
    if (!content.trim()) return

    // Add user message locally
    const userMsg: Message = {
      id: `user-${Date.now()}`,
      type: 'user_text',
      content: content.trim(),
      timestamp: String(Date.now()),
    }
    addMessage(id!, userMsg)

    // Send to server
    send({ type: 'user_message', content: content.trim() })
    setStreamingText('')
  }, [id, addMessage, send])

  const handleRefresh = useCallback(() => {
    if (id) {
      refreshMessages(id)
    }
  }, [id, refreshMessages])

  // Combine stored messages with streaming text
  const allMessages = [
    ...(messages[id!] || []),
    ...(streamingText ? [{
      id: 'streaming',
      type: 'assistant_text' as const,
      content: streamingText,
      timestamp: String(Date.now()),
    }] : []),
  ]

  return (
    <>
      <Stack.Screen
        options={{
          title: session?.title || '对话',
          headerBackTitle: '返回',
        }}
      />
      <KeyboardAvoidingView
        style={[styles.container, { backgroundColor: colors.background }]}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={100}
      >
        {isLoading ? (
          <View style={styles.center}>
            <ActivityIndicator size="large" color={colors.primary} />
          </View>
        ) : (
          <>
            {/* Debug info bar */}
            <View style={[styles.debugBar, { backgroundColor: colors.surface }]}>
              <Text style={[styles.debugText, { color: colors.textSecondary }]}>
                {SCREEN_VERSION} | WS: {status} | {allMessages.length} msgs
              </Text>
              <View style={[styles.statusDot, { backgroundColor: status === 'connected' ? '#22c55e' : '#ef4444' }]} />
            </View>

            <FlatList
              ref={flatListRef}
              data={allMessages}
              keyExtractor={(item) => item.id}
              renderItem={({ item, index }) => (
                <MessageBubble
                  message={item}
                  isLast={index === allMessages.length - 1}
                />
              )}
              contentContainerStyle={styles.listContent}
              onContentSizeChange={() => flatListRef.current?.scrollToEnd({ animated: false })}
              refreshControl={
                <RefreshControl
                  refreshing={isRefreshing}
                  onRefresh={handleRefresh}
                  tintColor={colors.primary}
                  colors={[colors.primary]}
                />
              }
            />

            <ChatInput
              onSend={handleSend}
              placeholder="发送消息..."
            />
          </>
        )}
      </KeyboardAvoidingView>
    </>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  debugBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 4,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(150, 150, 150, 0.2)',
  },
  debugText: {
    fontSize: 10,
    marginRight: 6,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  listContent: { padding: 16, paddingBottom: 8 },
})
