import { useState, useRef } from 'react'
import {
  View,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
} from 'react-native'
import { useTheme } from '@/utils/theme'

type ChatInputProps = {
  onSend: (message: string) => void
  disabled?: boolean
  placeholder?: string
}

export function ChatInput({ onSend, disabled, placeholder = '输入消息...' }: ChatInputProps) {
  const { colors } = useTheme()
  const [text, setText] = useState('')
  const inputRef = useRef<TextInput>(null)

  const handleSend = () => {
    if (!text.trim() || disabled) return
    onSend(text.trim())
    setText('')
  }

  const canSend = text.trim().length > 0 && !disabled

  return (
    <View style={[styles.container, { borderTopColor: colors.border }]}>
      <TextInput
        ref={inputRef}
        style={[styles.input, { backgroundColor: colors.surface, color: colors.text }]}
        value={text}
        onChangeText={setText}
        placeholder={placeholder}
        placeholderTextColor={colors.textTertiary}
        multiline
        maxLength={4000}
        editable={!disabled}
      />
      <TouchableOpacity
        style={[
          styles.sendButton,
          { backgroundColor: colors.primary },
          !canSend && styles.sendButtonDisabled,
        ]}
        onPress={handleSend}
        disabled={!canSend}
      >
        {disabled ? (
          <ActivityIndicator size="small" color="#ffffff" />
        ) : (
          <Text style={styles.sendText}>发送</Text>
        )}
      </TouchableOpacity>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    padding: 12,
    borderTopWidth: 1,
    gap: 8,
  },
  input: {
    flex: 1,
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 10,
    fontSize: 16,
    maxHeight: 120,
  },
  sendButton: {
    paddingHorizontal: 20,
    borderRadius: 20,
    justifyContent: 'center',
    minWidth: 70,
    alignItems: 'center',
  },
  sendButtonDisabled: {
    opacity: 0.5,
  },
  sendText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
})
