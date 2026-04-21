import { useEffect, useCallback } from 'react'
import {
  View,
  FlatList,
  RefreshControl,
  ActivityIndicator,
  StyleSheet,
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
    isLoading,
    error,
    fetchSessions,
    setCurrentSession,
  } = useSessionStore()

  useEffect(() => {
    fetchSessions()
  }, [fetchSessions])

  const handleRefresh = useCallback(() => {
    fetchSessions()
  }, [fetchSessions])

  const handleSessionPress = useCallback((sessionId: string) => {
    setCurrentSession(sessionId)
    router.push(`/chat/${sessionId}`)
  }, [setCurrentSession, router])

  if (isLoading && sessions.length === 0) {
    return (
      <View style={[styles.center, { backgroundColor: colors.background }]}>
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    )
  }

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <FlatList
        data={sessions}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <SessionItem
            session={item}
            onPress={() => handleSessionPress(item.id)}
          />
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
            <ActivityIndicator size="small" color={colors.textTertiary} />
          </View>
        }
      />
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
  listContent: {
    padding: 16,
  },
  empty: {
    alignItems: 'center',
    marginTop: 48,
  },
})
