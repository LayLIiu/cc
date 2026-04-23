import React, { useState, memo } from 'react'
import { View, Text, TouchableOpacity, StyleSheet, Animated, Modal } from 'react-native'
import { useTheme } from '@/utils/theme'
import type { Session, SessionStatus } from '@/types/session'
import { ClaudeLogoWidget } from './shared/ClaudeLogoWidget'

type SessionItemProps = {
  session: Session
  onPress: () => void
  onDelete?: () => void
  isActive?: boolean
  status?: SessionStatus
}

const SessionItemComponent = ({ session, onPress, onDelete, isActive, status = 'idle' }: SessionItemProps) => {
  const { colors } = useTheme()
  const [translateX] = useState(new Animated.Value(0))
  const [isSwipeOpen, setIsSwipeOpen] = useState(false)
  const [showDeleteModal, setShowDeleteModal] = useState(false)

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
    setShowDeleteModal(true)
  }

  const handleConfirmDelete = () => {
    setShowDeleteModal(false)
    closeSwipe()
    onDelete?.()
  }

  const handleCancelDelete = () => {
    setShowDeleteModal(false)
    closeSwipe()
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
          {/* 状态图标 */}
          <View style={styles.iconContainer}>
            {status !== 'idle' ? (
              <ClaudeLogoWidget
                size={28}
                forceMode="thinking"
              />
            ) : (
              <Text style={styles.icon}>💬</Text>
            )}
          </View>

          <View style={styles.content}>
            <View style={styles.titleRow}>
              <Text
                style={[styles.title, { color: colors.text }]}
                numberOfLines={1}
              >
                {session.title || '新对话'}
              </Text>
              {/* 状态标签 */}
              {status !== 'idle' && (
                <View style={[styles.statusBadge, { backgroundColor: colors.primary + '20' }]}>
                  <Text style={[styles.statusText, { color: colors.primary }]}>工作中</Text>
                </View>
              )}
            </View>

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

      {/* Delete confirmation modal */}
      <Modal
        visible={showDeleteModal}
        transparent
        animationType="fade"
        onRequestClose={handleCancelDelete}
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: colors.surface }]}>
            <Text style={[styles.modalTitle, { color: colors.text }]}>删除对话</Text>
            <Text style={[styles.modalMessage, { color: colors.textSecondary }]}>
              确定要删除这个对话吗？
            </Text>
            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={[styles.modalButton, { backgroundColor: colors.surfaceContainer }]}
                onPress={handleCancelDelete}
              >
                <Text style={[styles.modalButtonText, { color: colors.text }]}>取消</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalButton, { backgroundColor: colors.error }]}
                onPress={handleConfirmDelete}
              >
                <Text style={styles.modalButtonTextWhite}>删除</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  )
}

export const SessionItem = memo(SessionItemComponent)

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
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  title: {
    fontSize: 15,
    fontWeight: '500',
    lineHeight: 20,
    flex: 1,
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 10,
  },
  statusText: {
    fontSize: 11,
    fontWeight: '600',
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
  // Delete modal styles
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  modalContent: {
    width: '100%',
    maxWidth: 320,
    borderRadius: 16,
    padding: 24,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 8,
    textAlign: 'center',
  },
  modalMessage: {
    fontSize: 15,
    textAlign: 'center',
    marginBottom: 24,
    lineHeight: 22,
  },
  modalButtons: {
    flexDirection: 'row',
    gap: 12,
  },
  modalButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 10,
    alignItems: 'center',
  },
  modalButtonText: {
    fontSize: 16,
    fontWeight: '600',
  },
  modalButtonTextWhite: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
})
