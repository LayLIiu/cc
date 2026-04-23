import { useEffect, useState, useCallback, useRef, useMemo } from 'react'
import {
  View,
  FlatList,
  StyleSheet,
  Platform,
  KeyboardAvoidingView,
  ActivityIndicator,
  Text,
  TouchableOpacity,
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
    addMessage,
    updateMessage,
    updateSessionStatus,
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
  const addedMessageContents = useRef(new Set<string>())
  const [showScrollToBottom, setShowScrollToBottom] = useState(false)

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

  // Update session status when chatStatus changes
  useEffect(() => {
    if (id) {
      console.log('[Chat] Updating session status:', id, chatStatus)
      updateSessionStatus(id, chatStatus)
    }
  }, [id, chatStatus, updateSessionStatus])

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
        // User message from another client - add it to messages
        console.log('[Chat] Received user_message_echo')
        if (id && lastMessage.content) {
          // Check if message already exists (avoid duplicate from local send)
          const contentKey = `user-${lastMessage.content}`
          if (!addedMessageContents.current.has(contentKey)) {
            addedMessageContents.current.add(contentKey)
            const echoMsg: Message = {
              id: lastMessage.id || `user-echo-${Date.now()}`,
              type: 'user_text',
              content: lastMessage.content,
              timestamp: lastMessage.timestamp || String(Date.now()),
            }
            addMessage(id, echoMsg)
          }
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
  }, [lastMessage, id, addMessage, updateMessage, clearLastMessage, send, updateSessionTitle])

  const handleSend = useCallback((content: string) => {
    if (!content.trim()) return

    const trimmedContent = content.trim()

    // Add user message locally
    const userMsg: Message = {
      id: `user-${Date.now()}`,
      type: 'user_text',
      content: trimmedContent,
      timestamp: String(Date.now()),
    }
    addMessage(id!, userMsg)

    // Mark this content as added to avoid duplicate from echo
    addedMessageContents.current.add(`user-${trimmedContent}`)

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
    send({ type: 'user_message', content: trimmedContent })
  }, [id, addMessage, send])

  const handleStop = useCallback(() => {
    console.log('[Chat] Stopping AI response')
    // Send stop message to server
    send({ type: 'stop' })
    // Reset streaming state
    const streamState = streamStateRef.current
    streamState.textBuffer = ''
    streamState.thinkingBuffer = ''
    streamState.inTextBlock = false
    streamState.inThinkingBlock = false
    setStreamingText('')
    setStreamingThinking('')
    setChatStatus('idle')
    setStatusVerb('')
  }, [send])

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

  // Handle scroll to show/hide scroll-to-bottom button
  const handleScroll = useCallback(({ nativeEvent }) => {
    // In inverted list, offset > 50 means user scrolled away from latest
    const isNearLatest = nativeEvent.contentOffset.y < 50
    setShowScrollToBottom(!isNearLatest)
  }, [])

  // 使用 useMemo 缓存消息列表，减少重新计算
  const allMessages = useMemo(() => {
    const historical = messages[id!] || []
    return [
      // Streaming content goes first (will appear at bottom in inverted list)
      ...(streamingText ? [{
        id: 'streaming-text',
        type: 'assistant_text' as const,
        content: streamingText,
        timestamp: String(Date.now()),
      }] : []),
      ...(streamingThinking ? [{
        id: 'streaming-thinking',
        type: 'thinking' as const,
        content: streamingThinking,
        timestamp: String(Date.now()),
        isStreaming: true,
      }] : []),
      // Historical messages in reverse order
      ...historical.slice().reverse(),
    ]
  }, [messages[id], streamingText, streamingThinking])

  // 使用 useCallback 缓存 renderItem
  const renderMessage = useCallback(({ item, index }: { item: any; index: number }) => (
    <MessageBubble
      message={item}
      isLast={index === allMessages.length - 1}
    />
  ), [allMessages.length])

  // Scroll to latest message (bottom of inverted list = index 0)
  const scrollToLatest = useCallback(() => {
    if (flatListRef.current) {
      flatListRef.current.scrollToIndex({ index: 0, animated: true })
    }
  }, [])

  const content = (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      {isLoading && allMessages.length === 0 ? (
        <View style={styles.center}>
          <ActivityIndicator size="large" color={colors.primary} />
        </View>
      ) : (
        <>
          <FlatList
            ref={flatListRef}
            data={allMessages}
            inverted
            keyExtractor={(item) => item.id}
            renderItem={renderMessage}
            contentContainerStyle={[styles.listContent, { backgroundColor: colors.background }]}
            onScroll={handleScroll}
            scrollEventThrottle={100}
            removeClippedSubviews={true}
            maxToRenderPerBatch={10}
            windowSize={5}
            keyboardDismissMode="interactive"
            keyboardShouldPersistTaps="handled"
          />

          {/* Scroll to latest button */}
          {showScrollToBottom && (
            <TouchableOpacity
              style={[styles.scrollToBottom, { backgroundColor: colors.surface, borderColor: colors.border }]}
              onPress={scrollToLatest}
              activeOpacity={0.7}
            >
              <Text style={[styles.scrollToBottomText, { color: colors.primary }]}>↓ 最新</Text>
            </TouchableOpacity>
          )}

          <ChatInput
            onSend={handleSend}
            onStop={handleStop}
            placeholder="发送消息..."
            chatStatus={chatStatus}
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
    </View>
  )

  return (
    <>
      <Stack.Screen
        options={{
          title: session?.title || '对话',
          headerBackTitle: '返回',
        }}
      />
      {Platform.OS === 'ios' ? (
        <KeyboardAvoidingView
          style={styles.container}
          behavior="padding"
          keyboardVerticalOffset={90}
        >
          {content}
        </KeyboardAvoidingView>
      ) : (
        content
      )}
    </>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  listContent: { padding: 16, paddingBottom: 8 },
  scrollToBottom: {
    position: 'absolute',
    bottom: 80,
    right: 16,
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    borderWidth: 1,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 3,
  },
  scrollToBottomText: {
    fontSize: 14,
    fontWeight: '600',
  },
})
