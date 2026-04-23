import React, { useState, memo } from 'react'
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
} from 'react-native'
import { useTheme } from '@/utils/theme'
import { MarkdownRenderer } from '../markdown/MarkdownRenderer'
import { ChevronDown, ChevronRight, Tool } from '../markdown/Icons'

type ToolCallProps = {
  toolName: string
  input: Record<string, any>
  status?: 'pending' | 'running' | 'completed' | 'failed'
  result?: any
  timestamp?: string
  duration?: number
}

// Tool icons mapping (using emoji/unicode as fallback)
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
}

// Tool display names
const TOOL_LABELS: Record<string, string> = {
  Bash: 'Terminal',
  Read: 'Read file',
  Write: 'Write file',
  Edit: 'Edit file',
  Glob: 'Find files',
  Grep: 'Search content',
  Agent: 'Agent',
  WebSearch: 'Web search',
  WebFetch: 'Fetch URL',
}

const ToolCallBlockComponent = ({
  toolName,
  input,
  status = 'completed',
  result,
  timestamp,
  duration,
}: ToolCallProps) => {
  const { colors } = useTheme()
  const [expanded, setExpanded] = useState(false)

  const icon = TOOL_ICONS[toolName] || '🔧'
  const label = TOOL_LABELS[toolName] || toolName

  // Get summary based on tool type
  const getSummary = () => {
    const obj = input || {}

    switch (toolName) {
      case 'Bash':
        return typeof obj.command === 'string' ? obj.command.slice(0, 50) : ''
      case 'Read':
      case 'Write':
      case 'Edit':
        const filePath = typeof obj.file_path === 'string' ? obj.file_path : ''
        return filePath.split('/').pop() || filePath
      case 'Glob':
        return typeof obj.pattern === 'string' ? obj.pattern : ''
      case 'Grep':
        return typeof obj.pattern === 'string' ? obj.pattern : ''
      case 'Agent':
        return typeof obj.description === 'string' ? obj.description.slice(0, 40) : ''
      default:
        return ''
    }
  }

  // Get result summary
  const getResultSummary = () => {
    if (!result) return null
    const text = typeof result === 'string' ? result : JSON.stringify(result)
    const lines = text.split('\n').length
    return lines > 1 ? `${lines} lines` : text.slice(0, 30)
  }

  const summary = getSummary()
  const resultSummary = getResultSummary()
  const isExpandable = ['Edit', 'Write', 'Bash'].includes(toolName)

  return (
    <View style={[styles.container, { borderColor: colors.border, backgroundColor: colors.surface }]}>
      {/* Header */}
      <TouchableOpacity
        style={styles.header}
        onPress={() => isExpandable && setExpanded(!expanded)}
        activeOpacity={0.7}
        disabled={!isExpandable}
      >
        <Text style={styles.icon}>{icon}</Text>

        <Text style={[styles.toolLabel, { color: colors.textSecondary }]}>
          {toolName}
        </Text>

        {summary ? (
          <Text
            style={[styles.summary, { color: colors.textTertiary }]}
            numberOfLines={1}
          >
            {summary}
          </Text>
        ) : (
          <View style={styles.summaryPlaceholder} />
        )}

        {status === 'completed' && (
          <Text style={styles.checkmark}>✓</Text>
        )}

        {status === 'failed' && (
          <Text style={styles.errorIcon}>✗</Text>
        )}

        {isExpandable && (
          expanded
            ? <ChevronDown size={16} color={colors.textTertiary} />
            : <ChevronRight size={16} color={colors.textTertiary} />
        )}
      </TouchableOpacity>

      {/* Expanded Content */}
      {expanded && (
        <View style={[styles.expandedContent, { borderTopColor: colors.border }]}>
          {/* Input */}
          <View style={styles.section}>
            <Text style={[styles.sectionLabel, { color: colors.textTertiary }]}>
              INPUT
            </Text>
            <View style={[styles.codeBlock, { backgroundColor: colors.background, borderColor: colors.border }]}>
              <ScrollView horizontal>
                <Text style={[styles.codeText, { color: colors.text }]}>
                  {JSON.stringify(input, null, 2)}
                </Text>
              </ScrollView>
            </View>
          </View>

          {/* Result */}
          {result && (
            <View style={styles.section}>
              <Text style={[styles.sectionLabel, { color: colors.textTertiary }]}>
                OUTPUT
              </Text>
              <View style={[styles.codeBlock, { backgroundColor: colors.background, borderColor: colors.border }]}>
                <MarkdownRenderer
                  content={typeof result === 'string' ? result : JSON.stringify(result, null, 2)}
                />
              </View>
            </View>
          )}
        </View>
      )}
    </View>
  )
}

export const ToolCallBlock = memo(ToolCallBlockComponent)

type ToolCallGroupProps = {
  title?: string
  children: React.ReactNode
}

export function ToolCallGroup({ title, children }: ToolCallGroupProps) {
  const { colors } = useTheme()

  return (
    <View style={[styles.groupContainer, { borderColor: colors.border }]}>
      {title && (
        <View style={[styles.groupTitle, { backgroundColor: colors.surface }]}>
          <Text style={[styles.groupTitleText, { color: colors.textSecondary }]}>
            {title}
          </Text>
        </View>
      )}
      <View style={styles.groupContent}>{children}</View>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    borderRadius: 10,
    borderWidth: 1,
    marginVertical: 4,
    overflow: 'hidden',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
  },
  icon: {
    fontSize: 14,
    width: 20,
    textAlign: 'center',
  },
  toolLabel: {
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  summary: {
    flex: 1,
    fontSize: 12,
    fontFamily: 'monospace',
  },
  summaryPlaceholder: {
    flex: 1,
  },
  checkmark: {
    color: '#22c55e',
    fontSize: 14,
    fontWeight: '600',
  },
  errorIcon: {
    color: '#ef4444',
    fontSize: 14,
    fontWeight: '600',
  },
  expandedContent: {
    borderTopWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 12,
    gap: 12,
  },
  section: {
    gap: 6,
  },
  sectionLabel: {
    fontSize: 10,
    fontWeight: '600',
    letterSpacing: 1.5,
    textTransform: 'uppercase',
  },
  codeBlock: {
    borderRadius: 8,
    borderWidth: 1,
    padding: 10,
  },
  codeText: {
    fontSize: 12,
    fontFamily: 'monospace',
    lineHeight: 18,
  },
  groupContainer: {
    borderWidth: 1,
    borderRadius: 12,
    marginVertical: 8,
    overflow: 'hidden',
  },
  groupTitle: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderBottomWidth: 1,
  },
  groupTitleText: {
    fontSize: 12,
    fontWeight: '500',
  },
  groupContent: {
    paddingVertical: 4,
  },
})
