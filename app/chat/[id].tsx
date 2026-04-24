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
  Animated,
} from 'react-native'
import { useLocalSearchParams, Stack, useNavigation } from 'expo-router'
import { useSessionStore } from '@/stores/sessionStore'
import { useSharedWebSocket } from '@/hooks/useSharedWebSocket'
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
    sessionStatuses,
    sessions,
    fetchSessions,
    updateSessionTitle,
    isLoading,
  } = useSessionStore()

  const session = sessions.find((s): s is NonNullable<typeof s> => s?.id === id)

  // 从保存的状态中读取当前会话状态，进入页面时立即显示
  const getInitialStatus = useCallback(() => {
    if (id && sessionStatuses[id]) {
      return sessionStatuses[id]
    }
    return 'idle'
  }, [id, sessionStatuses])

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

  // 进入页面时，立即从保存的状态恢复
  useEffect(() => {
    const savedStatus = getInitialStatus()
    if (savedStatus !== 'idle') {
      setChatStatus(savedStatus)

      // 设置超时：如果 30 秒内没有收到任何消息，才认为是连接断开
      // 给予足够长的时间让 WebSocket 重连并继续接收消息
      statusCheckTimeoutRef.current = setTimeout(() => {
        // 只有当 WebSocket 状态不是 connected 时才清除状态
        // 这意味着如果 WebSocket 仍然连接中，不要错误地清除状态
        if (status !== 'connected') {
          setChatStatus('idle')
          if (id) updateSessionStatus(id, 'idle')
        }
      }, 30000) // 30 秒超时
    }

    return () => {
      if (statusCheckTimeoutRef.current) {
        clearTimeout(statusCheckTimeoutRef.current)
        statusCheckTimeoutRef.current = null
      }
    }
  }, [id, getInitialStatus, updateSessionStatus, status])

  const flatListRef = useRef<FlatList>(null)
  const processedIds = useRef(new Set<string>())
  const addedMessageContents = useRef(new Set<string>()) // 使用内容去重
  const [showScrollToBottom, setShowScrollToBottom] = useState(false)
  const statusCheckTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  // 状态点闪烁动画
  const dotOpacity = useRef(new Animated.Value(1)).current

  useEffect(() => {
    if (chatStatus !== 'idle') {
      // 创建闪烁动画
      const animation = Animated.loop(
        Animated.sequence([
          Animated.timing(dotOpacity, {
            toValue: 0.3,
            duration: 500,
            useNativeDriver: true,
          }),
          Animated.timing(dotOpacity, {
            toValue: 1,
            duration: 500,
            useNativeDriver: true,
          }),
        ])
      )
      animation.start()
      return () => animation.stop()
    } else {
      dotOpacity.setValue(1)
    }
  }, [chatStatus, dotOpacity])

  // Track stream state for pairing tool_use with tool_result
  const streamStateRef = useRef<StreamState>({
    textBuffer: '',
    thinkingBuffer: '',
    inTextBlock: false,
    inThinkingBlock: false,
    pendingToolUseIds: new Set(),
  })

  const { status, lastMessage, clearLastMessage, send } = useSharedWebSocket(id)

  // Fetch messages on mount
  useEffect(() => {
    if (id) {
      fetchMessages(id)
    }
  }, [id, fetchMessages])

  // Update session status when chatStatus changes
  useEffect(() => {
    if (id) {
      updateSessionStatus(id, chatStatus)
    }
  }, [id, chatStatus, updateSessionStatus])

  // Handle WebSocket messages
  useEffect(() => {
    if (!lastMessage) return

    // 使用消息类型+时间戳作为去重键，避免 JSON.stringify
    const msgId = `${lastMessage.type}-${lastMessage.timestamp || Date.now()}`
    if (processedIds.current.has(msgId)) {
      clearLastMessage()
      return
    }
    processedIds.current.add(msgId)
    // 限制缓存大小
    if (processedIds.current.size > 200) {
      const arr = Array.from(processedIds.current)
      processedIds.current = new Set(arr.slice(-100))
    }

    const streamState = streamStateRef.current

    switch (lastMessage.type) {
      case 'connected':
        break

      case 'content_start': {
        // 收到内容开始，清除超时检查
        if (statusCheckTimeoutRef.current) {
          clearTimeout(statusCheckTimeoutRef.current)
          statusCheckTimeoutRef.current = null
        }
        if (lastMessage.blockType === 'text') {
          streamState.inTextBlock = true
          streamState.textBuffer = ''
          setStreamingText('')
        }
        break
      }

      case 'content_delta': {
        // 收到内容增量，清除超时检查
        if (statusCheckTimeoutRef.current) {
          clearTimeout(statusCheckTimeoutRef.current)
          statusCheckTimeoutRef.current = null
        }
        if (lastMessage.text) {
          streamState.textBuffer += lastMessage.text
          setStreamingText(streamState.textBuffer)
        }
        break
      }

      case 'thinking': {
        // 收到思考内容，清除超时检查
        if (statusCheckTimeoutRef.current) {
          clearTimeout(statusCheckTimeoutRef.current)
          statusCheckTimeoutRef.current = null
        }
        if (!streamState.inThinkingBlock) {
          streamState.inThinkingBlock = true
          streamState.thinkingBuffer = ''
        }
        streamState.thinkingBuffer += lastMessage.text
        setStreamingThinking(streamState.thinkingBuffer)
        break
      }

      case 'tool_use_complete': {
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
        // 收到完成消息，清除超时检查
        if (statusCheckTimeoutRef.current) {
          clearTimeout(statusCheckTimeoutRef.current)
          statusCheckTimeoutRef.current = null
        }
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
        // 收到状态更新，清除超时检查
        if (statusCheckTimeoutRef.current) {
          clearTimeout(statusCheckTimeoutRef.current)
          statusCheckTimeoutRef.current = null
        }
        // 如果消息包含 sessionId，更新对应会话的状态
        if (lastMessage.sessionId && lastMessage.state) {
          updateSessionStatus(lastMessage.sessionId, lastMessage.state as any)
          // 如果是当前会话，也更新本地状态
          if (lastMessage.sessionId === id) {
            setChatStatus(lastMessage.state as any)
          }
        } else if (lastMessage.state) {
          // 兼容旧格式：没有 sessionId，更新当前会话
          setChatStatus(lastMessage.state as any)
        }
        if (lastMessage.verb) {
          setStatusVerb(lastMessage.verb)
        }
        break
      }

      case 'user_message_echo':
        if (id && lastMessage.content) {
          // 使用内容去重（避免本地发送和 echo 重复）
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
        if (lastMessage.sessionId && lastMessage.title) {
          updateSessionTitle(lastMessage.sessionId, lastMessage.title)
        }
        break
      }

      case 'error':
        streamState.textBuffer = ''
        streamState.thinkingBuffer = ''
        streamState.inTextBlock = false
        streamState.inThinkingBlock = false
        setStreamingText('')
        setStreamingThinking('')
        setChatStatus('idle')
        break
    }

    clearLastMessage()
  }, [lastMessage, id, addMessage, updateMessage, clearLastMessage, updateSessionTitle])

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

  // 自定义标题组件（包含标题和状态）
  const HeaderTitle = useCallback(() => (
    <View style={styles.headerContent}>
      <Text style={[styles.headerTitle, { color: colors.text }]} numberOfLines={1}>
        {session?.title || '对话'}
      </Text>
      <View style={styles.statusRow}>
        <View style={styles.statusSpacer} />
        {chatStatus !== 'idle' && (
          <Animated.View style={[
            styles.statusDot,
            { backgroundColor: '#22c55e', opacity: dotOpacity }
          ]} />
        )}
        <Text style={[
          styles.statusText,
          { color: chatStatus !== 'idle' ? '#22c55e' : colors.textTertiary }
        ]}>
          {chatStatus !== 'idle' ? '工作中' : '等待中'}
        </Text>
        <View style={styles.statusSpacer} />
      </View>
    </View>
  ), [session?.title, chatStatus, colors, dotOpacity])

  return (
    <>
      <Stack.Screen
        options={{
          headerTitle: HeaderTitle,
          headerBackTitle: '返回',
          headerTitleAlign: 'center',
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
  headerContent: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '600',
    textAlign: 'center',
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 2,
  },
  statusSpacer: {
    width: 10,
  },
  statusDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    marginRight: 4,
  },
  statusText: {
    fontSize: 11,
    fontWeight: '500',
    textAlign: 'center',
  },
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
