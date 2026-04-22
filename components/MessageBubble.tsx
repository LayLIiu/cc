import { View, Text, StyleSheet } from 'react-native'
import { useTheme } from '@/utils/theme'
import type { Message } from '@/types/session'
import { MarkdownRenderer } from './index'

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
  },
})
