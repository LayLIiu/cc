import { View, Text, TouchableOpacity, StyleSheet } from 'react-native'
import { useTheme } from '@/utils/theme'
import type { Session } from '@/types/session'

type SessionItemProps = {
  session: Session
  onPress: () => void
  isActive?: boolean
}

export function SessionItem({ session, onPress, isActive }: SessionItemProps) {
  const { colors } = useTheme()

  const formatTime = (dateStr: string) => {
    const date = new Date(dateStr)
    const now = new Date()
    const diffMs = now.getTime() - date.getTime()
    const diffMins = Math.floor(diffMs / 60000)
    const diffHours = Math.floor(diffMs / 3600000)
    const diffDays = Math.floor(diffMs / 86400000)

    if (diffMins < 1) return '刚刚'
    if (diffMins < 60) return `${diffMins} 分钟前`
    if (diffHours < 24) return `${diffHours} 小时前`
    if (diffDays < 7) return `${diffDays} 天前`
    return date.toLocaleDateString('zh-CN')
  }

  return (
    <TouchableOpacity
      style={[
        styles.container,
        { backgroundColor: colors.surface },
        isActive && { borderLeftWidth: 3, borderLeftColor: colors.primary },
      ]}
      onPress={onPress}
    >
      <View style={styles.content}>
        <Text
          style={[styles.title, { color: colors.text }]}
          numberOfLines={1}
        >
          {session.title || '无标题'}
        </Text>
        <View style={styles.meta}>
          <Text
            style={[styles.project, { color: colors.textTertiary }]}
            numberOfLines={1}
          >
            {session.projectPath?.split('/').pop() || '无项目'}
          </Text>
          <Text style={[styles.time, { color: colors.textTertiary }]}>
            {formatTime(session.modifiedAt)}
          </Text>
        </View>
      </View>
      <Text style={[styles.count, { color: colors.primary }]}>
        {session.messageCount} 条
      </Text>
    </TouchableOpacity>
  )
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderRadius: 12,
    marginBottom: 8,
  },
  content: {
    flex: 1,
  },
  title: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  meta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  project: {
    fontSize: 12,
    flex: 1,
  },
  time: {
    fontSize: 12,
  },
  count: {
    fontSize: 12,
    marginLeft: 8,
  },
})
