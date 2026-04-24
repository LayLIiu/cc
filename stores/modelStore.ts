// stores/modelStore.ts

import { create } from 'zustand'
import { apiClient, ModelInfo } from '@/api/client'

interface ModelState {
  currentModel: ModelInfo | null
  availableModels: ModelInfo[]
  activeProviderName: string | null
  effortLevel: string
  isLoading: boolean
  error: string | null

  // Actions
  fetchModels: () => Promise<void>
  setCurrentModel: (modelId: string) => Promise<void>
  setEffort: (level: string) => Promise<void>
  setError: (error: string | null) => void
}

export const useModelStore = create<ModelState>((set, get) => ({
  currentModel: null,
  availableModels: [],
  activeProviderName: null,
  effortLevel: 'high',
  isLoading: false,
  error: null,

  fetchModels: async () => {
    set({ isLoading: true, error: null })
    try {
      const [modelsRes, currentRes, effortRes] = await Promise.all([
        apiClient.getModels(),
        apiClient.getCurrentModel(),
        apiClient.getEffort(),
      ])
      set({
        availableModels: modelsRes.models,
        activeProviderName: modelsRes.provider?.name ?? null,
        currentModel: currentRes.model,
        effortLevel: effortRes.level,
        isLoading: false,
      })
    } catch (err) {
      set({ error: err instanceof Error ? err.message : '加载失败', isLoading: false })
    }
  },

  setCurrentModel: async (modelId: string) => {
    set({ isLoading: true, error: null })
    try {
      await apiClient.setCurrentModel(modelId)
      const model = get().availableModels.find(m => m.id === modelId)
      if (model) {
        set({ currentModel: model, isLoading: false })
      } else {
        set({ isLoading: false })
      }
    } catch (err) {
      set({ error: err instanceof Error ? err.message : '设置失败', isLoading: false })
      throw err
    }
  },

  setEffort: async (level: string) => {
    try {
      await apiClient.setEffort(level)
      set({ effortLevel: level })
    } catch (err) {
      set({ error: err instanceof Error ? err.message : '设置失败' })
      throw err
    }
  },

  setError: (error: string | null) => set({ error }),
}))