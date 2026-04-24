import React, { useState, useEffect, memo } from 'react'
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Modal,
  Pressable,
  ScrollView,
} from 'react-native'
import { useTheme } from '@/utils/theme'
import { useModelStore } from '@/stores/modelStore'

type ModelSelectorProps = {
  compact?: boolean
}

const ModelSelectorComponent = ({ compact = false }: ModelSelectorProps) => {
  const { colors, isDark } = useTheme()
  const [showModal, setShowModal] = useState(false)
  const {
    currentModel,
    availableModels,
    activeProviderName,
    effortLevel,
    fetchModels,
    setCurrentModel,
    setEffort,
  } = useModelStore()

  useEffect(() => {
    fetchModels()
  }, [])

  const effortOptions = [
    { value: 'low', label: '低' },
    { value: 'medium', label: '中' },
    { value: 'high', label: '高' },
    { value: 'max', label: '最高' },
  ]

  const getModelIcon = (id: string): string => {
    const lower = id.toLowerCase()
    if (lower.includes('opus')) return '◆'
    if (lower.includes('sonnet')) return '✦'
    if (lower.includes('haiku')) return '⚡'
    return '🤖'
  }

  const handleModelSelect = async (modelId: string) => {
    try {
      await setCurrentModel(modelId)
      setShowModal(false)
    } catch (e) {
      // Error handled in store
    }
  }

  const handleEffortSelect = async (level: string) => {
    try {
      await setEffort(level)
    } catch (e) {
      // Error handled in store
    }
  }

  // Compact mode: just show model name as a button
  if (compact) {
    return (
      <>
        <TouchableOpacity
          style={[styles.compactButton, { backgroundColor: colors.surface }]}
          onPress={() => setShowModal(true)}
        >
          <Text style={[styles.compactIcon, { color: colors.primary }]}>✦</Text>
          <Text style={[styles.compactText, { color: colors.textSecondary }]} numberOfLines={1}>
            {currentModel?.name || '模型'}
          </Text>
        </TouchableOpacity>

        <Modal
          visible={showModal}
          transparent
          animationType="slide"
          onRequestClose={() => setShowModal(false)}
        >
          <Pressable style={styles.modalOverlay} onPress={() => setShowModal(false)}>
            <Pressable
              style={[styles.modalContent, { backgroundColor: colors.surface }]}
              onPress={(e) => e.stopPropagation()}
            >
              {/* Header */}
              <View style={styles.modalHeader}>
                <Text style={[styles.modalTitle, { color: colors.text }]}>选择模型</Text>
                <TouchableOpacity onPress={() => setShowModal(false)}>
                  <Text style={[styles.closeButton, { color: colors.textSecondary }]}>关闭</Text>
                </TouchableOpacity>
              </View>

              {/* Provider info */}
              {activeProviderName && (
                <View style={[styles.providerInfo, { backgroundColor: colors.background }]}>
                  <Text style={[styles.providerLabel, { color: colors.textTertiary }]}>服务商</Text>
                  <Text style={[styles.providerName, { color: colors.text }]}>{activeProviderName}</Text>
                </View>
              )}

              {/* Models */}
              <ScrollView style={styles.modelList}>
                {availableModels.map((model) => {
                  const isSelected = model.id === currentModel?.id
                  return (
                    <TouchableOpacity
                      key={model.id}
                      style={[
                        styles.modelItem,
                        isSelected && { backgroundColor: colors.primary + '15' },
                      ]}
                      onPress={() => handleModelSelect(model.id)}
                    >
                      <View style={styles.modelLeft}>
                        <View
                          style={[
                            styles.radioOuter,
                            { borderColor: isSelected ? colors.primary : colors.border },
                          ]}
                        >
                          {isSelected && (
                            <View style={[styles.radioInner, { backgroundColor: colors.primary }]} />
                          )}
                        </View>
                        <Text style={[styles.modelIcon, { color: colors.primary }]}>
                          {getModelIcon(model.id)}
                        </Text>
                      </View>
                      <View style={styles.modelInfo}>
                        <Text style={[styles.modelName, { color: colors.text }]}>{model.name}</Text>
                        {model.description && (
                          <Text style={[styles.modelDesc, { color: colors.textTertiary }]} numberOfLines={1}>
                            {model.description}
                          </Text>
                        )}
                      </View>
                    </TouchableOpacity>
                  )
                })}
              </ScrollView>

              {/* Effort selector */}
              <View style={[styles.effortSection, { borderTopColor: colors.border }]}>
                <Text style={[styles.effortLabel, { color: colors.textTertiary }]}>思考强度</Text>
                <View style={styles.effortButtons}>
                  {effortOptions.map((opt) => {
                    const isSelected = opt.value === effortLevel
                    return (
                      <TouchableOpacity
                        key={opt.value}
                        style={[
                          styles.effortButton,
                          isSelected
                            ? { backgroundColor: colors.primary }
                            : { backgroundColor: colors.background },
                        ]}
                        onPress={() => handleEffortSelect(opt.value)}
                      >
                        <Text
                          style={[
                            styles.effortText,
                            { color: isSelected ? '#fff' : colors.textSecondary },
                          ]}
                        >
                          {opt.label}
                        </Text>
                      </TouchableOpacity>
                    )
                  })}
                </View>
              </View>
            </Pressable>
          </Pressable>
        </Modal>
      </>
    )
  }

  // Full mode: show as a styled button
  return (
    <>
      <TouchableOpacity
        style={[styles.selectorButton, { backgroundColor: colors.surface }]}
        onPress={() => setShowModal(true)}
      >
        <Text style={[styles.selectorIcon, { color: colors.primary }]}>✦</Text>
        <Text style={[styles.selectorText, { color: colors.text }]} numberOfLines={1}>
          {currentModel?.name || '选择模型'}
        </Text>
        <Text style={[styles.selectorArrow, { color: colors.textSecondary }]}>▼</Text>
      </TouchableOpacity>

      <Modal
        visible={showModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowModal(false)}
      >
        <Pressable style={styles.modalOverlay} onPress={() => setShowModal(false)}>
          <Pressable
            style={[styles.modalContent, { backgroundColor: colors.surface }]}
            onPress={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <View style={styles.modalHeader}>
              <Text style={[styles.modalTitle, { color: colors.text }]}>选择模型</Text>
              <TouchableOpacity onPress={() => setShowModal(false)}>
                <Text style={[styles.closeButton, { color: colors.textSecondary }]}>关闭</Text>
              </TouchableOpacity>
            </View>

            {/* Provider info */}
            {activeProviderName && (
              <View style={[styles.providerInfo, { backgroundColor: colors.background }]}>
                <Text style={[styles.providerLabel, { color: colors.textTertiary }]}>服务商</Text>
                <Text style={[styles.providerName, { color: colors.text }]}>{activeProviderName}</Text>
              </View>
            )}

            {/* Models */}
            <ScrollView style={styles.modelList}>
              {availableModels.map((model) => {
                const isSelected = model.id === currentModel?.id
                return (
                  <TouchableOpacity
                    key={model.id}
                    style={[
                      styles.modelItem,
                      isSelected && { backgroundColor: colors.primary + '15' },
                    ]}
                    onPress={() => handleModelSelect(model.id)}
                  >
                    <View style={styles.modelLeft}>
                      <View
                        style={[
                          styles.radioOuter,
                          { borderColor: isSelected ? colors.primary : colors.border },
                        ]}
                      >
                        {isSelected && (
                          <View style={[styles.radioInner, { backgroundColor: colors.primary }]} />
                        )}
                      </View>
                      <Text style={[styles.modelIcon, { color: colors.primary }]}>
                        {getModelIcon(model.id)}
                      </Text>
                    </View>
                    <View style={styles.modelInfo}>
                      <Text style={[styles.modelName, { color: colors.text }]}>{model.name}</Text>
                      {model.description && (
                        <Text style={[styles.modelDesc, { color: colors.textTertiary }]} numberOfLines={1}>
                          {model.description}
                        </Text>
                      )}
                    </View>
                  </TouchableOpacity>
                )
              })}
            </ScrollView>

            {/* Effort selector */}
            <View style={[styles.effortSection, { borderTopColor: colors.border }]}>
              <Text style={[styles.effortLabel, { color: colors.textTertiary }]}>思考强度</Text>
              <View style={styles.effortButtons}>
                {effortOptions.map((opt) => {
                  const isSelected = opt.value === effortLevel
                  return (
                    <TouchableOpacity
                      key={opt.value}
                      style={[
                        styles.effortButton,
                        isSelected
                          ? { backgroundColor: colors.primary }
                          : { backgroundColor: colors.background },
                      ]}
                      onPress={() => handleEffortSelect(opt.value)}
                    >
                      <Text
                        style={[
                          styles.effortText,
                          { color: isSelected ? '#fff' : colors.textSecondary },
                        ]}
                      >
                        {opt.label}
                      </Text>
                    </TouchableOpacity>
                  )
                })}
              </View>
            </View>
          </Pressable>
        </Pressable>
      </Modal>
    </>
  )
}

export const ModelSelector = memo(ModelSelectorComponent)

const styles = StyleSheet.create({
  // Full mode button
  selectorButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    gap: 6,
  },
  selectorIcon: {
    fontSize: 14,
  },
  selectorText: {
    fontSize: 13,
    fontWeight: '500',
    maxWidth: 100,
  },
  selectorArrow: {
    fontSize: 10,
  },

  // Compact mode button
  compactButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    gap: 4,
  },
  compactIcon: {
    fontSize: 12,
  },
  compactText: {
    fontSize: 11,
    fontWeight: '500',
    maxWidth: 60,
  },

  // Modal
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: '70%',
    paddingBottom: 34,
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
  closeButton: {
    fontSize: 14,
  },

  // Provider info
  providerInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    marginHorizontal: 16,
    marginTop: 12,
    borderRadius: 8,
    gap: 8,
  },
  providerLabel: {
    fontSize: 12,
  },
  providerName: {
    fontSize: 13,
    fontWeight: '500',
  },

  // Model list
  modelList: {
    padding: 16,
    maxHeight: 300,
  },
  modelItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    borderRadius: 12,
    marginBottom: 8,
    gap: 12,
  },
  modelLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  radioOuter: {
    width: 18,
    height: 18,
    borderRadius: 9,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  radioInner: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  modelIcon: {
    fontSize: 18,
  },
  modelInfo: {
    flex: 1,
  },
  modelName: {
    fontSize: 15,
    fontWeight: '600',
  },
  modelDesc: {
    fontSize: 12,
    marginTop: 2,
  },

  // Effort section
  effortSection: {
    padding: 16,
    borderTopWidth: 1,
  },
  effortLabel: {
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
    marginBottom: 10,
  },
  effortButtons: {
    flexDirection: 'row',
    gap: 8,
  },
  effortButton: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 10,
    alignItems: 'center',
  },
  effortText: {
    fontSize: 13,
    fontWeight: '600',
  },
})
