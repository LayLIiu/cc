import { useState } from 'react'
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, TextInput, ActivityIndicator } from 'react-native'
import { useRouter } from 'expo-router'
import { useAuthStore, type ThemeMode, type ServerMode } from '@/stores/authStore'
import { useSessionStore } from '@/stores/sessionStore'
import { useTheme } from '@/utils/theme'
import AnimatedModal from '@/components/AnimatedModal'

// 版本信息 - 每次修改后更新
const APP_VERSION = '1.1.0'
const BUILD_TIME = '2026-04-23 09:35'

const THEME_OPTIONS: { mode: ThemeMode; label: string; icon: string }[] = [
  { mode: 'light', label: '浅色', icon: '☀️' },
  { mode: 'dark', label: '深色', icon: '🌙' },
  { mode: 'system', label: '跟随系统', icon: '💻' },
]

export default function SettingsScreen() {
  const router = useRouter()
  const { colors } = useTheme()
  const {
    user,
    serverUrl,
    lanUrl,
    tunnelUrl,
    serverMode,
    logout,
    setLanUrl,
    setTunnelUrl,
    setServerMode,
    themeMode,
    setThemeMode
  } = useAuthStore()
  const { sessions } = useSessionStore()

  const [showLanModal, setShowLanModal] = useState(false)
  const [showTunnelModal, setShowTunnelModal] = useState(false)
  const [showThemeModal, setShowThemeModal] = useState(false)
  const [showLogoutModal, setShowLogoutModal] = useState(false)
  const [tempUrl, setTempUrl] = useState('')

  // 连接速度测试状态
  const [testingLatency, setTestingLatency] = useState(false)
  const [latency, setLatency] = useState<number | null>(null)

  // 测试连接延迟
  const testLatency = async () => {
    if (!serverUrl) return

    setTestingLatency(true)
    setLatency(null)

    try {
      const start = Date.now()
      const controller = new AbortController()
      const timeoutId = setTimeout(() => controller.abort(), 15000)

      const response = await fetch(`${serverUrl}/api/sessions`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
        signal: controller.signal,
      })

      clearTimeout(timeoutId)
      const end = Date.now()
      const duration = end - start

      if (response.ok || response.status === 401) {
        setLatency(duration)
      } else {
        setLatency(-1)
      }
    } catch (err: any) {
      console.log('Latency test error:', err)
      setLatency(-1)
    } finally {
      setTestingLatency(false)
    }
  }

  // 格式化延迟显示
  const formatLatency = (ms: number) => {
    if (ms < 0) return '连接失败'
    if (ms < 100) return `${ms}ms (极快)`
    if (ms < 300) return `${ms}ms (很快)`
    if (ms < 500) return `${ms}ms (较快)`
    if (ms < 1000) return `${ms}ms (一般)`
    return `${ms}ms (较慢)`
  }

  // 获取延迟颜色
  const getLatencyColor = (ms: number) => {
    if (ms < 0) return colors.error
    if (ms < 100) return '#22c55e'
    if (ms < 300) return '#84cc16'
    if (ms < 500) return '#eab308'
    return '#f97316'
  }

  const handleLogout = () => {
    setShowLogoutModal(true)
  }

  const handleConfirmLogout = () => {
    setShowLogoutModal(false)
    logout()
    router.replace('/(auth)/login')
  }

  // 编辑局域网地址
  const handleEditLan = () => {
    setTempUrl(lanUrl)
    setShowLanModal(true)
  }

  // 编辑公网地址
  const handleEditTunnel = () => {
    setTempUrl(tunnelUrl)
    setShowTunnelModal(true)
  }

  // 保存局域网地址
  const handleSaveLan = () => {
    if (tempUrl.trim()) {
      let url = tempUrl.trim()
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://' + url
      }
      url = url.replace(/\/+$/, '')
      setLanUrl(url)
      setShowLanModal(false)
      setLatency(null)
    }
  }

  // 保存公网地址
  const handleSaveTunnel = () => {
    if (tempUrl.trim()) {
      let url = tempUrl.trim()
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://' + url
      }
      url = url.replace(/\/+$/, '')
      setTunnelUrl(url)
      setShowTunnelModal(false)
      setLatency(null)
    }
  }

  // 切换服务器模式
  const handleToggleMode = () => {
    const newMode: ServerMode = serverMode === 'lan' ? 'tunnel' : 'lan'
    // 只有对应地址存在时才能切换
    if (newMode === 'tunnel' && !tunnelUrl) {
      return
    }
    if (newMode === 'lan' && !lanUrl) {
      return
    }
    setServerMode(newMode)
    setLatency(null)
  }

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: colors.background }]}
      contentContainerStyle={styles.content}
    >
      {/* Header Title */}
      <View style={styles.header}>
        <Text style={[styles.headerTitle, { color: colors.text }]}>Claude Code</Text>
      </View>

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

        {/* 服务器切换 */}
        <View style={[styles.card, { backgroundColor: colors.surface }]}>
          {/* 当前模式显示 */}
          <View style={styles.modeRow}>
            <Text style={[styles.label, { color: colors.text }]}>当前网络</Text>
            <View style={styles.modeSwitch}>
              <TouchableOpacity
                style={[
                  styles.modeButton,
                  serverMode === 'lan' && { backgroundColor: colors.primary }
                ]}
                onPress={() => lanUrl && setServerMode('lan')}
                disabled={!lanUrl}
              >
                <Text style={[
                  styles.modeButtonText,
                  { color: serverMode === 'lan' ? '#fff' : colors.textSecondary }
                ]}>
                  局域网
                </Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[
                  styles.modeButton,
                  serverMode === 'tunnel' && { backgroundColor: colors.primary }
                ]}
                onPress={() => tunnelUrl && setServerMode('tunnel')}
                disabled={!tunnelUrl}
              >
                <Text style={[
                  styles.modeButtonText,
                  { color: serverMode === 'tunnel' ? '#fff' : colors.textSecondary }
                ]}>
                  公网
                </Text>
              </TouchableOpacity>
            </View>
          </View>

          <View style={[styles.divider, { backgroundColor: colors.border }]} />

          {/* 局域网地址 */}
          <TouchableOpacity style={styles.urlRow} onPress={handleEditLan}>
            <View style={styles.urlInfo}>
              <Text style={[styles.label, { color: colors.text }]}>局域网地址</Text>
              <Text
                style={[styles.urlValue, { color: lanUrl ? colors.textSecondary : colors.textTertiary }]}
                numberOfLines={1}
              >
                {lanUrl || '未设置'}
              </Text>
            </View>
            <Text style={[styles.editHint, { color: colors.primary }]}>编辑</Text>
          </TouchableOpacity>

          <View style={[styles.divider, { backgroundColor: colors.border }]} />

          {/* 公网地址 */}
          <TouchableOpacity style={styles.urlRow} onPress={handleEditTunnel}>
            <View style={styles.urlInfo}>
              <Text style={[styles.label, { color: colors.text }]}>公网地址</Text>
              <Text
                style={[styles.urlValue, { color: tunnelUrl ? colors.textSecondary : colors.textTertiary }]}
                numberOfLines={1}
              >
                {tunnelUrl || '未设置'}
              </Text>
            </View>
            <Text style={[styles.editHint, { color: colors.primary }]}>编辑</Text>
          </TouchableOpacity>

          <View style={[styles.divider, { backgroundColor: colors.border }]} />

          {/* 当前使用的地址 */}
          <View style={styles.urlRow}>
            <View style={styles.urlInfo}>
              <Text style={[styles.label, { color: colors.text }]}>当前地址</Text>
              <Text
                style={[styles.urlValue, { color: colors.textSecondary }]}
                numberOfLines={1}
              >
                {serverUrl || '未设置'}
              </Text>
            </View>
          </View>

          <View style={[styles.divider, { backgroundColor: colors.border }]} />

          {/* 连接速度 */}
          <TouchableOpacity style={styles.latencyRow} onPress={testLatency} disabled={testingLatency || !serverUrl}>
            <View style={styles.latencyInfo}>
              <Text style={[styles.label, { color: colors.text }]}>连接速度</Text>
              {testingLatency ? (
                <View style={styles.latencyLoading}>
                  <ActivityIndicator size="small" color={colors.primary} />
                  <Text style={[styles.latencyValue, { color: colors.textSecondary, marginLeft: 8 }]}>
                    测试中...
                  </Text>
                </View>
              ) : latency !== null ? (
                <Text style={[styles.latencyValue, { color: getLatencyColor(latency) }]}>
                  {formatLatency(latency)}
                </Text>
              ) : (
                <Text style={[styles.latencyValue, { color: colors.textTertiary }]}>
                  点击测试
                </Text>
              )}
            </View>
            {!testingLatency && serverUrl && (
              <Text style={[styles.editHint, { color: colors.primary }]}>测试</Text>
            )}
          </TouchableOpacity>
        </View>

        <Text style={[styles.hint, { color: colors.textTertiary }]}>
          局域网适合在家使用，公网适合外出使用
        </Text>
      </View>

      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: colors.textSecondary }]}>
          外观
        </Text>
        <View style={[styles.card, { backgroundColor: colors.surface }]}>
          <TouchableOpacity
            style={styles.urlRow}
            onPress={() => setShowThemeModal(true)}
          >
            <View style={styles.urlInfo}>
              <Text style={[styles.label, { color: colors.text }]}>主题</Text>
              <Text style={[styles.urlValue, { color: colors.textSecondary }]}>
                {THEME_OPTIONS.find((o) => o.mode === themeMode)?.label || '跟随系统'}
              </Text>
            </View>
            <Text style={[styles.editHint, { color: colors.primary }]}>选择</Text>
          </TouchableOpacity>
        </View>
      </View>

      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: colors.textSecondary }]}>
          数据管理
        </Text>
        <View style={[styles.card, { backgroundColor: colors.surface }]}>
          <TouchableOpacity style={styles.menuItem} onPress={() => router.push('/import')}>
            <View style={styles.menuIcon}>
              <Text style={styles.menuIconText}>📥</Text>
            </View>
            <View style={styles.menuContent}>
              <Text style={[styles.menuLabel, { color: colors.text }]}>导入对话</Text>
              <Text style={[styles.menuHint, { color: colors.textTertiary }]}>
                从 Cloud Code 导入对话到本地
              </Text>
            </View>
            <Text style={[styles.menuArrow, { color: colors.textTertiary }]}>›</Text>
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
            <Text style={[styles.value, { color: colors.textSecondary }]}>{APP_VERSION}</Text>
          </View>
          <View style={[styles.row, { borderTopColor: colors.border, borderTopWidth: 1, marginTop: 12, paddingTop: 12 }]}>
            <Text style={[styles.label, { color: colors.text }]}>构建时间</Text>
            <Text style={[styles.value, { color: colors.textSecondary }]}>{BUILD_TIME}</Text>
          </View>
          <View style={[styles.row, { borderTopColor: colors.border, borderTopWidth: 1, marginTop: 12, paddingTop: 12 }]}>
            <Text style={[styles.label, { color: colors.text }]}>主题</Text>
            <Text style={[styles.value, { color: colors.textSecondary }]}>
              {THEME_OPTIONS.find(o => o.mode === themeMode)?.label || '跟随系统'}
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
        Claude Code Mobile v{APP_VERSION} ({BUILD_TIME})
      </Text>

      {/* 局域网地址编辑 Modal */}
      <AnimatedModal
        visible={showLanModal}
        onClose={() => setShowLanModal(false)}
      >
        <View style={[styles.modalContent, { backgroundColor: colors.surface }]}>
          <Text style={[styles.modalTitle, { color: colors.text }]}>局域网地址</Text>
          <TextInput
            style={[styles.modalInput, { backgroundColor: colors.background, color: colors.text, borderColor: colors.border }]}
            value={tempUrl}
            onChangeText={setTempUrl}
            placeholder="http://192.168.x.x:3456"
            placeholderTextColor={colors.textTertiary}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
          />
          <Text style={[styles.modalHint, { color: colors.textTertiary }]}>
            输入桌面端的局域网地址{'\n'}
            例如：http://192.168.3.33:3456
          </Text>
          <View style={styles.modalButtons}>
            <TouchableOpacity
              style={[styles.modalButton, { backgroundColor: colors.border }]}
              onPress={() => setShowLanModal(false)}
            >
              <Text style={[styles.modalButtonText, { color: colors.text }]}>取消</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.modalButton, { backgroundColor: colors.primary }]}
              onPress={handleSaveLan}
            >
              <Text style={styles.modalButtonTextWhite}>保存</Text>
            </TouchableOpacity>
          </View>
        </View>
      </AnimatedModal>

      {/* 公网地址编辑 Modal */}
      <AnimatedModal
        visible={showTunnelModal}
        onClose={() => setShowTunnelModal(false)}
      >
        <View style={[styles.modalContent, { backgroundColor: colors.surface }]}>
          <Text style={[styles.modalTitle, { color: colors.text }]}>公网地址</Text>
          <TextInput
            style={[styles.modalInput, { backgroundColor: colors.background, color: colors.text, borderColor: colors.border }]}
            value={tempUrl}
            onChangeText={setTempUrl}
            placeholder="https://xxx.trycloudflare.com"
            placeholderTextColor={colors.textTertiary}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
          />
          <Text style={[styles.modalHint, { color: colors.textTertiary }]}>
            输入 Cloudflare Tunnel 公网地址{'\n'}
            或其他公网代理地址
          </Text>
          <View style={styles.modalButtons}>
            <TouchableOpacity
              style={[styles.modalButton, { backgroundColor: colors.border }]}
              onPress={() => setShowTunnelModal(false)}
            >
              <Text style={[styles.modalButtonText, { color: colors.text }]}>取消</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.modalButton, { backgroundColor: colors.primary }]}
              onPress={handleSaveTunnel}
            >
              <Text style={styles.modalButtonTextWhite}>保存</Text>
            </TouchableOpacity>
          </View>
        </View>
      </AnimatedModal>

      {/* Theme Selection Modal */}
      <AnimatedModal
        visible={showThemeModal}
        onClose={() => setShowThemeModal(false)}
      >
        <View style={[styles.modalContent, { backgroundColor: colors.surface }]}>
          <Text style={[styles.modalTitle, { color: colors.text }]}>选择主题</Text>
          {THEME_OPTIONS.map((opt) => (
            <TouchableOpacity
              key={opt.mode}
              style={[
                styles.themeOption,
                {
                  backgroundColor: themeMode === opt.mode ? colors.primary + '20' : colors.background,
                  borderColor: themeMode === opt.mode ? colors.primary : colors.border,
                },
              ]}
              onPress={() => {
                setThemeMode(opt.mode)
                setShowThemeModal(false)
              }}
            >
              <Text style={styles.themeIcon}>{opt.icon}</Text>
              <Text style={[styles.themeLabel, { color: colors.text }]}>
                {opt.label}
              </Text>
              {themeMode === opt.mode && (
                <Text style={[styles.themeCheck, { color: colors.primary }]}>✓</Text>
              )}
            </TouchableOpacity>
          ))}
          <TouchableOpacity
            style={[styles.modalButton, { backgroundColor: colors.surfaceContainer, marginTop: 8 }]}
            onPress={() => setShowThemeModal(false)}
          >
            <Text style={[styles.modalButtonText, { color: colors.text }]}>取消</Text>
          </TouchableOpacity>
        </View>
      </AnimatedModal>

      {/* Logout Confirmation Modal */}
      <AnimatedModal
        visible={showLogoutModal}
        onClose={() => setShowLogoutModal(false)}
      >
        <View style={[styles.modalContent, { backgroundColor: colors.surface }]}>
          <Text style={[styles.modalTitle, { color: colors.text }]}>退出登录</Text>
          <Text style={[styles.modalMessage, { color: colors.textSecondary }]}>
            确定要退出登录吗？
          </Text>
          <View style={styles.modalButtons}>
            <TouchableOpacity
              style={[styles.modalButton, { backgroundColor: colors.surfaceContainer }]}
              onPress={() => setShowLogoutModal(false)}
            >
              <Text style={[styles.modalButtonText, { color: colors.text }]}>取消</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.modalButton, { backgroundColor: colors.error }]}
              onPress={handleConfirmLogout}
            >
              <Text style={styles.modalButtonTextWhite}>退出</Text>
            </TouchableOpacity>
          </View>
        </View>
      </AnimatedModal>
    </ScrollView>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    padding: 16,
    paddingBottom: 60, // 底部留出 Tab 栏空间
  },
  header: {
    paddingTop: 44,
    alignItems: 'center',
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: '700',
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
  // 模式切换
  modeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  modeSwitch: {
    flexDirection: 'row',
    borderRadius: 8,
    overflow: 'hidden',
  },
  modeButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
  },
  modeButtonText: {
    fontSize: 14,
    fontWeight: '600',
  },
  urlRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  urlInfo: {
    flex: 1,
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
  urlValue: {
    fontSize: 13,
    marginTop: 4,
  },
  editHint: {
    fontSize: 14,
    fontWeight: '600',
    marginLeft: 12,
  },
  divider: {
    height: 1,
    marginVertical: 12,
  },
  latencyRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  latencyInfo: {
    flex: 1,
  },
  latencyLoading: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
  },
  latencyValue: {
    fontSize: 13,
    marginTop: 4,
  },
  hint: {
    fontSize: 12,
    marginTop: 8,
  },
  // Menu item styles
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 4,
  },
  menuIcon: {
    width: 36,
    height: 36,
    borderRadius: 8,
    backgroundColor: 'rgba(99, 102, 241, 0.1)',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  menuIconText: {
    fontSize: 18,
  },
  menuContent: {
    flex: 1,
  },
  menuLabel: {
    fontSize: 15,
    fontWeight: '500',
  },
  menuHint: {
    fontSize: 12,
    marginTop: 2,
  },
  menuArrow: {
    fontSize: 20,
    marginLeft: 8,
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
  // Modal styles
  modalContent: {
    width: '100%',
    maxWidth: 400,
    borderRadius: 16,
    padding: 20,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 16,
    textAlign: 'center',
  },
  modalMessage: {
    fontSize: 15,
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: 8,
  },
  modalInput: {
    borderWidth: 1,
    borderRadius: 10,
    padding: 14,
    fontSize: 15,
  },
  modalHint: {
    fontSize: 12,
    marginTop: 12,
    textAlign: 'center',
  },
  modalButtons: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 20,
  },
  modalButton: {
    flex: 1,
    padding: 14,
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
  // Theme modal styles
  themeOption: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderRadius: 10,
    marginBottom: 8,
    borderWidth: 1,
  },
  themeIcon: {
    fontSize: 20,
    marginRight: 12,
  },
  themeLabel: {
    flex: 1,
    fontSize: 16,
    fontWeight: '500',
  },
  themeCheck: {
    fontSize: 18,
    fontWeight: '600',
  },
})
