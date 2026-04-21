import { useState } from 'react'
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  ActivityIndicator,
  ScrollView,
} from 'react-native'
import { useRouter } from 'expo-router'
import { useAuthStore } from '@/stores/authStore'
import { useTheme } from '@/utils/theme'

export default function LoginScreen() {
  const router = useRouter()
  const { colors } = useTheme()
  const { login, setServerUrl, serverUrl } = useAuthStore()

  const [serverAddress, setServerAddress] = useState(serverUrl)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleConnect = async () => {
    if (!serverAddress.trim()) {
      setError('请输入服务器地址')
      return
    }

    setLoading(true)
    setError(null)

    try {
      // Test connection
      const response = await fetch(`${serverAddress}/api/sessions`, {
        method: 'GET',
      })

      if (!response.ok) {
        throw new Error('无法连接到服务器')
      }

      // Save server URL
      setServerUrl(serverAddress.trim())

      // For now, simulate login (TODO: implement real auth)
      login(
        { id: 'user-1', email: 'user@example.com', name: 'User' },
        'mock-token'
      )

      router.replace('/(tabs)/sessions')
    } catch (err) {
      setError(err instanceof Error ? err.message : '连接失败')
    } finally {
      setLoading(false)
    }
  }

  return (
    <KeyboardAvoidingView
      style={[styles.container, { backgroundColor: colors.background }]}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <ScrollView
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.header}>
          <Text style={[styles.title, { color: colors.text }]}>Claude Code</Text>
          <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
            移动端助手
          </Text>
        </View>

        <View style={styles.form}>
          <Text style={[styles.label, { color: colors.text }]}>服务器地址</Text>
          <TextInput
            style={[
              styles.input,
              { backgroundColor: colors.surface, color: colors.text, borderColor: colors.border },
            ]}
            value={serverAddress}
            onChangeText={setServerAddress}
            placeholder="http://192.168.1.100:3456"
            placeholderTextColor={colors.textTertiary}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
          />
          <Text style={[styles.hint, { color: colors.textTertiary }]}>
            请输入桌面端服务地址（确保手机和电脑在同一网络）
          </Text>

          {error && (
            <View style={styles.errorContainer}>
              <Text style={styles.errorText}>{error}</Text>
            </View>
          )}

          <TouchableOpacity
            style={[
              styles.button,
              { backgroundColor: colors.primary },
              loading && styles.buttonDisabled,
            ]}
            onPress={handleConnect}
            disabled={loading}
          >
            {loading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.buttonText}>连接</Text>
            )}
          </TouchableOpacity>
        </View>

        <View style={styles.instructions}>
          <Text style={[styles.instructionsTitle, { color: colors.text }]}>
            使用步骤
          </Text>
          <View style={styles.step}>
            <Text style={[styles.stepNumber, { backgroundColor: colors.primary }]}>1</Text>
            <Text style={[styles.stepText, { color: colors.textSecondary }]}>
              在电脑上启动 Claude Code 桌面应用
            </Text>
          </View>
          <View style={styles.step}>
            <Text style={[styles.stepNumber, { backgroundColor: colors.primary }]}>2</Text>
            <Text style={[styles.stepText, { color: colors.textSecondary }]}>
              确保手机和电脑连接同一 WiFi
            </Text>
          </View>
          <View style={styles.step}>
            <Text style={[styles.stepNumber, { backgroundColor: colors.primary }]}>3</Text>
            <Text style={[styles.stepText, { color: colors.textSecondary }]}>
              输入电脑的 IP 地址和端口
            </Text>
          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    flexGrow: 1,
    justifyContent: 'center',
    paddingHorizontal: 24,
    paddingVertical: 48,
  },
  header: {
    alignItems: 'center',
    marginBottom: 48,
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
  },
  subtitle: {
    fontSize: 16,
    marginTop: 8,
  },
  form: {
    gap: 12,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    marginBottom: 4,
  },
  input: {
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    borderWidth: 1,
  },
  hint: {
    fontSize: 12,
    marginTop: 4,
  },
  errorContainer: {
    backgroundColor: 'rgba(239, 68, 68, 0.1)',
    borderRadius: 8,
    padding: 12,
    marginTop: 8,
  },
  errorText: {
    color: '#ef4444',
    fontSize: 14,
  },
  button: {
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    marginTop: 16,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
  },
  instructions: {
    marginTop: 48,
    gap: 16,
  },
  instructionsTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 8,
  },
  step: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  stepNumber: {
    width: 24,
    height: 24,
    borderRadius: 12,
    textAlign: 'center',
    lineHeight: 24,
    color: '#fff',
    fontWeight: '600',
    fontSize: 12,
  },
  stepText: {
    fontSize: 14,
    flex: 1,
  },
})
