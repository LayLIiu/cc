import { useEffect, useState } from 'react'
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Alert, TextInput } from 'react-native'
import { SafeAreaView } from 'react-native-safe-area-context'
import { useTheme } from '@/utils/theme'
import { useProviderStore } from '@/stores/providerStore'
import { useAuthStore } from '@/stores/authStore'
import { apiClient } from '@/api/client'
import { PROVIDER_PRESETS, API_FORMAT_LABELS } from '@/config/providerPresets'
import type { CreateProviderInput, UpdateProviderInput, ApiFormat, ModelMapping, SavedProvider } from '@/types/provider'
import { ActivityIndicator, Modal } from 'react-native'

export default function ProvidersScreen() {
  const { colors } = useTheme()
  const { serverUrl } = useAuthStore()
  const {
    providers,
    activeProviderId,
    isLoading,
    error,
    loadProviders,
    createProvider,
    updateProvider,
    deleteProvider,
    activateProvider,
    activateOfficial,
    setError,
  } = useProviderStore()

  const [showAddModal, setShowAddModal] = useState(false)
  const [selectedPreset, setSelectedPreset] = useState<string | null>(null)
  const [editingProvider, setEditingProvider] = useState<SavedProvider | null>(null)
  const [formData, setFormData] = useState<Partial<CreateProviderInput>>({})
  const [testingId, setTestingId] = useState<string | null>(null)

  // Network settings states
  const [pairingCode, setPairingCode] = useState<string | null>(null)
  const [pairingCodeExpiry, setPairingCodeExpiry] = useState<string | null>(null)
  const [networkInfo, setNetworkInfo] = useState<{ lanUrl: string; tunnelUrl: string; tunnelEnabled: boolean } | null>(null)
  const [loadingPairingCode, setLoadingPairingCode] = useState(false)
  const [loadingNetworkInfo, setLoadingNetworkInfo] = useState(false)
  const [enablingTunnel, setEnablingTunnel] = useState(false)

  useEffect(() => {
    loadProviders().catch(() => {})
    loadNetworkInfo().catch(() => {})
  }, [])

  // Load network info
  const loadNetworkInfo = async () => {
    if (!serverUrl) return
    setLoadingNetworkInfo(true)
    try {
      const info = await apiClient.getNetworkInfo()
      setNetworkInfo(info)
    } catch (err) {
      // API 不存在或其他错误，设置默认值
      console.log('Failed to load network info:', err)
      setNetworkInfo({ lanUrl: '', tunnelUrl: '', tunnelEnabled: false })
    } finally {
      setLoadingNetworkInfo(false)
    }
  }

  // Generate pairing code
  const handleGeneratePairingCode = async () => {
    setLoadingPairingCode(true)
    try {
      const result = await apiClient.getPairingCode()
      setPairingCode(result.pairingCode)
      setPairingCodeExpiry(result.expiresAt)
      Alert.alert('配对码已生成', `配对码: ${result.pairingCode}\n请在桌面端输入此配对码进行连接`)
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : '生成配对码失败'
      if (errorMsg.includes('暂不支持')) {
        Alert.alert('功能暂不可用', '桌面端版本可能需要更新以支持此功能')
      } else {
        Alert.alert('生成失败', errorMsg)
      }
    } finally {
      setLoadingPairingCode(false)
    }
  }

  // Toggle tunnel
  const handleToggleTunnel = async (enabled: boolean) => {
    setEnablingTunnel(true)
    try {
      const result = await apiClient.enableTunnel(enabled)
      await loadNetworkInfo()
      if (result.tunnelUrl) {
        Alert.alert(
          enabled ? '公网隧道已开启' : '公网隧道已关闭',
          enabled ? `公网地址: ${result.tunnelUrl}` : ''
        )
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : '设置隧道失败'
      if (errorMsg.includes('暂不支持')) {
        Alert.alert('功能暂不可用', '桌面端版本可能需要更新以支持此功能')
      } else {
        Alert.alert('操作失败', errorMsg)
      }
    } finally {
      setEnablingTunnel(false)
    }
  }

  // Copy pairing code
  const handleCopyPairingCode = () => {
    if (pairingCode) {
      Alert.alert('配对码', pairingCode)
    }
  }

  const handleSelectPreset = (presetId: string) => {
    const preset = PROVIDER_PRESETS.find(p => p.id === presetId)
    if (preset) {
      setSelectedPreset(presetId)
      setFormData({
        presetId: preset.id,
        name: preset.name,
        baseUrl: preset.baseUrl,
        apiKey: '',
        apiFormat: preset.apiFormat,
        models: preset.defaultModels,
      })
    }
  }

  const handleSaveProvider = async () => {
    if (!formData.presetId || !formData.name || !formData.apiKey) {
      setError('请填写所有必填字段')
      return
    }

    try {
      if (editingProvider) {
        await updateProvider(editingProvider.id, formData as UpdateProviderInput)
      } else {
        await createProvider(formData as CreateProviderInput)
      }
      setShowAddModal(false)
      setEditingProvider(null)
      setFormData({})
      setSelectedPreset(null)
    } catch (err) {
      // Error already set in store
    }
  }

  const handleDelete = (id: string) => {
    Alert.alert('确认删除', '确定要删除这个服务商吗？', [
      { text: '取消', style: 'cancel' },
      {
        text: '删除',
        style: 'destructive',
        onPress: () => deleteProvider(id).catch(() => {}),
      },
    ])
  }

  const handleActivate = (id: string) => {
    activateProvider(id).catch(() => {})
  }

  const handleActivateOfficial = () => {
    Alert.alert('确认切换', '切换到官方认证可能需要重新登录', [
      { text: '取消', style: 'cancel' },
      {
        text: '确认',
        onPress: () => activateOfficial().catch(() => {}),
      },
    ])
  }

  const handleTest = async (id: string) => {
    setTestingId(id)
    try {
      const { result } = await apiClient.testProvider(id)
      const success = result.connectivity.success
      Alert.alert(
        success ? '测试成功' : '测试失败',
        success
          ? `延迟: ${result.connectivity.latencyMs}ms`
          : result.connectivity.error || '连接失败'
      )
    } catch (err) {
      Alert.alert('测试失败', err instanceof Error ? err.message : '未知错误')
    } finally {
      setTestingId(null)
    }
  }

  const openAddModal = () => {
    setEditingProvider(null)
    setSelectedPreset(null)
    setFormData({})
    setShowAddModal(true)
  }

  const openEditModal = (provider: SavedProvider) => {
    setEditingProvider(provider)
    setSelectedPreset(provider.presetId)
    setFormData({
      name: provider.name,
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
      apiFormat: provider.apiFormat,
      models: provider.models,
      notes: provider.notes,
    })
    setShowAddModal(true)
  }

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
      <View style={[styles.header, { borderBottomColor: colors.border }]}>
        <Text style={[styles.title, { color: colors.text }]}>服务商</Text>
        <TouchableOpacity
          style={[styles.addButton, { backgroundColor: colors.primary }]}
          onPress={openAddModal}
        >
          <Text style={styles.addButtonText}>+ 添加</Text>
        </TouchableOpacity>
      </View>

      {error && (
        <View style={[styles.errorBox, { backgroundColor: colors.error + '20' }]}>
          <Text style={[styles.errorText, { color: colors.error }]}>{error}</Text>
          <TouchableOpacity onPress={() => setError(null)}>
            <Text style={[styles.closeError, { color: colors.text }]}>×</Text>
          </TouchableOpacity>
        </View>
      )}

      <ScrollView style={styles.scroll} contentContainerStyle={{ paddingBottom: 80 }}>
        {/* Network & Pairing Code Section */}
        <View style={[styles.section, { backgroundColor: colors.surface }]}>
          <Text style={[styles.sectionTitle, { color: colors.textSecondary }]}>连接设置</Text>

          {/* Pairing Code */}
          <TouchableOpacity
            style={[styles.settingRow, { borderBottomColor: colors.border }]}
            onPress={handleGeneratePairingCode}
            disabled={loadingPairingCode}
          >
            <View style={styles.settingInfo}>
              <Text style={[styles.settingLabel, { color: colors.text }]}>配对码</Text>
              <Text style={[styles.settingDesc, { color: colors.textSecondary }]}>
                生成配对码连接桌面端
              </Text>
            </View>
            {loadingPairingCode ? (
              <ActivityIndicator size="small" color={colors.primary} />
            ) : pairingCode ? (
              <TouchableOpacity onPress={handleCopyPairingCode}>
                <Text style={[styles.pairingCodeText, { color: colors.primary }]}>
                  {pairingCode}
                </Text>
              </TouchableOpacity>
            ) : (
              <Text style={[styles.settingAction, { color: colors.primary }]}>生成</Text>
            )}
          </TouchableOpacity>

          {/* LAN URL */}
          <View style={[styles.settingRow, { borderBottomColor: colors.border }]}>
            <View style={styles.settingInfo}>
              <Text style={[styles.settingLabel, { color: colors.text }]}>局域网地址</Text>
              {loadingNetworkInfo ? (
                <ActivityIndicator size="small" color={colors.textTertiary} />
              ) : (
                <Text style={[styles.settingValue, { color: colors.textSecondary }]} numberOfLines={1}>
                  {serverUrl ? `${serverUrl} (当前连接)` : '未设置'}
                </Text>
              )}
            </View>
          </View>

          {/* Tunnel URL */}
          <View style={styles.settingRow}>
            <View style={styles.settingInfo}>
              <Text style={[styles.settingLabel, { color: colors.text }]}>公网隧道</Text>
              {loadingNetworkInfo ? (
                <ActivityIndicator size="small" color={colors.textTertiary} />
              ) : (
                <Text style={[styles.settingValue, { color: colors.textSecondary }]} numberOfLines={1}>
                  {networkInfo?.tunnelUrl || '未开启'}
                </Text>
              )}
            </View>
            <TouchableOpacity
              style={[
                styles.toggleButton,
                networkInfo?.tunnelEnabled ? { backgroundColor: colors.primary } : { backgroundColor: colors.border }
              ]}
              onPress={() => handleToggleTunnel(!networkInfo?.tunnelEnabled)}
              disabled={enablingTunnel || !serverUrl}
            >
              {enablingTunnel ? (
                <ActivityIndicator size="small" color={networkInfo?.tunnelEnabled ? '#fff' : colors.textTertiary} />
              ) : (
                <Text style={[
                  styles.toggleButtonText,
                  { color: networkInfo?.tunnelEnabled ? '#fff' : colors.textSecondary }
                ]}>
                  {networkInfo?.tunnelEnabled ? '已开启' : '开启'}
                </Text>
              )}
            </TouchableOpacity>
          </View>
        </View>

        <View style={[styles.section, { backgroundColor: colors.surface }]}>
          <Text style={[styles.sectionTitle, { color: colors.textSecondary }]}>官方认证</Text>
          <TouchableOpacity
            style={[
              styles.providerCard,
              activeProviderId === null && styles.activeCard,
              { backgroundColor: activeProviderId === null ? colors.primary + '10' : colors.background },
            ]}
            onPress={handleActivateOfficial}
          >
            <View style={styles.providerInfo}>
              <Text style={[styles.providerName, { color: colors.text }]}>Claude Official</Text>
              <Text style={[styles.providerDesc, { color: colors.textSecondary }]}>
                使用官方 Anthropic 认证
              </Text>
            </View>
            {activeProviderId === null && (
              <View style={[styles.activeBadge, { backgroundColor: colors.primary }]}>
                <Text style={styles.activeBadgeText}>当前</Text>
              </View>
            )}
          </TouchableOpacity>
        </View>

        <View style={[styles.section, { backgroundColor: colors.surface }]}>
          <Text style={[styles.sectionTitle, { color: colors.textSecondary }]}>自定义服务商</Text>
          {providers.length === 0 && !isLoading && (
            <View style={styles.empty}>
              <Text style={[styles.emptyText, { color: colors.textSecondary }]}>
                暂无自定义服务商，点击上方添加
              </Text>
            </View>
          )}
          {providers.map(provider => (
            <View
              key={provider.id}
              style={[
                styles.providerCard,
                activeProviderId === provider.id && styles.activeCard,
                { backgroundColor: activeProviderId === provider.id ? colors.primary + '10' : colors.background },
              ]}
            >
              <TouchableOpacity
                style={styles.providerMain}
                onPress={() => openEditModal(provider)}
              >
                <View style={styles.providerInfo}>
                  <Text style={[styles.providerName, { color: colors.text }]}>{provider.name}</Text>
                  <Text style={[styles.providerDesc, { color: colors.textSecondary }]}>
                    {API_FORMAT_LABELS[provider.apiFormat]}
                  </Text>
                </View>
                {activeProviderId === provider.id && (
                  <View style={[styles.activeBadge, { backgroundColor: colors.primary }]}>
                    <Text style={styles.activeBadgeText}>当前</Text>
                  </View>
                )}
              </TouchableOpacity>
              <View style={styles.providerActions}>
                <TouchableOpacity
                  style={[styles.actionButton, { borderColor: colors.border }]}
                  onPress={() => handleActivate(provider.id)}
                  disabled={activeProviderId === provider.id}
                >
                  <Text style={[styles.actionText, { color: colors.textSecondary }]}>
                    {activeProviderId === provider.id ? '已激活' : '激活'}
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.actionButton, { borderColor: colors.border }]}
                  onPress={() => handleTest(provider.id)}
                  disabled={testingId === provider.id}
                >
                  {testingId === provider.id ? (
                    <ActivityIndicator size="small" color={colors.primary} />
                  ) : (
                    <Text style={[styles.actionText, { color: colors.textSecondary }]}>测试</Text>
                  )}
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.actionButton, { borderColor: colors.border }]}
                  onPress={() => handleDelete(provider.id)}
                >
                  <Text style={[styles.actionText, { color: colors.error }]}>删除</Text>
                </TouchableOpacity>
              </View>
            </View>
          ))}
        </View>

        {isLoading && (
          <View style={styles.loading}>
            <ActivityIndicator color={colors.primary} />
          </View>
        )}
      </ScrollView>

      <Modal
        visible={showAddModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowAddModal(false)}
      >
        <View style={[styles.modalOverlay, { backgroundColor: 'rgba(0,0,0,0.5)' }]}>
          <View style={[styles.modalContent, { backgroundColor: colors.surface }]}>
            <Text style={[styles.modalTitle, { color: colors.text }]}>
              {editingProvider ? '编辑服务商' : '添加服务商'}
            </Text>

            {!editingProvider && (
              <>
                <Text style={[styles.label, { color: colors.textSecondary }]}>选择预设</Text>
                <ScrollView horizontal style={styles.presetScroll}>
                  {PROVIDER_PRESETS.filter(p => p.id !== 'custom').map(preset => (
                    <TouchableOpacity
                      key={preset.id}
                      style={[
                        styles.presetCard,
                        selectedPreset === preset.id && {
                          backgroundColor: colors.primary + '20',
                          borderColor: colors.primary,
                        },
                        { backgroundColor: colors.background, borderColor: colors.border },
                      ]}
                      onPress={() => handleSelectPreset(preset.id)}
                    >
                      <Text style={[styles.presetName, { color: colors.text }]}>{preset.name}</Text>
                    </TouchableOpacity>
                  ))}
                </ScrollView>
              </>
            )}

            <Text style={[styles.label, { color: colors.textSecondary }]}>名称</Text>
            <TextInput
              style={[styles.input, { backgroundColor: colors.background, color: colors.text, borderColor: colors.border }]}
              value={formData.name || ''}
              onChangeText={text => setFormData({ ...formData, name: text })}
              placeholder="服务商名称"
            />

            <Text style={[styles.label, { color: colors.textSecondary }]}>API Key</Text>
            <TextInput
              style={[styles.input, { backgroundColor: colors.background, color: colors.text, borderColor: colors.border }]}
              value={formData.apiKey || ''}
              onChangeText={text => setFormData({ ...formData, apiKey: text })}
              placeholder="输入 API Key"
              secureTextEntry
            />

            <Text style={[styles.label, { color: colors.textSecondary }]}>Base URL</Text>
            <TextInput
              style={[styles.input, { backgroundColor: colors.background, color: colors.text, borderColor: colors.border }]}
              value={formData.baseUrl || ''}
              onChangeText={text => setFormData({ ...formData, baseUrl: text })}
              placeholder="https://api.example.com"
            />

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={[styles.modalButton, styles.cancelButton, { borderColor: colors.border }]}
                onPress={() => setShowAddModal(false)}
              >
                <Text style={[styles.modalButtonText, { color: colors.text }]}>取消</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalButton, styles.saveButton, { backgroundColor: colors.primary }]}
                onPress={handleSaveProvider}
              >
                <Text style={[styles.modalButtonText, styles.saveButtonText]}>保存</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
  },
  addButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
  },
  addButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  errorBox: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 12,
    marginHorizontal: 16,
    marginTop: 8,
    borderRadius: 8,
  },
  errorText: {
    flex: 1,
    fontSize: 14,
  },
  closeError: {
    fontSize: 20,
    marginLeft: 8,
  },
  scroll: {
    flex: 1,
  },
  section: {
    marginTop: 16,
    padding: 20,
  },
  sectionTitle: {
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
    marginBottom: 12,
  },
  providerCard: {
    borderRadius: 12,
    padding: 16,
    marginBottom: 8,
  },
  activeCard: {
    borderWidth: 1,
  },
  providerMain: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  providerInfo: {
    flex: 1,
  },
  providerName: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  providerDesc: {
    fontSize: 14,
  },
  activeBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  activeBadgeText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  providerActions: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 12,
  },
  actionButton: {
    flex: 1,
    paddingVertical: 8,
    borderRadius: 6,
    borderWidth: 1,
    alignItems: 'center',
  },
  actionText: {
    fontSize: 13,
    fontWeight: '500',
  },
  empty: {
    padding: 32,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 14,
  },
  loading: {
    padding: 32,
    alignItems: 'center',
  },
  modalOverlay: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  modalContent: {
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 24,
    maxHeight: '80%',
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  label: {
    fontSize: 14,
    fontWeight: '500',
    marginTop: 16,
    marginBottom: 8,
  },
  presetScroll: {
    flexDirection: 'row',
    marginBottom: 8,
  },
  presetCard: {
    padding: 12,
    borderRadius: 8,
    borderWidth: 1,
    marginRight: 8,
    minWidth: 100,
  },
  presetName: {
    fontSize: 14,
    fontWeight: '500',
  },
  input: {
    padding: 12,
    borderRadius: 8,
    borderWidth: 1,
    fontSize: 16,
  },
  modalButtons: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 24,
  },
  modalButton: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 10,
    alignItems: 'center',
  },
  cancelButton: {
    borderWidth: 1,
  },
  saveButton: {},
  modalButtonText: {
    fontSize: 16,
    fontWeight: '600',
  },
  saveButtonText: {
    color: '#fff',
  },
  // Network settings styles
  settingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 16,
    borderBottomWidth: 1,
  },
  settingInfo: {
    flex: 1,
  },
  settingLabel: {
    fontSize: 15,
    fontWeight: '500',
    marginBottom: 2,
  },
  settingDesc: {
    fontSize: 12,
    marginTop: 2,
  },
  settingValue: {
    fontSize: 13,
    marginTop: 4,
  },
  settingAction: {
    fontSize: 14,
    fontWeight: '600',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
  },
  pairingCodeText: {
    fontSize: 18,
    fontWeight: '700',
    fontFamily: 'monospace',
    letterSpacing: 2,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
  },
  toggleButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
  },
  toggleButtonText: {
    fontSize: 13,
    fontWeight: '600',
  },
})
