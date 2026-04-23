import React, { memo, useState, useRef } from 'react'
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native'
import * as Clipboard from 'expo-clipboard'
import { useTheme } from '@/utils/theme'
import type { Message } from '@/types/session'
import { MarkdownRenderer } from './markdown/MarkdownRenderer'
import { ToolCallBlock } from './chat/ToolCallBlock'
import { ThinkingBlock } from './chat/ThinkingBlock'

type MessageBubbleProps = {
  message: Message
  isLast?: boolean
}

// 使用 memo 避免不必要的重新渲染
const MessageBubbleComponent = ({ message, isLast }: MessageBubbleProps) => {
  const { colors } = useTheme()
  const [showMenu, setShowMenu] = useState(false)
  const [copySuccess, setCopySuccess] = useState(false)
  const hideTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  // 复制消息内容
  const handleCopy = async () => {
    try {
      await Clipboard.setStringAsync(message.content)
      setCopySuccess(true)
      // 显示"已复制"后自动消失
      setTimeout(() => {
        setShowMenu(false)
        setCopySuccess(false)
      }, 800)
    } catch (error) {
      console.error('Copy failed:', error)
    }
  }

  // 长按显示菜单
  const handleLongPress = () => {
    setShowMenu(true)
    setCopySuccess(false)
    // 3秒后自动隐藏
    if (hideTimeoutRef.current) {
      clearTimeout(hideTimeoutRef.current)
    }
    hideTimeoutRef.current = setTimeout(() => {
      setShowMenu(false)
      setCopySuccess(false)
    }, 3000)
  }

  // 点击气泡
  const handlePressBubble = () => {
    if (showMenu) {
      setShowMenu(false)
      setCopySuccess(false)
      if (hideTimeoutRef.current) {
        clearTimeout(hideTimeoutRef.current)
        hideTimeoutRef.current = null
      }
    }
  }

  // 是否是用户消息
  const isUserMessage = message.type === 'user_text'

  // User message - right side, primary color
  if (message.type === 'user_text') {
    return (
      <View style={[styles.userWrapper, isLast && styles.lastMessage]}>
        {/* 复制菜单 - 放在气泡上面的一个独立行 */}
        {showMenu && (
          <View style={styles.menuRowRight}>
            <TouchableOpacity
              style={styles.menuBubble}
              onPress={handleCopy}
              activeOpacity={0.7}
            >
              <Text style={copySuccess ? styles.menuTextSuccess : styles.menuText}>
                {copySuccess ? '已复制' : '复制'}
              </Text>
            </TouchableOpacity>
          </View>
        )}
        <TouchableOpacity
          style={[styles.userBubble, { backgroundColor: colors.primary }]}
          onLongPress={handleLongPress}
          onPress={handlePressBubble}
          activeOpacity={0.8}
          delayLongPress={200}
        >
          <Text style={styles.userText} selectable>{message.content}</Text>
        </TouchableOpacity>
      </View>
    )
  }

  // Assistant message - left side, with markdown
  if (message.type === 'assistant_text') {
    return (
      <View style={[styles.assistantWrapper, isLast && styles.lastMessage]}>
        {/* 复制菜单 - 放在气泡上面的一个独立行 */}
        {showMenu && (
          <View style={styles.menuRowLeft}>
            <TouchableOpacity
              style={styles.menuBubble}
              onPress={handleCopy}
              activeOpacity={0.7}
            >
              <Text style={copySuccess ? styles.menuTextSuccess : styles.menuText}>
                {copySuccess ? '已复制' : '复制'}
              </Text>
            </TouchableOpacity>
          </View>
        )}
        <TouchableOpacity
          style={[styles.assistantBubble, { backgroundColor: colors.surface, borderColor: colors.border }]}
          onLongPress={handleLongPress}
          onPress={handlePressBubble}
          activeOpacity={0.8}
          delayLongPress={200}
        >
          <MarkdownRenderer content={message.content} />
        </TouchableOpacity>
      </View>
    )
  }

  // Tool use message - show as collapsible tool call block
  if (message.type === 'tool_use') {
    return (
      <View style={[styles.toolWrapper, isLast && styles.lastMessage]}>
        <ToolCallBlock
          toolName={message.toolName || 'Unknown'}
          input={message.toolInput || {}}
          status={message.toolStatus || 'completed'}
          result={message.toolResult}
          duration={message.toolDuration}
        />
      </View>
    )
  }

  // Thinking message - show as collapsible thinking block
  if (message.type === 'thinking') {
    return (
      <View style={[styles.thinkingWrapper, isLast && styles.lastMessage]}>
        <ThinkingBlock
          content={message.content}
          isStreaming={message.isStreaming}
        />
      </View>
    )
  }

  // Other types - just show as text on left
  return (
    <View style={[styles.assistantWrapper, isLast && styles.lastMessage]}>
      <View style={[styles.assistantBubble, { backgroundColor: colors.surface, borderColor: colors.border }]}>
        <Text style={{ color: colors.text }}>{message.content}</Text>
      </View>
    </View>
  )
}

// 自定义比较函数，只在 message.id 或 isLast 变化时重新渲染
export const MessageBubble = memo(MessageBubbleComponent, (prevProps, nextProps) => {
  return (
    prevProps.message.id === nextProps.message.id &&
    prevProps.isLast === nextProps.isLast &&
    prevProps.message.type === nextProps.message.type &&
    // 对于流式消息，检查内容是否变化
    (nextProps.message.type !== 'thinking' || prevProps.message.isStreaming === nextProps.message.isStreaming)
  )
})

const styles = StyleSheet.create({
  // 消息容器
  userWrapper: {
    alignItems: 'flex-end',
    marginBottom: 12,
    paddingHorizontal: 8,
  },
  assistantWrapper: {
    alignItems: 'flex-start',
    marginBottom: 12,
    paddingHorizontal: 8,
    width: '100%',
  },
  lastMessage: {
    marginBottom: 0,
  },

  // 菜单行 - 使用 flex 布局放在气泡上方
  menuRowLeft: {
    marginBottom: 6,
    paddingLeft: 8,
  },
  menuRowRight: {
    marginBottom: 6,
    paddingRight: 8,
  },
  menuBubble: {
    backgroundColor: '#4a4a4a',
    paddingHorizontal: 18,
    paddingVertical: 8,
    borderRadius: 4,
  },
  menuText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '500',
  },
  menuTextSuccess: {
    color: '#4ade80',
    fontSize: 14,
    fontWeight: '500',
  },

  // 消息气泡
  userBubble: {
    maxWidth: '75%',
    minWidth: 50,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 18,
    borderBottomRightRadius: 4,
  },
  userText: {
    fontSize: 15,
    lineHeight: 22,
    color: '#fff',
  },

  assistantBubble: {
    maxWidth: '75%',
    minWidth: 50,
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 20,
    borderBottomLeftRadius: 8,
    borderWidth: 1,
  },

  toolWrapper: {
    marginHorizontal: 8,
    marginBottom: 4,
  },

  thinkingWrapper: {
    marginBottom: 4,
    marginHorizontal: 8,
  },
})
