import { View, Text, TouchableOpacity, StyleSheet, Alert, ScrollView } from 'react-native'
import { useRouter } from 'expo-router'
import { useAuthStore } from '@/stores/authStore'
import { useTheme } from '@/utils/theme'

export default function SettingsScreen() {
  const router = useRouter()
  const { colors, isDark } = useTheme()
  const { user, serverUrl, logout } = useAuthStore()

  const handleLogout = () => {
    Alert.alert('退出登录', '确定要退出登录吗？', [
      { text: '取消', style: 'cancel' },
      {
        text: '退出',
        style: 'destructive',
        onPress: () => {
          logout()
          router.replace('/(auth)/login')
        },
      },
    ])
  }

  const handleChangeServer = () => {
    Alert.alert(
      '更换服务器',
      '确定要更换服务器吗？需要重新连接。',
      [
        { text: '取消', style: 'cancel' },
        {
          text: '确定',
          onPress: () => {
            logout()
            router.replace('/(auth)/login')
          },
        },
      ]
    )
  }

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: colors.background }]}
      contentContainerStyle={styles.content}
    >
      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: colors.textSecondary }]}>
          账户
        </Text>
        <View style={[styles.card, { backgroundColor: colors.surface }]}>
          <View style={styles.row}>
            <Text style={[styles.label, { color: colors.text }]}>用户</Text>
            <Text style={[styles.value, { color: colors.textSecondary }]}>
              {user?.name || '未登录'}
            </Text>
          </View>
        </View>
      </View>

      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: colors.textSecondary }]}>
          连接
        </Text>
        <View style={[styles.card, { backgroundColor: colors.surface }]}>
          <View style={styles.row}>
            <Text style={[styles.label, { color: colors.text }]}>服务器地址</Text>
            <Text
              style={[styles.value, { color: colors.textSecondary }]}
              numberOfLines={1}
            >
              {serverUrl}
            </Text>
          </View>
          <TouchableOpacity
            style={[styles.changeButton, { borderTopColor: colors.border }]}
            onPress={handleChangeServer}
          >
            <Text style={[styles.changeText, { color: colors.primary }]}>
              更换服务器
            </Text>
          </TouchableOpacity>
        </View>
      </View>

      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: colors.textSecondary }]}>
          关于
        </Text>
        <View style={[styles.card, { backgroundColor: colors.surface }]}>
          <View style={styles.row}>
            <Text style={[styles.label, { color: colors.text }]}>版本</Text>
            <Text style={[styles.value, { color: colors.textSecondary }]}>1.0.0</Text>
          </View>
          <View style={[styles.row, { borderTopColor: colors.border, borderTopWidth: 1, marginTop: 12, paddingTop: 12 }]}>
            <Text style={[styles.label, { color: colors.text }]}>主题</Text>
            <Text style={[styles.value, { color: colors.textSecondary }]}>
              {isDark ? '深色' : '浅色'} (跟随系统)
            </Text>
          </View>
        </View>
      </View>

      <TouchableOpacity
        style={[styles.logoutButton, { backgroundColor: colors.error }]}
        onPress={handleLogout}
      >
        <Text style={styles.logoutText}>退出登录</Text>
      </TouchableOpacity>

      <Text style={[styles.footer, { color: colors.textTertiary }]}>
        Claude Code Mobile v1.0.0
      </Text>
    </ScrollView>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    padding: 16,
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 8,
  },
  card: {
    borderRadius: 12,
    padding: 16,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  label: {
    fontSize: 16,
  },
  value: {
    fontSize: 14,
    flex: 1,
    textAlign: 'right',
    marginLeft: 16,
  },
  changeButton: {
    marginTop: 12,
    paddingTop: 12,
    alignItems: 'center',
  },
  changeText: {
    fontSize: 14,
    fontWeight: '600',
  },
  logoutButton: {
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    marginTop: 16,
  },
  logoutText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
  },
  footer: {
    textAlign: 'center',
    marginTop: 32,
    fontSize: 12,
  },
})
