import React from 'react'
import {
  View,
  Text,
  StyleSheet,
  Modal,
  TouchableOpacity,
  ScrollView,
} from 'react-native'
import { useTheme } from '@/utils/theme'

type PermissionRequest = {
  requestId: string
  toolName: string
  input: Record<string, unknown>
  description?: string
}

type PermissionDialogProps = {
  visible: boolean
  request: PermissionRequest | null
  onAllow: (requestId: string, always: boolean) => void
  onDeny: (requestId: string) => void
}

// Tool display names
const TOOL_LABELS: Record<string, string> = {
  Bash: '终端命令',
  Read: '读取文件',
  Write: '写入文件',
  Edit: '编辑文件',
  Glob: '查找文件',
  Grep: '搜索内容',
  Agent: '子代理',
  WebSearch: '网络搜索',
  WebFetch: '获取URL',
  Skill: '技能',
  MCP: 'MCP工具',
}

// Tool icons
const TOOL_ICONS: Record<string, string> = {
  Bash: '⌘',
  Read: '📄',
  Write: '✏️',
  Edit: '📝',
  Glob: '🔍',
  Grep: '🔎',
  Agent: '🤖',
  WebSearch: '🌐',
  WebFetch: '⬇️',
  Skill: '⚡',
  MCP: '🔌',
}

// Get summary for tool input
function getInputSummary(toolName: string, input: Record<string, unknown>): string {
  switch (toolName) {
    case 'Bash':
      return typeof input.command === 'string' ? input.command : ''
    case 'Read':
    case 'Write':
    case 'Edit':
      return typeof input.file_path === 'string' ? input.file_path : ''
    case 'Glob':
      return typeof input.pattern === 'string' ? input.pattern : ''
    case 'Grep':
      return typeof input.pattern === 'string' ? input.pattern : ''
    case 'Agent':
      return typeof input.description === 'string' ? input.description.slice(0, 60) : ''
    case 'WebSearch':
      return typeof input.query === 'string' ? input.query : ''
    case 'WebFetch':
      return typeof input.url === 'string' ? input.url : ''
    default:
      return ''
  }
}

export function PermissionDialog({
  visible,
  request,
  onAllow,
  onDeny,
}: PermissionDialogProps) {
  const { colors } = useTheme()

  if (!request) return null

  const icon = TOOL_ICONS[request.toolName] || '🔧'
  const label = TOOL_LABELS[request.toolName] || request.toolName
  const summary = getInputSummary(request.toolName, request.input)
  const hasInput = Object.keys(request.input).length > 0

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={() => onDeny(request.requestId)}
    >
      <View style={styles.overlay}>
        <View style={[styles.dialog, { backgroundColor: colors.surface }]}>
          {/* Header */}
          <View style={styles.header}>
            <Text style={styles.icon}>{icon}</Text>
            <View style={styles.headerText}>
              <Text style={[styles.title, { color: colors.text }]}>
                权限请求
              </Text>
              <Text style={[styles.toolName, { color: colors.primary }]}>
                {label}
              </Text>
            </View>
          </View>

          {/* Description */}
          {request.description ? (
            <Text style={[styles.description, { color: colors.textSecondary }]}>
              {request.description}
            </Text>
          ) : null}

          {/* Tool input summary */}
          {summary ? (
            <View style={[styles.summaryBox, { backgroundColor: colors.background, borderColor: colors.border }]}>
              <Text style={[styles.summaryText, { color: colors.text }]} numberOfLines={3}>
                {summary}
              </Text>
            </View>
          ) : null}

          {/* Full input (collapsible) */}
          {hasInput && !summary ? (
            <ScrollView style={[styles.inputBox, { backgroundColor: colors.background, borderColor: colors.border }]} nestedScrollEnabled>
              <Text style={[styles.inputText, { color: colors.text }]}>
                {JSON.stringify(request.input, null, 2)}
              </Text>
            </ScrollView>
          ) : null}

          {/* Buttons */}
          <View style={styles.buttonContainer}>
            <TouchableOpacity
              style={[styles.button, styles.denyButton, { borderColor: colors.border }]}
              onPress={() => onDeny(request.requestId)}
              activeOpacity={0.7}
            >
              <Text style={[styles.buttonText, { color: colors.textSecondary }]}>
                拒绝
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.button, styles.allowButton, { backgroundColor: colors.primary }]}
              onPress={() => onAllow(request.requestId, false)}
              activeOpacity={0.7}
            >
              <Text style={[styles.buttonText, { color: '#fff' }]}>
                允许
              </Text>
            </TouchableOpacity>
          </View>

          {/* Always allow */}
          <TouchableOpacity
            style={styles.alwaysButton}
            onPress={() => onAllow(request.requestId, true)}
            activeOpacity={0.7}
          >
            <Text style={[styles.alwaysText, { color: colors.textSecondary }]}>
              本次会话始终允许此工具
            </Text>
          </TouchableOpacity>
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
    gap: 12,
    marginBottom: 12,
  },
  icon: {
    fontSize: 28,
    width: 40,
    textAlign: 'center',
  },
  headerText: {
    flex: 1,
  },
  title: {
    fontSize: 16,
    fontWeight: '600',
  },
  toolName: {
    fontSize: 14,
    fontWeight: '500',
    marginTop: 2,
  },
  description: {
    fontSize: 13,
    lineHeight: 18,
    marginBottom: 12,
  },
  summaryBox: {
    borderRadius: 8,
    borderWidth: 1,
    padding: 10,
    marginBottom: 12,
  },
  summaryText: {
    fontSize: 12,
    fontFamily: 'monospace',
    lineHeight: 16,
  },
  inputBox: {
    borderRadius: 8,
    borderWidth: 1,
    padding: 10,
    marginBottom: 12,
    maxHeight: 120,
  },
  inputText: {
    fontSize: 11,
    fontFamily: 'monospace',
    lineHeight: 15,
  },
  buttonContainer: {
    flexDirection: 'row',
    gap: 10,
  },
  button: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  denyButton: {
    borderWidth: 1,
  },
  allowButton: {
    // backgroundColor set dynamically
  },
  buttonText: {
    fontSize: 15,
    fontWeight: '600',
  },
  alwaysButton: {
    marginTop: 12,
    paddingVertical: 8,
    alignItems: 'center',
  },
  alwaysText: {
    fontSize: 12,
  },
})
