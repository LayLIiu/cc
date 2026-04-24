// stores/providerStore.ts

import { create } from 'zustand'
import type { SavedProvider, CreateProviderInput, UpdateProviderInput } from '@/types/provider'
import { apiClient } from '@/api/client'

interface ProviderState {
  providers: SavedProvider[]
  activeProviderId: string | null
  isLoading: boolean
  error: string | null

  // Actions
  loadProviders: () => Promise<void>
  createProvider: (input: CreateProviderInput) => Promise<void>
  updateProvider: (id: string, input: UpdateProviderInput) => Promise<void>
  deleteProvider: (id: string) => Promise<void>
  activateProvider: (id: string) => Promise<void>
  activateOfficial: () => Promise<void>
  getActiveProvider: () => SavedProvider | null
  setError: (error: string | null) => void
}

export const useProviderStore = create<ProviderState>((set, get) => ({
  providers: [],
  activeProviderId: null,
  isLoading: false,
  error: null,

  loadProviders: async () => {
    set({ isLoading: true, error: null })
    try {
      const data = await apiClient.getProviders()
      set({ providers: data.providers, activeProviderId: data.activeId, isLoading: false })
    } catch (err) {
      set({ error: err instanceof Error ? err.message : '加载失败', isLoading: false })
      throw err
    }
  },

  createProvider: async (input: CreateProviderInput) => {
    set({ isLoading: true, error: null })
    try {
      const data = await apiClient.createProvider(input)
      set(state => ({
        providers: [...state.providers, data.provider],
        isLoading: false,
      }))
    } catch (err) {
      set({ error: err instanceof Error ? err.message : '创建失败', isLoading: false })
      throw err
    }
  },

  updateProvider: async (id: string, input: UpdateProviderInput) => {
    set({ isLoading: true, error: null })
    try {
      const data = await apiClient.updateProvider(id, input)
      set(state => ({
        providers: state.providers.map(p => p.id === id ? data.provider : p),
        isLoading: false,
      }))
    } catch (err) {
      set({ error: err instanceof Error ? err.message : '更新失败', isLoading: false })
      throw err
    }
  },

  deleteProvider: async (id: string) => {
    set({ isLoading: true, error: null })
    try {
      await apiClient.deleteProvider(id)
      set(state => ({
        providers: state.providers.filter(p => p.id !== id),
        activeProviderId: state.activeProviderId === id ? null : state.activeProviderId,
        isLoading: false,
      }))
    } catch (err) {
      set({ error: err instanceof Error ? err.message : '删除失败', isLoading: false })
      throw err
    }
  },

  activateProvider: async (id: string) => {
    set({ isLoading: true, error: null })
    try {
      await apiClient.activateProvider(id)
      set({ activeProviderId: id, isLoading: false })
    } catch (err) {
      set({ error: err instanceof Error ? err.message : '激活失败', isLoading: false })
      throw err
    }
  },

  activateOfficial: async () => {
    set({ isLoading: true, error: null })
    try {
      await apiClient.activateOfficialProvider()
      set({ activeProviderId: null, isLoading: false })
    } catch (err) {
      set({ error: err instanceof Error ? err.message : '激活失败', isLoading: false })
      throw err
    }
  },

  getActiveProvider: () => {
    const { providers, activeProviderId } = get()
    return activeProviderId ? providers.find(p => p.id === activeProviderId) || null : null
  },

  setError: (error: string | null) => set({ error }),
}))