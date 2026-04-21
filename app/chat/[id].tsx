import { useEffect, useState, useCallback, useRef } from 'react'
import {
  View,
  FlatList,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  ActivityIndicator,
  Text,
} from 'react-native'
import { useLocalSearchParams, useRouter, Stack } from 'expo-router'
import { useSessionStore } from '@/stores/sessionStore'
import { useWebSocket } from '@/hooks/useWebSocket'
import { MessageBubble } from '@/components/MessageBubble'
import { ChatInput } from '@/components/ChatInput'
import { useTheme } from '@/utils/theme'
import type { Message } from '@/types/session'

type ChatState = 'idle' | 'thinking' | 'streaming' | 'tool_executing'

export default function ChatScreen() {
  const { id } = useLocalSearchParams<{ id: string }>()
  const router = useRouter()
  const { colors } = useTheme()

  const { messages, fetchMessages, addMessage, sessions } = useSessionStore()
  const session = sessions.find(s => s.id === id)

  const [chatState, setChatState] = useState<ChatState>('idle')
  const [streamingText, setStreamingText] = useState('')
  const [streamingMessages, setStreamingMessages] = useState<Message[]>([])

  const flatListRef = useRef<FlatList>(null)

  const { status, lastMessage, send } = useWebSocket(id)

  // Fetch messages on mount
  useEffect(() => {
    if (id) {
      fetchMessages(id)
    }
  }, [id, fetchMessages])

  // Handle WebSocket messages
  useEffect(() => {
    if (!lastMessage) return

    switch (lastMessage.type) {
      case 'status':
        setChatState(lastMessage.state)
        if (lastMessage.state === 'idle') {
          setStreamingText('')
          setStreamingMessages([])
        }
        break

      case 'content_delta':
        if (lastMessage.text) {
          setStreamingText(prev => prev + lastMessage.text)
        }
        break

      case 'content_start':
        if (lastMessage.blockType === 'text') {
          setStreamingText('')
        }
        break

      case 'tool_use_complete':
        const toolMsg: Message = {
          id: `tool-${Date.now()}`,
          type: 'tool_use',
          content: {
            name: lastMessage.toolName,
            input: lastMessage.input,
          },
          timestamp: new Date().toISOString(),
        }
        setStreamingMessages(prev => [...prev, toolMsg])
        break

      case 'tool_result':
        const resultMsg: Message = {
          id: `result-${Date.now()}`,
          type: 'tool_result',
          content: lastMessage.content,
          timestamp: new Date().toISOString(),
        }
        setStreamingMessages(prev => [...prev, resultMsg])
        break

      case 'message_complete':
        if (lastMessage.usage) {
          // Message complete - streaming text becomes a message
          if (streamingText) {
            const assistantMsg: Message = {
              id: `msg-${Date.now()}`,
              type: 'assistant',
              content: streamingText,
              timestamp: new Date().toISOString(),
            }
            addMessage(id!, assistantMsg)
          }
          setStreamingText('')
          setStreamingMessages([])
          setChatState('idle')
        }
        break
    }
  }, [lastMessage, id, streamingText, addMessage])

  const handleSend = useCallback((content: string) => {
    if (!content.trim()) return

    // Add user message
    const userMsg: Message = {
      id: `user-${Date.now()}`,
      type: 'user',
      content,
      timestamp: new Date().toISOString(),
    }
    addMessage(id!, userMsg)

    // Send to server
    send({ type: 'user_message', content })
    setChatState('thinking')
  }, [id, addMessage, send])

  // Combine persisted messages with streaming messages
  const allMessages = [
    ...(messages[id!] || []),
    ...streamingMessages,
    ...(streamingText ? [{
      id: 'streaming',
      type: 'assistant' as const,
      content: streamingText,
      timestamp: new Date().toISOString(),
    }] : []),
  ]

  const sessionTitle = session?.title || '对话'

  return (
    <>
      <Stack.Screen
        options={{
          title: sessionTitle,
          headerBackTitle: '返回',
        }}
      />
      <KeyboardAvoidingView
        style={[styles.container, { backgroundColor: colors.background }]}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={90}
      >
        {status === 'connecting' ? (
          <View style={styles.center}>
            <ActivityIndicator size="large" color={colors.primary} />
            <Text style={[styles.connectingText, { color: colors.textSecondary }]}>
              连接中...
            </Text>
          </View>
        ) : (
          <>
            <FlatList
              ref={flatListRef}
              data={allMessages}
              keyExtractor={(item) => item.id}
              renderItem={({ item }) => <MessageBubble message={item} />}
              contentContainerStyle={styles.listContent}
              onContentSizeChange={() => flatListRef.current?.scrollToEnd()}
              ListFooterComponent={
                chatState === 'thinking' ? (
                  <View style={styles.typing}>
                    <ActivityIndicator size="small" color={colors.primary} />
                    <Text style={[styles.typingText, { color: colors.textSecondary }]}>
                      思考中...
                    </Text>
                  </View>
                ) : null
              }
            />

            <ChatInput
              onSend={handleSend}
              disabled={chatState !== 'idle'}
              placeholder={
                chatState === 'thinking' ? '等待回复...' :
                chatState === 'streaming' ? '正在生成...' :
                '输入消息...'
              }
            />
          </>
        )}
      </KeyboardAvoidingView>
    </>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  connectingText: {
    marginTop: 12,
    fontSize: 14,
  },
  listContent: {
    padding: 16,
    paddingBottom: 8,
  },
  typing: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    gap: 8,
  },
  typingText: {
    fontSize: 14,
  },
})
