import React, { useMemo, memo } from 'react'
import { View, Text, ScrollView, StyleSheet, TouchableOpacity, Linking, Platform } from 'react-native'
import * as Clipboard from 'expo-clipboard'
import { useTheme } from '@/utils/theme'
import { Copy } from './Icons'

// Simple markdown parser
const parseMarkdown = (text: string): MarkdownNode[] => {
  const nodes: MarkdownNode[] = []
  const lines = text.split('\n')
  let i = 0

  while (i < lines.length) {
    const line = lines[i]

    // Code block
    if (line.trim().startsWith('```')) {
      const language = line.trim().slice(3).trim()
      const codeLines: string[] = []
      i++

      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.push(lines[i])
        i++
      }

      nodes.push({
        type: 'code',
        content: codeLines.join('\n'),
        language: language as string,
      })
      i++
      continue
    }

    // Headers
    if (line.startsWith('#')) {
      const match = line.match(/^(#{1,6})\s+(.*)/)
      if (match) {
        nodes.push({
          type: 'heading',
          level: match[1].length,
          content: match[2],
        })
        i++
        continue
      }
    }

    // Lists
    if (line.trim().match(/^[-*+]\s+/)) {
      const items: string[] = []
      while (i < lines.length && lines[i].trim().match(/^[-*+]\s+/)) {
        items.push(lines[i].trim().replace(/^[-*+]\s+/, ''))
        i++
      }
      nodes.push({
        type: 'list',
        items,
      })
      continue
    }

    // Numbered lists
    if (line.trim().match(/^\d+\.\s+/)) {
      const items: string[] = []
      while (i < lines.length && lines[i].trim().match(/^\d+\.\s+/)) {
        items.push(lines[i].trim().replace(/^\d+\.\s+/, ''))
        i++
      }
      nodes.push({
        type: 'numbered-list',
        items,
      })
      continue
    }

    // Blockquotes
    if (line.trim().startsWith('>')) {
      const quoteLines: string[] = []
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        quoteLines.push(lines[i].trim().replace(/^>\s?/, ''))
        i++
      }
      nodes.push({
        type: 'blockquote',
        content: quoteLines.join('\n'),
      })
      continue
    }

    // Empty line
    if (line.trim() === '') {
      nodes.push({ type: 'newline' })
      i++
      continue
    }

    // Regular paragraph with inline elements
    if (line.trim()) {
      nodes.push({
        type: 'paragraph',
        content: parseInlineElements(line),
      })
    }

    i++
  }

  // Remove trailing newlines to avoid extra whitespace at end
  while (nodes.length > 0 && nodes[nodes.length - 1]?.type === 'newline') {
    nodes.pop()
  }

  return nodes
}

// Parse inline elements (links, bold, italic, code)
const parseInlineElements = (text: string): InlineElement[] => {
  const elements: InlineElement[] = []
  let remaining = text

  while (remaining.length > 0) {
    // Links [text](url)
    const linkMatch = remaining.match(/\[([^\]]+)\]\(([^)]+)\)/)
    if (linkMatch && linkMatch.index === 0) {
      elements.push({
        type: 'link',
        content: linkMatch[1],
        url: linkMatch[2],
      })
      remaining = remaining.slice(linkMatch[0].length)
      continue
    }

    // Bold **text**
    const boldMatch = remaining.match(/\*\*([^*]+)\*\*/)
    if (boldMatch && boldMatch.index === 0) {
      elements.push({
        type: 'bold',
        content: boldMatch[1],
      })
      remaining = remaining.slice(boldMatch[0].length)
      continue
    }

    // Italic *text*
    const italicMatch = remaining.match(/\*([^*]+)\*/)
    if (italicMatch && italicMatch.index === 0) {
      elements.push({
        type: 'italic',
        content: italicMatch[1],
      })
      remaining = remaining.slice(italicMatch[0].length)
      continue
    }

    // Inline code `text`
    const codeMatch = remaining.match(/`([^`]+)`/)
    if (codeMatch && codeMatch.index === 0) {
      elements.push({
        type: 'inline-code',
        content: codeMatch[1],
      })
      remaining = remaining.slice(codeMatch[0].length)
      continue
    }

    // Regular text
    elements.push({
      type: 'text',
      content: remaining[0]!,
    })
    remaining = remaining.slice(1)
  }

  return elements
}

type MarkdownNode =
  | { type: 'code'; content: string; language: string }
  | { type: 'heading'; level: number; content: string }
  | { type: 'paragraph'; content: InlineElement[] }
  | { type: 'list'; items: string[] }
  | { type: 'numbered-list'; items: string[] }
  | { type: 'blockquote'; content: string }
  | { type: 'newline' }

type InlineElement =
  | { type: 'text'; content: string }
  | { type: 'link'; content: string; url: string }
  | { type: 'bold'; content: string }
  | { type: 'italic'; content: string }
  | { type: 'inline-code'; content: string }

type MarkdownRendererProps = {
  content: string
  style?: any
}

// Code block component with copy functionality
function CodeBlock({
  code,
  language
}: {
  code: string
  language: string
}) {
  const { colors } = useTheme()
  const [copied, setCopied] = React.useState(false)

  const handleCopy = async () => {
    try {
      await Clipboard.setStringAsync(code)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch (err) {
      console.error('Failed to copy:', err)
    }
  }

  return (
    <View style={[styles.codeBlock, { backgroundColor: '#1e1e1e' }]}>
      <View style={styles.codeHeader}>
        <Text style={styles.codeLanguage}>
          {language || 'code'}
        </Text>
        <TouchableOpacity onPress={handleCopy} style={styles.copyButton}>
          <Copy
            color={copied ? colors.success : '#888'}
            size={16}
          />
        </TouchableOpacity>
      </View>
      <ScrollView horizontal style={styles.codeScroll} showsHorizontalScrollIndicator={false}>
        <Text style={styles.codeText}>
          {code}
        </Text>
      </ScrollView>
      {copied && (
        <View style={styles.copyIndicator}>
          <Text style={styles.copyIndicatorText}>已复制</Text>
        </View>
      )}
    </View>
  )
}

const MarkdownRendererComponent = ({ content, style }: MarkdownRendererProps) => {
  const { colors } = useTheme()
  const nodes = useMemo(() => parseMarkdown(content), [content])

  const renderInlineElement = (element: InlineElement) => {
    switch (element.type) {
      case 'text':
        return <Text style={{ color: colors.text }}>{element.content}</Text>
      case 'link':
        return (
          <TouchableOpacity
            onPress={() => Linking.openURL(element.url)}
            activeOpacity={0.7}
          >
            <Text style={{ color: colors.primary }}>{element.content}</Text>
          </TouchableOpacity>
        )
      case 'bold':
        return (
          <Text style={{ color: colors.text, fontWeight: '700' }}>
            {element.content}
          </Text>
        )
      case 'italic':
        return (
          <Text style={{ color: colors.text, fontStyle: 'italic' }}>
            {element.content}
          </Text>
        )
      case 'inline-code':
        return (
          <Text
            style={{
              backgroundColor: colors.surface,
              color: colors.accent,
              fontFamily: Platform.select({ ios: 'Courier', android: 'monospace' }),
              paddingHorizontal: 4,
              borderRadius: 4,
              fontSize: 13,
            }}
          >
            {element.content}
          </Text>
        )
    }
  }

  const renderNode = (node: MarkdownNode, index: number) => {
    switch (node.type) {
      case 'code':
        return (
          <CodeBlock
            key={index}
            code={node.content}
            language={node.language}
          />
        )

      case 'heading':
        const fontSize = 24 - node.level * 2
        return (
          <Text
            key={index}
            style={[
              styles.heading,
              {
                color: colors.text,
                fontSize,
                marginTop: node.level === 1 ? 16 : 12,
              },
            ]}
          >
            {node.content}
          </Text>
        )

      case 'paragraph':
        return (
          <Text key={index} style={[styles.paragraph, { color: colors.text }]}>
            {node.content.map((el, i) => (
              <React.Fragment key={i}>{renderInlineElement(el)}</React.Fragment>
            ))}
          </Text>
        )

      case 'list':
        return (
          <View key={index} style={styles.list}>
            {node.items.map((item, itemIndex) => (
              <View key={itemIndex} style={styles.listItem}>
                <Text style={[styles.bullet, { color: colors.textSecondary }]}>•</Text>
                <Text style={{ color: colors.text }}>{item}</Text>
              </View>
            ))}
          </View>
        )

      case 'numbered-list':
        return (
          <View key={index} style={styles.list}>
            {node.items.map((item, itemIndex) => (
              <View key={itemIndex} style={styles.listItem}>
                <Text style={[styles.bullet, { color: colors.textSecondary }]}>
                  {itemIndex + 1}.
                </Text>
                <Text style={{ color: colors.text }}>{item}</Text>
              </View>
            ))}
          </View>
        )

      case 'blockquote':
        return (
          <View
            key={index}
            style={[styles.blockquote, { borderColor: colors.border, backgroundColor: colors.surface }]}
          >
            <Text style={{ color: colors.textSecondary, fontStyle: 'italic' }}>
              {node.content}
            </Text>
          </View>
        )

      case 'newline':
        return <View key={index} style={{ height: 4 }} />
    }
  }

  return (
    <View style={[styles.container, style]}>
      {nodes.map((node, index) => renderNode(node, index))}
    </View>
  )
}

export const MarkdownRenderer = memo(MarkdownRendererComponent)

const styles = StyleSheet.create({
  container: {
    flexShrink: 1,
  },
  codeBlock: {
    marginVertical: 4,
    borderRadius: 8,
    overflow: 'hidden',
    maxWidth: '100%',
  },
  codeHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(128, 128, 128, 0.2)',
  },
  codeLanguage: {
    fontSize: 12,
    fontWeight: '500',
    color: '#888',
    textTransform: 'lowercase',
  },
  copyButton: {
    padding: 4,
  },
  codeScroll: {
    paddingHorizontal: 8,
    flexGrow: 0,
  },
  codeText: {
    fontFamily: Platform.select({ ios: 'Courier', android: 'monospace' }),
    fontSize: 13,
    lineHeight: 20,
    color: '#d4d4d4',
    paddingHorizontal: 8,
    paddingVertical: 8,
  },
  copyIndicator: {
    position: 'absolute',
    top: 50,
    right: 12,
    backgroundColor: '#22c55e',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  copyIndicatorText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '500',
  },
  heading: {
    fontWeight: '700',
    marginBottom: 4,
  },
  paragraph: {
    flexShrink: 1,
    lineHeight: 22,
  },
  list: {
    marginLeft: 16,
    marginVertical: 4,
    flexShrink: 1,
  },
  listItem: {
    flexDirection: 'row',
    marginBottom: 2,
    flexShrink: 1,
  },
  bullet: {
    marginRight: 8,
    minWidth: 20,
  },
  blockquote: {
    borderLeftWidth: 4,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginVertical: 4,
    borderRadius: 4,
    flexShrink: 1,
  },
})
