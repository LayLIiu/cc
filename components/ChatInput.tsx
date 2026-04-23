import React, { useState, memo } from 'react'
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
} from 'react-native'
import { useTheme } from '@/utils/theme'
import { ClaudeLogoWidget } from './shared/ClaudeLogoWidget'

type ChatInputProps = {
  onSend: (message: string) => void
  onStop?: () => void
  placeholder?: string
  chatStatus?: 'idle' | 'thinking' | 'tool_executing' | 'streaming' | 'permission_pending'
}

const ChatInputComponent = ({ onSend, onStop, placeholder = '发送消息...', chatStatus = 'idle' }: ChatInputProps) => {
  const { colors } = useTheme()
  const [text, setText] = useState('')

  const isWorking = chatStatus !== 'idle'

  const handleSend = () => {
    if (!text.trim()) return
    onSend(text.trim())
    setText('')
  }

  const handleStop = () => {
    onStop?.()
  }

  return (
    <View style={[styles.container, { borderTopColor: colors.border, backgroundColor: colors.background }]}>
      {/* 戴安娜 Logo */}
      <View style={styles.logoContainer}>
        <ClaudeLogoWidget
          size={36}
          chatStatus={chatStatus}
        />
      </View>

      <TextInput
        style={[styles.input, { backgroundColor: colors.surface, color: colors.text }]}
        value={text}
        onChangeText={setText}
        placeholder={placeholder}
        placeholderTextColor={colors.textTertiary}
        multiline
        maxLength={4000}
      />
      {isWorking && !text.trim() ? (
        <TouchableOpacity
          style={styles.stopButton}
          onPress={handleStop}
        >
          <Text style={styles.stopText}>暂停</Text>
        </TouchableOpacity>
      ) : (
        <TouchableOpacity
          style={[styles.sendButton, { backgroundColor: colors.primary }]}
          onPress={handleSend}
          disabled={!text.trim()}
        >
          <Text style={[styles.sendText, { opacity: text.trim() ? 1 : 0.5 }]}>发送</Text>
        </TouchableOpacity>
      )}
    </View>
  )
}

export const ChatInput = memo(ChatInputComponent)

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    padding: 16,
    borderTopWidth: 1,
    gap: 10,
    alignItems: 'flex-end',
  },
  logoContainer: {
    width: 36,
    height: 36,
    justifyContent: 'center',
    alignItems: 'center',
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
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  sendText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
  },
  stopButton: {
    backgroundColor: '#f97316',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  stopText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
  },
})
