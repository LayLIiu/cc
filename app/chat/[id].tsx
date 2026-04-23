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
import { useLocalSearchParams, Stack, useNavigation } from 'expo-router'
import { useSessionStore } from '@/stores/sessionStore'
import { useWebSocket } from '@/hooks/useWebSocket'
import { MessageBubble } from '@/components/MessageBubble'
import { ChatInput } from '@/components/ChatInput'
import { PermissionDialog } from '@/components/chat/PermissionDialog'
import { useTheme } from '@/utils/theme'
import type { Message } from '@/types/session'

const SCREEN_VERSION = 'v1.1.0 - 02:40'

type StreamState = {
  // Current streaming text content
  textBuffer: string
  // Current thinking text buffer
  thinkingBuffer: string
  // Is currently in a text block
  inTextBlock: boolean
  // Is currently in a thinking block
  inThinkingBlock: boolean
  // Pending tool calls (waiting for result)
  pendingToolUseIds: Set<string>
}

export default function ChatScreen() {
  const { id } = useLocalSearchParams<{ id: string }>()
  const { colors } = useTheme()
  const navigation = useNavigation()

  const {
    messages,
    fetchMessages,
    refreshMessages,
    addMessage,
    updateMessage,
    sessions,
    fetchSessions,
    updateSessionTitle,
    isLoading,
  } = useSessionStore()

  const session = sessions.find((s): s is NonNullable<typeof s> => s?.id === id)

  // Update header title when session title changes
  useEffect(() => {
    const title = session?.title || '对话'
    navigation.setOptions({ headerTitle: title })
  }, [session?.title, navigation])

  // Fetch sessions to get title
  useEffect(() => {
    if (id && sessions.length === 0) {
      fetchSessions()
    }
  }, [id, sessions.length, fetchSessions])

  // Streaming state
  const [streamingText, setStreamingText] = useState('')
  const [streamingThinking, setStreamingThinking] = useState('')
  const [chatStatus, setChatStatus] = useState<'idle' | 'thinking' | 'tool_executing' | 'streaming' | 'permission_pending'>('idle')
  const [statusVerb, setStatusVerb] = useState('')
  const [permissionRequest, setPermissionRequest] = useState<{
    requestId: string
    toolName: string
    input: Record<string, unknown>
    description?: string
  } | null>(null)

  const flatListRef = useRef<FlatList>(null)
  const processedIds = useRef(new Set<string>())

  // Track stream state for pairing tool_use with tool_result
  const streamStateRef = useRef<StreamState>({
    textBuffer: '',
    thinkingBuffer: '',
    inTextBlock: false,
    inThinkingBlock: false,
    pendingToolUseIds: new Set(),
  })

  const { status, lastMessage, clearLastMessage, send } = useWebSocket(id)

  // Fetch messages on mount
  useEffect(() => {
    if (id) {
      fetchMessages(id)
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
    if (processedIds.current.size > 100) {
      processedIds.current = new Set(Array.from(processedIds.current).slice(-60))
    }

    const streamState = streamStateRef.current

    switch (lastMessage.type) {
      case 'connected':
        console.log('[Chat] Connected to session:', id)
        break

      case 'content_start': {
        // A new content block is starting
        if (lastMessage.blockType === 'text') {
          streamState.inTextBlock = true
          streamState.textBuffer = ''
          setStreamingText('')
        }
        // For tool_use blocks, we'll create the tool_use message when tool_use_complete arrives
        break
      }

      case 'content_delta': {
        // Incremental text or tool input
        if (lastMessage.text) {
          streamState.textBuffer += lastMessage.text
          setStreamingText(streamState.textBuffer)
        }
        // toolInput delta is not displayed in real-time (too verbose)
        break
      }

      case 'thinking': {
        // Thinking process incremental text
        if (!streamState.inThinkingBlock) {
          streamState.inThinkingBlock = true
          streamState.thinkingBuffer = ''
        }
        streamState.thinkingBuffer += lastMessage.text
        setStreamingThinking(streamState.thinkingBuffer)
        break
      }

      case 'tool_use_complete': {
        // A tool call has completed - add it as a message
        const toolUseId = lastMessage.toolUseId || `tool-${Date.now()}`
        streamState.pendingToolUseIds.add(toolUseId)

        const toolMsg: Message = {
          id: `ws-tool-${toolUseId}`,
          type: 'tool_use',
          content: '',
          timestamp: String(Date.now()),
          toolName: lastMessage.toolName || 'Unknown',
          toolInput: typeof lastMessage.input === 'object' ? lastMessage.input as Record<string, any> : {},
          toolStatus: 'running',
        }
        if (id) addMessage(id, toolMsg)

        // Clear streaming text since we're now in tool execution
        if (streamState.textBuffer) {
          const textMsg: Message = {
            id: `ws-text-${Date.now()}`,
            type: 'assistant_text',
            content: streamState.textBuffer,
            timestamp: String(Date.now()),
          }
          if (id) addMessage(id, textMsg)
          streamState.textBuffer = ''
          streamState.inTextBlock = false
          setStreamingText('')
        }

        // Clear thinking if we had one
        if (streamState.thinkingBuffer) {
          const thinkMsg: Message = {
            id: `ws-think-${Date.now()}`,
            type: 'thinking',
            content: streamState.thinkingBuffer,
            timestamp: String(Date.now()),
          }
          if (id) addMessage(id, thinkMsg)
          streamState.thinkingBuffer = ''
          streamState.inThinkingBlock = false
          setStreamingThinking('')
        }
        break
      }

      case 'tool_result': {
        // Tool execution result - update the matching tool_use message
        const toolUseId = lastMessage.toolUseId
        if (id && toolUseId) {
          const resultContent = lastMessage.content
            ? (typeof lastMessage.content === 'string'
              ? lastMessage.content
              : Array.isArray(lastMessage.content)
                ? lastMessage.content.map((b: any) => b?.text || '').join('')
                : JSON.stringify(lastMessage.content))
            : ''

          updateMessage(id, `ws-tool-${toolUseId}`, {
            toolResult: resultContent,
            toolStatus: lastMessage.isError ? 'failed' : 'completed',
          })
          streamState.pendingToolUseIds.delete(toolUseId)
        }
        break
      }

      case 'message_complete': {
        // Turn is complete - save any remaining streaming content
        if (streamState.textBuffer) {
          const textMsg: Message = {
            id: `ws-text-${Date.now()}`,
            type: 'assistant_text',
            content: streamState.textBuffer,
            timestamp: String(Date.now()),
          }
          if (id) addMessage(id, textMsg)
        }
        if (streamState.thinkingBuffer) {
          const thinkMsg: Message = {
            id: `ws-think-${Date.now()}`,
            type: 'thinking',
            content: streamState.thinkingBuffer,
            timestamp: String(Date.now()),
          }
          if (id) addMessage(id, thinkMsg)
        }

        // Reset all streaming state
        streamState.textBuffer = ''
        streamState.thinkingBuffer = ''
        streamState.inTextBlock = false
        streamState.inThinkingBlock = false
        setStreamingText('')
        setStreamingThinking('')
        setChatStatus('idle')
        setStatusVerb('')
        break
      }

      case 'status': {
        // Status update (thinking, tool_executing, streaming, idle, permission_pending)
        const state = lastMessage.state as StreamState extends { pendingToolUseIds: any } ? never : string
        if (lastMessage.state) {
          setChatStatus(lastMessage.state as any)
        }
        if (lastMessage.verb) {
          setStatusVerb(lastMessage.verb)
        }
        break
      }

      case 'user_message_echo':
        // User message from another client - only fetch if we have no messages
        console.log('[Chat] Received user_message_echo')
        if (id && (!messages[id!] || messages[id!].length === 0)) {
          fetchMessages(id)
        }
        break

      case 'permission_request': {
        // Show permission dialog for user to approve or deny
        console.log('[Chat] Permission request:', lastMessage.toolName)
        setPermissionRequest({
          requestId: lastMessage.requestId,
          toolName: lastMessage.toolName || 'Unknown',
          input: typeof lastMessage.input === 'object' && lastMessage.input ? lastMessage.input as Record<string, unknown> : {},
          description: lastMessage.description,
        })
        setChatStatus('permission_pending')
        setStatusVerb('等待权限...')
        break
      }

      case 'session_title_updated': {
        // Update session title in store and header
        if (lastMessage.sessionId && lastMessage.title) {
          console.log('[Chat] Session title updated:', lastMessage.title)
          updateSessionTitle(lastMessage.sessionId, lastMessage.title)
        }
        break
      }

      case 'error':
        console.error('[Chat] Server error:', lastMessage.message)
        // Reset streaming state on error
        streamState.textBuffer = ''
        streamState.thinkingBuffer = ''
        streamState.inTextBlock = false
        streamState.inThinkingBlock = false
        setStreamingText('')
        setStreamingThinking('')
        setChatStatus('idle')
        break

      default:
        console.log('[Chat] Unhandled message type:', lastMessage.type)
    }

    clearLastMessage()
  }, [lastMessage, id, addMessage, updateMessage, clearLastMessage, send, messages, updateSessionTitle])

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

    // Reset streaming state
    const streamState = streamStateRef.current
    streamState.textBuffer = ''
    streamState.thinkingBuffer = ''
    streamState.inTextBlock = false
    streamState.inThinkingBlock = false
    setStreamingText('')
    setStreamingThinking('')
    setChatStatus('thinking')
    setStatusVerb('Thinking')

    // Send to server
    send({ type: 'user_message', content: content.trim() })
  }, [id, addMessage, send])

  const handlePermissionAllow = useCallback((requestId: string, always: boolean) => {
    console.log('[Chat] Permission allowed:', requestId, always ? '(always)' : '(once)')
    send({
      type: 'permission_response',
      requestId,
      allowed: true,
      ...(always ? { rule: 'always' } : {}),
    })
    setPermissionRequest(null)
    // Resume previous status
    setChatStatus('thinking')
    setStatusVerb('Thinking')
  }, [send])

  const handlePermissionDeny = useCallback((requestId: string) => {
    console.log('[Chat] Permission denied:', requestId)
    send({
      type: 'permission_response',
      requestId,
      allowed: false,
    })
    setPermissionRequest(null)
    setChatStatus('thinking')
    setStatusVerb('Thinking')
  }, [send])

  const handleRefresh = useCallback(() => {
    if (id) {
      refreshMessages(id)
    }
  }, [id, refreshMessages])

  // Build the complete message list including streaming content
  const allMessages = [
    ...(messages[id!] || []),
    // Add streaming thinking block
    ...(streamingThinking ? [{
      id: 'streaming-thinking',
      type: 'thinking' as const,
      content: streamingThinking,
      timestamp: String(Date.now()),
      isStreaming: true,
    }] : []),
    // Add streaming text
    ...(streamingText ? [{
      id: 'streaming-text',
      type: 'assistant_text' as const,
      content: streamingText,
      timestamp: String(Date.now()),
    }] : []),
  ]

  // Status indicator text
  const statusText = chatStatus !== 'idle' && statusVerb
    ? statusVerb
    : chatStatus === 'thinking' ? '思考中...'
    : chatStatus === 'streaming' ? '生成中...'
    : chatStatus === 'tool_executing' ? '执行工具...'
    : chatStatus === 'permission_pending' ? '等待权限...'
    : ''

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
        {isLoading && allMessages.length === 0 ? (
          <View style={styles.center}>
            <ActivityIndicator size="large" color={colors.primary} />
          </View>
        ) : (
          <>
            {/* Status bar */}
            <View style={[styles.debugBar, { backgroundColor: colors.surface }]}>
              <Text style={[styles.debugText, { color: colors.textSecondary }]}>
                WS: {status} | {allMessages.length} msgs
              </Text>
              {statusText ? (
                <Text style={[styles.statusText, { color: colors.primary }]}>
                  {statusText}
                </Text>
              ) : null}
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
                  refreshing={isLoading}
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

        {/* Permission Dialog */}
        <PermissionDialog
          visible={!!permissionRequest}
          request={permissionRequest}
          onAllow={handlePermissionAllow}
          onDeny={handlePermissionDeny}
        />
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
    gap: 6,
  },
  debugText: {
    fontSize: 10,
  },
  statusText: {
    fontSize: 11,
    fontWeight: '500',
    flex: 1,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  listContent: { padding: 16, paddingBottom: 8 },
})
