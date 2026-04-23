import { useState, useEffect, useCallback } from 'react'
import {
  View,
  FlatList,
  ActivityIndicator,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
} from 'react-native'
import { useRouter } from 'expo-router'
import { useAuthStore } from '@/stores/authStore'
import { useSessionStore } from '@/stores/sessionStore'
import { useTheme } from '@/utils/theme'
import { apiClient } from '@/api/client'
import type { Session } from '@/types/session'

export default function ImportScreen() {
  const router = useRouter()
  const { colors } = useTheme()
  const { sessions: localSessions, importSessions } = useSessionStore()
  const serverUrl = useAuthStore((state) => state.serverUrl)

  const [serverSessions, setServerSessions] = useState<Session[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())
  const [isImporting, setIsImporting] = useState(false)

  // Get local session IDs to show import status
  const localSessionIds = new Set(localSessions.map((s) => s?.id).filter(Boolean))

  useEffect(() => {
    loadServerSessions()
  }, [])

  const loadServerSessions = async () => {
    setIsLoading(true)
    try {
      const sessions = await apiClient.getSessions()
      setServerSessions(sessions)
    } catch (err) {
      Alert.alert('错误', '无法连接服务器，请检查网络设置')
    } finally {
      setIsLoading(false)
    }
  }

  const toggleSelection = useCallback((sessionId: string) => {
    setSelectedIds((prev) => {
      const newSet = new Set(prev)
      if (newSet.has(sessionId)) {
        newSet.delete(sessionId)
      } else {
        newSet.add(sessionId)
      }
      return newSet
    })
  }, [])

  const toggleSelectAll = useCallback(() => {
    // Select all sessions that are not already imported
    const notImported = serverSessions.filter((s) => !localSessionIds.has(s.id))
    if (selectedIds.size === notImported.length) {
      setSelectedIds(new Set())
    } else {
      setSelectedIds(new Set(notImported.map((s) => s.id)))
    }
  }, [serverSessions, localSessionIds, selectedIds.size])

  const handleImport = async () => {
    if (selectedIds.size === 0) {
      Alert.alert('提示', '请选择要导入的对话')
      return
    }

    setIsImporting(true)
    try {
      // 获取选中的会话信息
      const selectedSessions = serverSessions.filter(s => selectedIds.has(s.id))
      const count = await importSessions(Array.from(selectedIds), selectedSessions)
      console.log('[Import] Imported', count, 'sessions')
      Alert.alert('成功', `已导入 ${count} 个对话`)
      router.back()
    } catch (err) {
      console.error('[Import] Failed:', err)
      Alert.alert('错误', '导入失败')
    } finally {
      setIsImporting(false)
    }
  }

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr)
    return date.toLocaleDateString('zh-CN', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  const getProjectName = (projectPath: string) => {
    // Convert sanitized path back to readable name
    const parts = projectPath.replace(/^-/, '').split('-')
    return parts[parts.length - 1] || projectPath
  }

  const renderSession = ({ item }: { item: Session }) => {
    const isSelected = selectedIds.has(item.id)
    const isImported = localSessionIds.has(item.id)
    const messageCount = item.messageCount || 0

    return (
      <TouchableOpacity
        style={[
          styles.sessionItem,
          {
            backgroundColor: isSelected ? colors.primary + '20' : colors.surface,
            borderColor: isSelected ? colors.primary : colors.border,
          },
          isImported && styles.importedItem,
        ]}
        onPress={() => !isImported && toggleSelection(item.id)}
        disabled={isImported}
      >
        <View style={styles.checkbox}>
          {isImported ? (
            <View style={[styles.importedBadge, { backgroundColor: colors.success }]}>
              <Text style={styles.importedText}>已导入</Text>
            </View>
          ) : (
            <View
              style={[
                styles.checkboxInner,
                {
                  backgroundColor: isSelected ? colors.primary : 'transparent',
                  borderColor: isSelected ? colors.primary : colors.border,
                },
              ]}
            >
              {isSelected && <Text style={styles.checkmark}>✓</Text>}
            </View>
          )}
        </View>
        <View style={styles.sessionContent}>
          <Text style={[styles.sessionTitle, { color: colors.text }]} numberOfLines={1}>
            {item.title || '新对话'}
          </Text>
          <View style={styles.sessionMeta}>
            <Text style={[styles.projectName, { color: colors.primary }]}>
              {getProjectName(item.projectPath)}
            </Text>
            <Text style={[styles.sessionMetaText, { color: colors.textTertiary }]}>
              {formatDate(item.modifiedAt)}
            </Text>
            <Text style={[styles.sessionMetaText, { color: colors.textTertiary }]}>
              • {messageCount} 条消息
            </Text>
          </View>
        </View>
      </TouchableOpacity>
    )
  }

  if (isLoading) {
    return (
      <View style={[styles.center, { backgroundColor: colors.background }]}>
        <ActivityIndicator size="large" color={colors.primary} />
        <Text style={[styles.loadingText, { color: colors.textSecondary }]}>
          正在加载服务器对话列表...
        </Text>
      </View>
    )
  }

  // Count sessions that are not yet imported
  const notImportedCount = serverSessions.filter((s) => !localSessionIds.has(s.id)).length

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
          <Text style={[styles.backText, { color: colors.primary }]}>← 返回</Text>
        </TouchableOpacity>
        <Text style={[styles.title, { color: colors.text }]}>导入对话</Text>
        <TouchableOpacity onPress={toggleSelectAll}>
          <Text style={[styles.selectAllText, { color: colors.primary }]}>
            {selectedIds.size === notImportedCount ? '取消' : '全选'}
          </Text>
        </TouchableOpacity>
      </View>

      {/* Server URL */}
      <View style={[styles.serverInfo, { backgroundColor: colors.surface }]}>
        <Text style={[styles.serverLabel, { color: colors.textSecondary }]}>服务器:</Text>
        <Text style={[styles.serverUrl, { color: colors.textTertiary }]} numberOfLines={1}>
          {serverUrl}
        </Text>
      </View>

      {/* Stats */}
      <View style={[styles.statsBox, { backgroundColor: colors.surface }]}>
        <Text style={[styles.statsText, { color: colors.textSecondary }]}>
          共 {serverSessions.length} 个对话，{notImportedCount} 个未导入
        </Text>
      </View>

      {/* List */}
      <FlatList
        data={serverSessions}
        keyExtractor={(item) => item.id}
        renderItem={renderSession}
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={[styles.emptyText, { color: colors.textSecondary }]}>
              暂无可导入的对话
            </Text>
            <TouchableOpacity style={styles.retryButton} onPress={loadServerSessions}>
              <Text style={[styles.retryText, { color: colors.primary }]}>重新加载</Text>
            </TouchableOpacity>
          </View>
        }
      />

      {/* Footer */}
      <View style={[styles.footer, { backgroundColor: colors.surface, borderTopColor: colors.border }]}>
        <Text style={[styles.selectedCount, { color: colors.textSecondary }]}>
          已选择 {selectedIds.size} 个对话
        </Text>
        <TouchableOpacity
          style={[
            styles.importButton,
            { backgroundColor: selectedIds.size > 0 ? colors.primary : colors.border },
          ]}
          onPress={handleImport}
          disabled={selectedIds.size === 0 || isImporting}
        >
          {isImporting ? (
            <ActivityIndicator color="#fff" size="small" />
          ) : (
            <Text style={styles.importButtonText}>导入选中</Text>
          )}
        </TouchableOpacity>
      </View>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 12,
    fontSize: 14,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(150, 150, 150, 0.2)',
  },
  backButton: {
    padding: 4,
  },
  backText: {
    fontSize: 16,
  },
  title: {
    fontSize: 18,
    fontWeight: '600',
  },
  selectAllText: {
    fontSize: 14,
  },
  serverInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(150, 150, 150, 0.1)',
  },
  serverLabel: {
    fontSize: 12,
    marginRight: 8,
  },
  serverUrl: {
    fontSize: 12,
    flex: 1,
  },
  statsBox: {
    padding: 12,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(150, 150, 150, 0.1)',
  },
  statsText: {
    fontSize: 13,
  },
  listContent: {
    padding: 16,
    paddingBottom: 100,
  },
  sessionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    borderRadius: 12,
    marginBottom: 8,
    borderWidth: 1,
  },
  importedItem: {
    opacity: 0.6,
  },
  checkbox: {
    marginRight: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkboxInner: {
    width: 24,
    height: 24,
    borderRadius: 12,
    borderWidth: 2,
    justifyContent: 'center',
    alignItems: 'center',
  },
  checkmark: {
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold',
  },
  importedBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  importedText: {
    color: '#fff',
    fontSize: 11,
    fontWeight: '500',
  },
  sessionContent: {
    flex: 1,
  },
  sessionTitle: {
    fontSize: 15,
    fontWeight: '500',
    marginBottom: 4,
  },
  sessionMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    flexWrap: 'wrap',
  },
  projectName: {
    fontSize: 11,
    fontWeight: '500',
  },
  sessionMetaText: {
    fontSize: 12,
  },
  empty: {
    alignItems: 'center',
    marginTop: 40,
  },
  emptyText: {
    fontSize: 16,
  },
  retryButton: {
    marginTop: 16,
    padding: 8,
  },
  retryText: {
    fontSize: 14,
    fontWeight: '500',
  },
  footer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
    borderTopWidth: 1,
  },
  selectedCount: {
    fontSize: 14,
  },
  importButton: {
    borderRadius: 10,
    paddingVertical: 12,
    paddingHorizontal: 24,
  },
  importButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
})
