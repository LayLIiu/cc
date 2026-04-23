import { View, Text, StyleSheet } from 'react-native'
import { useTheme } from '@/utils/theme'
import type { Message } from '@/types/session'
import { MarkdownRenderer } from './markdown/MarkdownRenderer'
import { ToolCallBlock } from './chat/ToolCallBlock'
import { ThinkingBlock } from './chat/ThinkingBlock'

type MessageBubbleProps = {
  message: Message
  isLast?: boolean
}

export function MessageBubble({ message, isLast }: MessageBubbleProps) {
  const { colors } = useTheme()

  // User message - right side, primary color
  if (message.type === 'user_text') {
    return (
      <View style={[styles.userWrapper, isLast && styles.lastMessage]}>
        <View style={[styles.userBubble, { backgroundColor: colors.primary }]}>
          <Text style={styles.userText}>{message.content}</Text>
        </View>
      </View>
    )
  }

  // Assistant message - left side, with markdown
  if (message.type === 'assistant_text') {
    return (
      <View style={[styles.assistantWrapper, isLast && styles.lastMessage]}>
        <View style={[styles.assistantBubble, { backgroundColor: colors.surface, borderColor: colors.border }]}>
          <MarkdownRenderer content={message.content} />
        </View>
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

const styles = StyleSheet.create({
  userWrapper: {
    alignItems: 'flex-end',
    marginBottom: 12,
  },
  lastMessage: {
    marginBottom: 0,
  },
  userBubble: {
    maxWidth: '85%',
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

  assistantWrapper: {
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  assistantBubble: {
    maxWidth: '85%',
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 20,
    borderBottomLeftRadius: 8,
    borderWidth: 1,
    overflow: 'hidden',
  },

  toolWrapper: {
    marginHorizontal: 16,
    marginBottom: 4,
  },

  thinkingWrapper: {
    marginBottom: 4,
  },
})
