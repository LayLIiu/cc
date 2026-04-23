import { useState } from 'react'
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, TextInput, Modal } from 'react-native'
import { useRouter } from 'expo-router'
import { useAuthStore, type ThemeMode } from '@/stores/authStore'
import { useSessionStore } from '@/stores/sessionStore'
import { useTheme } from '@/utils/theme'

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
  const { user, serverUrl, logout, setServerUrl, themeMode, setThemeMode } = useAuthStore()
  const { sessions } = useSessionStore()

  const [showUrlModal, setShowUrlModal] = useState(false)
  const [showThemeModal, setShowThemeModal] = useState(false)
  const [showLogoutModal, setShowLogoutModal] = useState(false)
  const [tempUrl, setTempUrl] = useState('')

  const handleLogout = () => {
    setShowLogoutModal(true)
  }

  const handleConfirmLogout = () => {
    setShowLogoutModal(false)
    logout()
    router.replace('/(auth)/login')
  }

  const handleEditUrl = () => {
    setTempUrl(serverUrl)
    setShowUrlModal(true)
  }

  const handleSaveUrl = () => {
    if (tempUrl.trim()) {
      // 确保 URL 格式正确
      let url = tempUrl.trim()
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://' + url
      }
      // 移除末尾斜杠
      url = url.replace(/\/+$/, '')
      setServerUrl(url)
      setShowUrlModal(false)
      Alert.alert('成功', `服务器地址已更新为:\n${url}`)
    }
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
          <TouchableOpacity style={styles.urlRow} onPress={handleEditUrl}>
            <View style={styles.urlInfo}>
              <Text style={[styles.label, { color: colors.text }]}>服务器地址</Text>
              <Text
                style={[styles.urlValue, { color: colors.textSecondary }]}
                numberOfLines={2}
              >
                {serverUrl}
              </Text>
            </View>
            <Text style={[styles.editHint, { color: colors.primary }]}>编辑</Text>
          </TouchableOpacity>
        </View>

        <Text style={[styles.hint, { color: colors.textTertiary }]}>
          提示：可以使用 Cloudflare Tunnel 实现远程连接
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

      {/* Edit URL Modal */}
      <Modal
        visible={showUrlModal}
        transparent
        animationType="fade"
        onRequestClose={() => setShowUrlModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: colors.surface }]}>
            <Text style={[styles.modalTitle, { color: colors.text }]}>编辑服务器地址</Text>
            <TextInput
              style={[styles.modalInput, { backgroundColor: colors.background, color: colors.text, borderColor: colors.border }]}
              value={tempUrl}
              onChangeText={setTempUrl}
              placeholder="https://your-tunnel.trycloudflare.com"
              placeholderTextColor={colors.textTertiary}
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType="url"
            />
            <Text style={[styles.modalHint, { color: colors.textTertiary }]}>
              输入本地地址 (如 http://192.168.1.x:3456){'\n'}
              或 Cloudflare Tunnel 地址
            </Text>
            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={[styles.modalButton, { backgroundColor: colors.border }]}
                onPress={() => setShowUrlModal(false)}
              >
                <Text style={[styles.modalButtonText, { color: colors.text }]}>取消</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalButton, { backgroundColor: colors.primary }]}
                onPress={handleSaveUrl}
              >
                <Text style={styles.modalButtonTextWhite}>保存</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* Theme Selection Modal */}
      <Modal
        visible={showThemeModal}
        transparent
        animationType="fade"
        onRequestClose={() => setShowThemeModal(false)}
      >
        <View style={styles.modalOverlay}>
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
        </View>
      </Modal>

      {/* Logout Confirmation Modal */}
      <Modal
        visible={showLogoutModal}
        transparent
        animationType="fade"
        onRequestClose={() => setShowLogoutModal(false)}
      >
        <View style={styles.modalOverlay}>
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
        </View>
      </Modal>
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
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
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
    color: '#fff',
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
