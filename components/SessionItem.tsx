import { View, Text, TouchableOpacity, StyleSheet, Animated, Alert } from 'react-native'
import { useRef, useState } from 'react'
import { useTheme } from '@/utils/theme'
import type { Session } from '@/types/session'

type SessionItemProps = {
  session: Session
  onPress: () => void
  onDelete?: () => void
  isActive?: boolean
}

export function SessionItem({ session, onPress, onDelete, isActive }: SessionItemProps) {
  const { colors } = useTheme()
  const [translateX] = useState(new Animated.Value(0))
  const [isSwipeOpen, setIsSwipeOpen] = useState(false)

  if (!session) return null

  const formatTime = (dateStr: string) => {
    const date = new Date(dateStr)
    const now = new Date()
    const diffMs = now.getTime() - date.getTime()
    const diffMins = Math.floor(diffMs / 60000)
    const diffHours = Math.floor(diffMs / 3600000)
    const diffDays = Math.floor(diffMs / 86400000)

    if (diffMins < 1) return '刚刚'
    if (diffMins < 60) return `${diffMins}分钟前`
    if (diffHours < 24) return `${diffHours}小时前`
    if (diffDays < 7) return `${diffDays}天前`
    return date.toLocaleDateString('zh-CN')
  }

  // Get project name from path
  const projectName = session.projectPath?.split('/').pop() || ''

  const openSwipe = () => {
    Animated.spring(translateX, {
      toValue: -80,
      useNativeDriver: true,
      tension: 100,
      friction: 10,
    }).start()
    setIsSwipeOpen(true)
  }

  const closeSwipe = () => {
    Animated.spring(translateX, {
      toValue: 0,
      useNativeDriver: true,
      tension: 100,
      friction: 10,
    }).start()
    setIsSwipeOpen(false)
  }

  const handleToggleSwipe = () => {
    if (isSwipeOpen) {
      closeSwipe()
    } else {
      openSwipe()
    }
  }

  const handleDelete = () => {
    Alert.alert(
      '删除对话',
      '确定要删除这个对话吗？',
      [
        { text: '取消', style: 'cancel', onPress: closeSwipe },
        {
          text: '删除',
          style: 'destructive',
          onPress: () => {
            closeSwipe()
            onDelete?.()
          },
        },
      ]
    )
  }

  return (
    <View style={styles.wrapper}>
      {/* Delete button underneath */}
      <View style={styles.deleteContainer}>
        <TouchableOpacity
          style={styles.deleteButton}
          onPress={handleDelete}
          activeOpacity={0.8}
        >
          <Text style={styles.deleteIcon}>🗑️</Text>
          <Text style={styles.deleteText}>删除</Text>
        </TouchableOpacity>
      </View>

      {/* Session item on top */}
      <Animated.View
        style={[
          styles.animatedContainer,
          { transform: [{ translateX }], backgroundColor: colors.background },
        ]}
      >
        <TouchableOpacity
          style={[
            styles.container,
            isActive && { backgroundColor: colors.surfaceHover },
          ]}
          onPress={isSwipeOpen ? closeSwipe : onPress}
          onLongPress={handleToggleSwipe}
          activeOpacity={0.7}
        >
          <View style={styles.iconContainer}>
            <Text style={styles.icon}>💬</Text>
          </View>

          <View style={styles.content}>
            <Text
              style={[styles.title, { color: colors.text }]}
              numberOfLines={1}
            >
              {session.title || '新对话'}
            </Text>

            <View style={styles.metaRow}>
              {projectName && (
                <Text style={[styles.projectName, { color: colors.textSecondary }]} numberOfLines={1}>
                  {projectName}
                </Text>
              )}
              <Text style={[styles.time, { color: colors.textTertiary }]}>
                {formatTime(session.modifiedAt)}
              </Text>
            </View>

            {session.messageCount > 0 && (
              <Text style={[styles.messageCount, { color: colors.textTertiary }]}>
                {session.messageCount} 条消息
              </Text>
            )}
          </View>

          {/* Swipe hint */}
          <TouchableOpacity onPress={handleToggleSwipe} style={styles.swipeHint}>
            <Text style={[styles.swipeHintText, { color: colors.textTertiary }]}>
              {isSwipeOpen ? '◀' : '▶'}
            </Text>
          </TouchableOpacity>
        </TouchableOpacity>
      </Animated.View>
    </View>
  )
}

const styles = StyleSheet.create({
  wrapper: {
    position: 'relative',
  },
  deleteContainer: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    width: 80,
    justifyContent: 'center',
    alignItems: 'center',
  },
  deleteButton: {
    width: 70,
    height: 50,
    borderRadius: 8,
    backgroundColor: '#ef4444',
    justifyContent: 'center',
    alignItems: 'center',
  },
  deleteIcon: {
    fontSize: 16,
  },
  deleteText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
    marginTop: 2,
  },
  animatedContainer: {
    // backgroundColor is set dynamically from theme
  },
  container: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    paddingVertical: 10,
    paddingHorizontal: 12,
    gap: 12,
  },
  iconContainer: {
    width: 36,
    height: 36,
    borderRadius: 8,
    backgroundColor: 'rgba(99, 102, 241, 0.1)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  icon: {
    fontSize: 18,
  },
  content: {
    flex: 1,
    gap: 2,
  },
  title: {
    fontSize: 15,
    fontWeight: '500',
    lineHeight: 20,
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: 2,
  },
  projectName: {
    fontSize: 13,
    flex: 1,
  },
  time: {
    fontSize: 12,
  },
  messageCount: {
    fontSize: 12,
    marginTop: 2,
  },
  swipeHint: {
    padding: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  swipeHintText: {
    fontSize: 12,
  },
})
