import { useEffect, useCallback, useState } from 'react'
import { useFocusEffect, useLocalSearchParams } from 'expo-router'
import {
  View,
  FlatList,
  RefreshControl,
  ActivityIndicator,
  Text,
  StyleSheet,
  TouchableOpacity,
  Modal,
  TextInput,
  ScrollView,
  Alert,
} from 'react-native'
import { useRouter } from 'expo-router'
import { useSessionStore } from '@/stores/sessionStore'
import { SessionItem } from '@/components/SessionItem'
import { useTheme } from '@/utils/theme'

export default function SessionsScreen() {
  const router = useRouter()
  const { colors } = useTheme()

  const {
    sessions,
    recentProjects,
    isLoading,
    isCreating,
    error,
    fetchSessions,
    setCurrentSession,
    createSession,
    deleteSession,
    fetchRecentProjects,
  } = useSessionStore()

  const [showNewModal, setShowNewModal] = useState(false)
  const [customPath, setCustomPath] = useState('')

  useEffect(() => {
    fetchRecentProjects()
  }, [fetchRecentProjects])

  useFocusEffect(
    useCallback(() => {
      console.log('[Sessions] Page focused, fetching sessions...')
      fetchSessions()
    }, [fetchSessions])
  )

  const handleRefresh = useCallback(() => {
    fetchSessions()
    fetchRecentProjects()
  }, [fetchSessions, fetchRecentProjects])

  const handleSessionPress = useCallback((sessionId: string) => {
    setCurrentSession(sessionId)
    router.push(`/chat/${sessionId}`)
  }, [setCurrentSession, router])

  const handleNewSession = useCallback(() => {
    setShowNewModal(true)
    setCustomPath('')
  }, [])

  const handleSelectProject = useCallback(async (projectPath?: string) => {
    const workDir = projectPath || customPath.trim()
    if (customPath.trim() && !projectPath) {
      // Use custom path
    }

    setShowNewModal(false)
    const sessionId = await createSession(workDir || undefined)
    if (sessionId) {
      setCurrentSession(sessionId)
      router.push(`/chat/${sessionId}`)
    }
  }, [createSession, setCurrentSession, router, customPath])

  const handleCreateWithCustomPath = useCallback(() => {
    if (!customPath.trim()) {
      Alert.alert('提示', '请输入项目路径')
      return
    }
    handleSelectProject(customPath.trim())
  }, [customPath, handleSelectProject])

  const handleDeleteSession = useCallback(async (sessionId: string) => {
    try {
      await deleteSession(sessionId)
    } catch (err) {
      Alert.alert('删除失败', err instanceof Error ? err.message : '无法删除对话')
    }
  }, [deleteSession])

  // Group sessions by date
  const groupedSessions = useCallback(() => {
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const yesterday = new Date(today)
    yesterday.setDate(yesterday.getDate() - 1)

    const lastWeek = new Date(today)
    lastWeek.setDate(lastWeek.getDate() - 7)

    const groups: { title: string; data: typeof sessions }[] = [
      { title: '今天', data: [] },
      { title: '昨天', data: [] },
      { title: '最近7天', data: [] },
      { title: '更早', data: [] },
    ]

    sessions.filter((s): s is NonNullable<typeof s> => s != null).forEach(session => {
      const date = new Date(session.modifiedAt)
      date.setHours(0, 0, 0, 0)

      if (date.getTime() >= today.getTime()) {
        groups[0].data.push(session)
      } else if (date.getTime() >= yesterday.getTime()) {
        groups[1].data.push(session)
      } else if (date.getTime() >= lastWeek.getTime()) {
        groups[2].data.push(session)
      } else {
        groups[3].data.push(session)
      }
    })

    return groups.filter(g => g.data.length > 0)
  }, [sessions])

  if (isLoading && sessions.length === 0) {
    return (
      <View style={[styles.center, { backgroundColor: colors.background }]}>
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    )
  }

  // Show error state when server is unreachable
  if (error && sessions.length === 0) {
    return (
      <View style={[styles.center, { backgroundColor: colors.background }]}>
        <Text style={[styles.errorTitle, { color: colors.text }]}>无法连接服务器</Text>
        <Text style={[styles.errorMessage, { color: colors.textSecondary }]}>
          {error}
        </Text>
        <Text style={[styles.errorHint, { color: colors.textTertiary }]}>
          请在设置中检查服务器地址
        </Text>
        <TouchableOpacity
          style={[styles.retryButton, { backgroundColor: colors.primary }]}
          onPress={() => router.push('/(tabs)/settings')}
        >
          <Text style={styles.retryButtonText}>前往设置</Text>
        </TouchableOpacity>
      </View>
    )
  }

  const groups = groupedSessions()

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      {/* New Session Button */}
      <View style={styles.header}>
        <Text style={[styles.pageTitle, { color: colors.text }]}>Claude Code</Text>
        <TouchableOpacity
          style={[styles.newButton, { backgroundColor: colors.primary }]}
          onPress={handleNewSession}
        >
          <Text style={styles.newButtonText}>+ 新建对话</Text>
        </TouchableOpacity>
      </View>

      <FlatList
        data={groups}
        keyExtractor={(item) => item.title}
        style={{ backgroundColor: colors.background }}
        renderItem={({ item: group }) => (
          <View style={styles.section}>
            <Text style={[styles.sectionTitle, { color: colors.textTertiary }]}>
              {group.title}
            </Text>
            <View style={[styles.sectionContent, { borderColor: colors.border }]}>
              {group.data.map((session, index) => (
                <View key={session?.id}>
                  <SessionItem
                    session={session}
                    onPress={() => session?.id && handleSessionPress(session.id)}
                    onDelete={() => session?.id && handleDeleteSession(session.id)}
                  />
                  {index < group.data.length - 1 && (
                    <View style={[styles.separator, { backgroundColor: colors.border }]} />
                  )}
                </View>
              ))}
            </View>
          </View>
        )}
        contentContainerStyle={styles.listContent}
        refreshControl={
          <RefreshControl
            refreshing={isLoading}
            onRefresh={handleRefresh}
            tintColor={colors.primary}
          />
        }
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={[styles.emptyTitle, { color: colors.textSecondary }]}>
              暂无对话
            </Text>
            <Text style={[styles.emptySubtitle, { color: colors.textTertiary }]}>
              点击上方"新建对话"开始
            </Text>
          </View>
        }
      />

      {/* New Session Modal */}
      <Modal
        visible={showNewModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowNewModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: colors.surface }]}>
            <View style={styles.modalHeader}>
              <Text style={[styles.modalTitle, { color: colors.text }]}>新建对话</Text>
              <TouchableOpacity onPress={() => setShowNewModal(false)}>
                <Text style={[styles.modalClose, { color: colors.textSecondary }]}>关闭</Text>
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.modalBody}>
              {/* Custom path input */}
              <Text style={[styles.inputLabel, { color: colors.textSecondary }]}>
                自定义项目路径
              </Text>
              <TextInput
                style={[styles.textInput, { backgroundColor: colors.background, color: colors.text, borderColor: colors.border }]}
                value={customPath}
                onChangeText={setCustomPath}
                placeholder="/Users/xxx/projects/my-project"
                placeholderTextColor={colors.textTertiary}
                autoCapitalize="none"
                autoCorrect={false}
              />
              <TouchableOpacity
                style={[styles.createButton, { backgroundColor: colors.primary, opacity: isCreating ? 0.6 : 1 }]}
                onPress={handleCreateWithCustomPath}
                disabled={isCreating}
              >
                {isCreating ? (
                  <ActivityIndicator color="#fff" size="small" />
                ) : (
                  <Text style={styles.createButtonText}>创建对话</Text>
                )}
              </TouchableOpacity>

              {/* Recent projects */}
              {recentProjects.length > 0 && (
                <View style={styles.recentSection}>
                  <Text style={[styles.recentTitle, { color: colors.textSecondary }]}>
                    或选择最近的项目
                  </Text>
                  {recentProjects.map((project) => (
                    <TouchableOpacity
                      key={project.projectPath}
                      style={[styles.projectItem, { backgroundColor: colors.background, borderColor: colors.border }]}
                      onPress={() => handleSelectProject(project.realPath)}
                      disabled={isCreating}
                    >
                      <View style={styles.projectInfo}>
                        <Text style={[styles.projectName, { color: colors.text }]} numberOfLines={1}>
                          {project.projectName}
                        </Text>
                        <Text style={[styles.projectPath, { color: colors.textTertiary }]} numberOfLines={1}>
                          {project.projectPath}
                        </Text>
                      </View>
                      {project.isGit && (
                        <View style={styles.gitBadge}>
                          <Text style={styles.gitText}>
                            {project.repoName} ({project.branch})
                          </Text>
                        </View>
                      )}
                    </TouchableOpacity>
                  ))}
                </View>
              )}
            </ScrollView>
          </View>
        </View>
      </Modal>
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
    padding: 20,
  },
  errorTitle: {
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 8,
  },
  errorMessage: {
    fontSize: 14,
    textAlign: 'center',
    marginBottom: 12,
  },
  errorHint: {
    fontSize: 12,
    marginBottom: 20,
  },
  retryButton: {
    borderRadius: 10,
    paddingVertical: 12,
    paddingHorizontal: 24,
  },
  retryButtonText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '500',
  },
  header: {
    padding: 16,
    paddingBottom: 0,
  },
  pageTitle: {
    fontSize: 28,
    fontWeight: '700',
    marginBottom: 12,
  },
  newButton: {
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
  },
  newButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  listContent: {
    padding: 16,
    paddingTop: 8,
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginBottom: 8,
    marginLeft: 4,
  },
  sectionContent: {
    borderRadius: 12,
    borderWidth: 1,
    overflow: 'hidden',
  },
  separator: {
    height: 1,
    marginLeft: 60,
  },
  empty: {
    alignItems: 'center',
    marginTop: 60,
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: '500',
    marginBottom: 8,
  },
  emptySubtitle: {
    fontSize: 14,
  },
  // Modal styles
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    maxHeight: '80%',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(150, 150, 150, 0.2)',
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
  },
  modalClose: {
    fontSize: 14,
  },
  modalBody: {
    padding: 16,
  },
  inputLabel: {
    fontSize: 14,
    fontWeight: '500',
    marginBottom: 8,
  },
  textInput: {
    borderWidth: 1,
    borderRadius: 10,
    padding: 14,
    fontSize: 15,
  },
  createButton: {
    borderRadius: 10,
    padding: 14,
    alignItems: 'center',
    marginTop: 12,
  },
  createButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  recentSection: {
    marginTop: 24,
  },
  recentTitle: {
    fontSize: 14,
    fontWeight: '500',
    marginBottom: 12,
  },
  projectItem: {
    borderRadius: 10,
    padding: 12,
    marginBottom: 8,
    borderWidth: 1,
  },
  projectInfo: {
    flex: 1,
  },
  projectName: {
    fontSize: 15,
    fontWeight: '500',
    marginBottom: 2,
  },
  projectPath: {
    fontSize: 12,
  },
  gitBadge: {
    marginTop: 6,
    alignSelf: 'flex-start',
  },
  gitText: {
    fontSize: 11,
    color: '#8b5cf6',
  },
})
