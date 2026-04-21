import { View, Text, StyleSheet } from 'react-native'
import { useTheme } from '@/utils/theme'
import type { Message } from '@/types/session'

type MessageBubbleProps = {
  message: Message
}

export function MessageBubble({ message }: MessageBubbleProps) {
  const { colors } = useTheme()
  const isUser = message.type === 'user'
  const isTool = message.type === 'tool_use' || message.type === 'tool_result'

  const getContent = () => {
    if (typeof message.content === 'string') {
      return message.content
    }
    if (message.content && typeof message.content === 'object') {
      // Tool use
      if (message.type === 'tool_use') {
        const input = (message.content as any).input
        const toolName = (message.content as any).name || 'Tool'
        if (toolName === 'Bash' && input?.command) {
          return `🖥️ ${input.command}`
        }
        if (input?.file_path) {
          return `📄 ${input.file_path}`
        }
        return `🔧 ${toolName}`
      }
      // Tool result
      if (message.type === 'tool_result') {
        return '✅ 完成'
      }
      return JSON.stringify(message.content, null, 2)
    }
    return ''
  }

  const content = getContent()

  if (isTool) {
    return (
      <View style={[styles.toolContainer, { backgroundColor: colors.surface }]}>
        <Text style={[styles.toolText, { color: colors.textSecondary }]}>
          {content}
        </Text>
      </View>
    )
  }

  return (
    <View
      style={[
        styles.container,
        isUser
          ? [styles.userContainer, { backgroundColor: colors.primary }]
          : [styles.assistantContainer, { backgroundColor: colors.surface }],
      ]}
    >
      <Text
        style={[
          styles.text,
          { color: isUser ? '#ffffff' : colors.text },
        ]}
      >
        {content}
      </Text>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    maxWidth: '85%',
    padding: 12,
    borderRadius: 16,
    marginBottom: 8,
  },
  userContainer: {
    alignSelf: 'flex-end',
    borderBottomRightRadius: 4,
  },
  assistantContainer: {
    alignSelf: 'flex-start',
    borderBottomLeftRadius: 4,
  },
  text: {
    fontSize: 15,
    lineHeight: 22,
  },
  toolContainer: {
    alignSelf: 'flex-start',
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 8,
    marginBottom: 4,
  },
  toolText: {
    fontSize: 13,
    fontFamily: 'monospace',
  },
})
