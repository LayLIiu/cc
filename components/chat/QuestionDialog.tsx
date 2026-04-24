import React, { useState } from 'react'
import {
  View,
  Text,
  StyleSheet,
  Modal,
  TouchableOpacity,
  TextInput,
  ScrollView,
} from 'react-native'
import { useTheme } from '@/utils/theme'

type QuestionRequest = {
  questionId: string
  questionText: string
  options: string[]
}

type QuestionDialogProps = {
  visible: boolean
  request: QuestionRequest | null
  onAnswer: (questionId: string, answer: string) => void
}

export function QuestionDialog({
  visible,
  request,
  onAnswer,
}: QuestionDialogProps) {
  const { colors } = useTheme()
  const [textAnswer, setTextAnswer] = useState('')

  if (!request) return null

  const hasOptions = request.options && request.options.length > 0

  const handleOptionSelect = (option: string) => {
    onAnswer(request.questionId, option)
    setTextAnswer('')
  }

  const handleTextSubmit = () => {
    if (!textAnswer.trim()) return
    onAnswer(request.questionId, textAnswer.trim())
    setTextAnswer('')
  }

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={() => {
        // 不能关闭，必须回答
      }}
    >
      <View style={styles.overlay}>
        <View style={[styles.dialog, { backgroundColor: colors.surface }]}>
          {/* Header */}
          <View style={styles.header}>
            <Text style={styles.icon}>❓</Text>
            <Text style={[styles.title, { color: colors.text }]}>
              问题
            </Text>
          </View>

          {/* Question text */}
          <ScrollView style={styles.questionScroll} nestedScrollEnabled>
            <Text style={[styles.questionText, { color: colors.text }]}>
              {request.questionText}
            </Text>
          </ScrollView>

          {/* Options or text input */}
          {hasOptions ? (
            <View style={styles.optionsContainer}>
              {request.options.map((option, index) => (
                <TouchableOpacity
                  key={index}
                  style={[styles.optionButton, { borderColor: colors.border, backgroundColor: colors.background }]}
                  onPress={() => handleOptionSelect(option)}
                  activeOpacity={0.7}
                >
                  <Text style={[styles.optionLabel, { color: colors.primary }]}>
                    {String.fromCharCode(65 + index)}.
                  </Text>
                  <Text style={[styles.optionText, { color: colors.text }]}>
                    {option}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          ) : (
            <View style={styles.inputContainer}>
              <TextInput
                style={[styles.input, { backgroundColor: colors.background, color: colors.text, borderColor: colors.border }]}
                value={textAnswer}
                onChangeText={setTextAnswer}
                placeholder="输入你的回答..."
                placeholderTextColor={colors.textTertiary}
                multiline
                maxLength={4000}
              />
              <TouchableOpacity
                style={[styles.submitButton, { backgroundColor: colors.primary }]}
                onPress={handleTextSubmit}
                disabled={!textAnswer.trim()}
                activeOpacity={0.7}
              >
                <Text style={[styles.submitText, { opacity: textAnswer.trim() ? 1 : 0.5 }]}>
                  提交
                </Text>
              </TouchableOpacity>
            </View>
          )}
        </View>
      </View>
    </Modal>
  )
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  dialog: {
    width: '100%',
    maxWidth: 400,
    borderRadius: 16,
    padding: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 16,
  },
  icon: {
    fontSize: 24,
  },
  title: {
    fontSize: 17,
    fontWeight: '600',
  },
  questionScroll: {
    maxHeight: 200,
    marginBottom: 16,
  },
  questionText: {
    fontSize: 15,
    lineHeight: 22,
  },
  optionsContainer: {
    gap: 8,
  },
  optionButton: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    padding: 12,
    borderRadius: 10,
    borderWidth: 1,
    gap: 8,
  },
  optionLabel: {
    fontSize: 14,
    fontWeight: '700',
    minWidth: 22,
  },
  optionText: {
    fontSize: 14,
    flex: 1,
    lineHeight: 20,
  },
  inputContainer: {
    gap: 10,
  },
  input: {
    borderRadius: 10,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 10,
    fontSize: 15,
    maxHeight: 100,
  },
  submitButton: {
    paddingVertical: 12,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  submitText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
  },
})
