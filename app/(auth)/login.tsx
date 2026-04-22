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

  const [mode, setMode] = useState<'pairing' | 'manual'>('pairing')
  const [pairingCode, setPairingCode] = useState('')
  const [serverAddress, setServerAddress] = useState(serverUrl)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // 配对码格式支持:
  // 1. 局域网: host:port:code (例如: 192.168.1.100:3456:ABC123)
  // 2. 公网隧道: https://xxx.trycloudflare.com:code
  // 3. 纯公网URL+码: https://xxx.trycloudflare.com::ABC123 (双冒号分隔)
  const handlePairingConnect = async () => {
    if (!pairingCode.trim()) {
      setError('请输入配对码')
      return
    }

    setLoading(true)
    setError(null)

    try {
      const input = pairingCode.trim()
      let serverAddr: string
      let code: string

      // 格式1: 公网隧道 URL + 双冒号分隔码 (推荐)
      // 例如: https://xxx.trycloudflare.com::ABC123
      if (input.includes('::')) {
        const [url, pairCode] = input.split('::')
        serverAddr = url.trim()
        code = pairCode.trim().toUpperCase()
      }
      // 格式2: 公网隧道 URL + 单冒号分隔码
      // 例如: https://xxx.trycloudflare.com:ABC123
      else if (input.startsWith('https://') || input.startsWith('http://')) {
        // 找到最后一个冒号位置
        const lastColonIndex = input.lastIndexOf(':')
        if (lastColonIndex > 8) { // 确保不是 http(s):// 后的冒号
          serverAddr = input.substring(0, lastColonIndex)
          code = input.substring(lastColonIndex + 1).toUpperCase()
        } else {
          throw new Error('公网地址格式错误，请使用: https://xxx.trycloudflare.com:ABC123 或 https://xxx.trycloudflare.com::ABC123')
        }
      }
      // 格式3: 局域网地址 host:port:code
      // 例如: 192.168.1.100:3456:ABC123
      else {
        const parts = input.split(':')
        if (parts.length === 3) {
          const [host, port, pairCode] = parts
          serverAddr = `http://${host}:${port}`
          code = pairCode.toUpperCase()
        } else if (parts.length === 4 && (parts[0] === 'http' || parts[0] === 'https')) {
          // 格式: http:host:port:code (已分割)
          const [, host, port, pairCode] = parts
          serverAddr = `http://${host}:${port}`
          code = pairCode.toUpperCase()
        } else {
          throw new Error('配对码格式错误\n局域网: 192.168.1.100:3456:ABC123\n公网: https://xxx.trycloudflare.com:ABC123')
        }
      }

      if (!code || code.length < 4) {
        throw new Error('配对码无效，请检查格式')
      }

      console.log('Connecting to:', serverAddr, 'with code:', code)

      // 验证配对码
      const response = await fetch(`${serverAddr}/api/mobile/pair`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code }),
      })

      if (!response.ok) {
        const data = await response.json().catch(() => ({}))
        throw new Error(data.error || '配对失败，请检查配对码是否正确')
      }

      // 配对成功，保存服务器地址
      setServerUrl(serverAddr)

      login(
        { id: 'mobile-user', email: 'mobile@example.com', name: 'Mobile User' },
        'mobile-token'
      )

      router.replace('/(tabs)/sessions')
    } catch (err) {
      setError(err instanceof Error ? err.message : '连接失败')
    } finally {
      setLoading(false)
    }
  }

  const handleManualConnect = async () => {
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

        {/* Mode tabs */}
        <View style={styles.tabContainer}>
          <TouchableOpacity
            style={[styles.tab, mode === 'pairing' && { borderBottomColor: colors.primary }]}
            onPress={() => setMode('pairing')}
          >
            <Text style={[styles.tabText, { color: mode === 'pairing' ? colors.primary : colors.textSecondary }]}>
              配对码连接
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.tab, mode === 'manual' && { borderBottomColor: colors.primary }]}
            onPress={() => setMode('manual')}
          >
            <Text style={[styles.tabText, { color: mode === 'manual' ? colors.primary : colors.textSecondary }]}>
              手动输入
            </Text>
          </TouchableOpacity>
        </View>

        {mode === 'pairing' ? (
          <View style={styles.form}>
            <Text style={[styles.label, { color: colors.text }]}>配对码</Text>
            <TextInput
              style={[
                styles.input,
                { backgroundColor: colors.surface, color: colors.text, borderColor: colors.border },
              ]}
              value={pairingCode}
              onChangeText={setPairingCode}
              placeholder="粘贴连接串或 IP:端口:配对码"
              placeholderTextColor={colors.textTertiary}
              autoCapitalize="characters"
              autoCorrect={false}
            />
            <Text style={[styles.hint, { color: colors.textTertiary }]}>
              支持局域网或公网隧道连接，在桌面端获取配对码
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
              onPress={handlePairingConnect}
              disabled={loading}
            >
              {loading ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text style={styles.buttonText}>配对连接</Text>
              )}
            </TouchableOpacity>
          </View>
        ) : (
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
              onPress={handleManualConnect}
              disabled={loading}
            >
              {loading ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text style={styles.buttonText}>连接</Text>
              )}
            </TouchableOpacity>
          </View>
        )}

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
              设置 → IM 接入 → 生成配对码
            </Text>
          </View>
          <View style={styles.step}>
            <Text style={[styles.stepNumber, { backgroundColor: colors.primary }]}>3</Text>
            <Text style={[styles.stepText, { color: colors.textSecondary }]}>
              局域网：输入 IP:端口:配对码
            </Text>
          </View>
          <View style={styles.step}>
            <Text style={[styles.stepNumber, { backgroundColor: colors.primary }]}>4</Text>
            <Text style={[styles.stepText, { color: colors.textSecondary }]}>
              公网：粘贴完整连接串
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
    marginBottom: 32,
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
  },
  subtitle: {
    fontSize: 16,
    marginTop: 8,
  },
  tabContainer: {
    flexDirection: 'row',
    marginBottom: 24,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(150, 150, 150, 0.2)',
  },
  tab: {
    flex: 1,
    paddingVertical: 12,
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
    alignItems: 'center',
  },
  tabText: {
    fontSize: 14,
    fontWeight: '600',
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
