import { useState } from 'react'
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
} from 'react-native'
import { useTheme } from '@/utils/theme'

type ChatInputProps = {
  onSend: (message: string) => void
  placeholder?: string
}

export function ChatInput({ onSend, placeholder = '发送消息...' }: ChatInputProps) {
  const { colors } = useTheme()
  const [text, setText] = useState('')

  const handleSend = () => {
    if (!text.trim()) return
    onSend(text.trim())
    setText('')
  }

  return (
    <View style={[styles.container, { borderTopColor: colors.border }]}>
      <TextInput
        style={[styles.input, { backgroundColor: colors.surface, color: colors.text }]}
        value={text}
        onChangeText={setText}
        placeholder={placeholder}
        placeholderTextColor={colors.textTertiary}
        multiline
        maxLength={4000}
      />
      <TouchableOpacity
        style={[styles.sendButton, { backgroundColor: colors.primary }]}
        onPress={handleSend}
      >
        <Text style={styles.sendText}>发送</Text>
      </TouchableOpacity>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    padding: 16,
    borderTopWidth: 1,
    gap: 10,
  },
  input: {
    flex: 1,
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 10,
    fontSize: 16,
    maxHeight: 100,
  },
  sendButton: {
    paddingHorizontal: 32,
    paddingVertical: 12,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
  },
  sendText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
})
