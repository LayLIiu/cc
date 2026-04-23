import React, { memo } from 'react'
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native'
import { useTheme } from '@/utils/theme'
import { ChevronDown, ChevronRight } from '../markdown/Icons'
import { ClaudeLogoWidget } from '../shared/ClaudeLogoWidget'

type ThinkingBlockProps = {
  content?: string
  isStreaming?: boolean
  timestamp?: string
}

const ThinkingBlockComponent = ({
  content = '',
  isStreaming = false,
}: ThinkingBlockProps) => {
  const { colors } = useTheme()
  const [expanded, setExpanded] = React.useState(false)

  // Get preview (first meaningful line)
  const lines = content.split('\n').filter(l => l.trim())
  const firstLine = lines[0]?.replace(/\s+/g, ' ').trim() || ''
  const preview = firstLine.length > 60 ? firstLine.slice(0, 60) + '...' : firstLine

  return (
    <View style={styles.container}>
      <TouchableOpacity
        onPress={() => setExpanded(v => !v)}
        style={styles.header}
        activeOpacity={0.7}
      >
        {/* 戴安娜 Logo 动画 */}
        <View style={styles.logoWrapper}>
          <ClaudeLogoWidget
            size={16}
            forceMode={isStreaming ? 'thinking' : 'idle'}
          />
        </View>

        <Text style={[styles.label, { color: colors.textTertiary }]}>
          thinking
        </Text>

        {!expanded && preview && (
          <Text
            style={[styles.preview, { color: colors.textTertiary }]}
            numberOfLines={1}
          >
            {preview}
          </Text>
        )}
      </TouchableOpacity>

      {expanded && (
        <ScrollView
          style={[styles.content, { backgroundColor: colors.surface, borderColor: colors.border }]}
          maximumZoomScale={1}
        >
          <Text style={[styles.contentText, { color: colors.textSecondary }]}>
            {content}
          </Text>
          {isStreaming && (
            <View style={styles.cursorContainer}>
              <View style={[styles.cursor, { backgroundColor: colors.textTertiary }]} />
            </View>
          )}
        </ScrollView>
      )}
    </View>
  )
}

export const ThinkingBlock = memo(ThinkingBlockComponent)

type ThinkingAnimationProps = {
  size?: number
  color?: string
  mode?: 'idle' | 'thinking' | 'waiting'
}

export function ThinkingAnimation({ size = 40, color = '#D97757', mode = 'thinking' }: ThinkingAnimationProps) {
  return (
    <View style={[styles.animationContainer, { width: size, height: size }]}>
      <ClaudeLogoWidget size={size} forceMode={mode} />
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    marginLeft: 40,
    marginBottom: 4,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 4,
    paddingVertical: 2,
    gap: 4,
  },
  logoWrapper: {
    width: 16,
    height: 16,
    justifyContent: 'center',
    alignItems: 'center',
  },
  label: {
    fontSize: 12,
    fontWeight: '500',
    fontStyle: 'italic',
  },
  preview: {
    flex: 1,
    fontSize: 11,
    fontFamily: 'monospace',
    marginLeft: 4,
  },
  content: {
    marginTop: 4,
    borderRadius: 8,
    borderWidth: 1,
    padding: 10,
    maxHeight: 200,
  },
  contentText: {
    fontSize: 11,
    fontFamily: 'monospace',
    lineHeight: 17,
  },
  cursorContainer: {
    marginTop: 2,
  },
  cursor: {
    width: 2,
    height: 12,
  },
  animationContainer: {
    alignItems: 'center',
    justifyContent: 'center',
  },
})
