import React from 'react'
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native'
import { useTheme } from '@/utils/theme'
import { ChevronDown, ChevronRight } from '../markdown/Icons'

type ThinkingBlockProps = {
  content?: string
  isStreaming?: boolean
  timestamp?: string
}

export function ThinkingBlock({
  content = '',
  isStreaming = false,
}: ThinkingBlockProps) {
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
        {expanded ? (
          <ChevronDown size={12} color={colors.textTertiary} />
        ) : (
          <ChevronRight size={12} color={colors.textTertiary} />
        )}

        <Text style={[styles.label, { color: colors.textTertiary }]}>
          thinking
        </Text>

        {isStreaming && (
          <View style={styles.streamingDots}>
            <View style={[styles.dot, { backgroundColor: colors.textTertiary }]} />
            <View style={[styles.dot, styles.dot2, { backgroundColor: colors.textTertiary }]} />
            <View style={[styles.dot, styles.dot3, { backgroundColor: colors.textTertiary }]} />
          </View>
        )}

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

type ThinkingAnimationProps = {
  size?: number
  color?: string
}

export function ThinkingAnimation({ size = 40, color = '#6366f1' }: ThinkingAnimationProps) {
  return (
    <View style={[styles.animationContainer, { width: size, height: size }]}>
      <View style={[styles.pulseRing, { borderColor: color }]} />
      <View style={[styles.pulseCore, { backgroundColor: color }]} />
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
  label: {
    fontSize: 12,
    fontWeight: '500',
    fontStyle: 'italic',
  },
  streamingDots: {
    flexDirection: 'row',
    marginLeft: 4,
  },
  dot: {
    width: 3,
    height: 3,
    borderRadius: 1.5,
    opacity: 0.4,
  },
  dot2: {
    marginLeft: 2,
    opacity: 0.6,
  },
  dot3: {
    marginLeft: 2,
    opacity: 0.8,
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
  pulseRing: {
    position: 'absolute',
    width: '100%',
    height: '100%',
    borderRadius: 100,
    borderWidth: 2,
    opacity: 0.3,
  },
  pulseCore: {
    width: '40%',
    height: '40%',
    borderRadius: 100,
  },
})
