import { useAuthStore } from '@/stores/authStore'
import type { Session, Message } from '@/types/session'
import type { SavedProvider, CreateProviderInput, UpdateProviderInput, TestProviderConfigInput, ProviderTestResult, ProviderPreset } from '@/types/provider'

export type ModelInfo = {
  id: string
  name: string
  description?: string
}

export type RecentProject = {
  projectPath: string
  realPath: string
  projectName: string
  isGit: boolean
  repoName: string | null
  branch: string | null
  modifiedAt: string
  sessionCount: number
}

class ApiClient {
  constructor() {
    // Log the initial server URL for debugging connectivity issues
    try {
      const base = this.getBaseUrl()
      console.log('[API] ApiClient initialized with serverUrl:', base)
    } catch (e) {
      console.log('[API] ApiClient initialization error:', (e as any)?.message)
    }
  }
  private getBaseUrl(): string {
    const url = useAuthStore.getState().serverUrl
    if (!url) {
      console.log('[API] getBaseUrl -> no serverUrl configured')
    }
    return url.replace(/\/+$/, '')
  }

  private async safeFetch(url: string, options?: RequestInit): Promise<Response> {
    console.log('[API] Attempting URL:', url, 'method:', options?.method || 'GET')
    try {
      const hasBody = options?.body != null
      const headers: Record<string, string> = {
        ...(hasBody ? { 'Content-Type': 'application/json' } : {}),
        ...options?.headers as Record<string, string>,
      }
      const response = await fetch(url, {
        ...options,
        headers,
      })
      console.log('[API] Response status:', response.status, 'for', url)
      return response
    } catch (err) {
      const msg = (err as any)?.message ?? '网络请求失败'
      console.log('[API] SafeFetch error:', msg, 'for', url)
      throw new Error(`无法连接服务器，请检查服务器地址是否正确（URL: ${url}，错误：${msg}）`)
    }
  }

  async getSessions(): Promise<Session[]> {
    const url = `${this.getBaseUrl()}/api/sessions`
    console.log('[API] Fetching sessions from:', url)
    try {
      const response = await this.safeFetch(url)
      console.log('[API] Sessions response status:', response.status)
      if (!response.ok) {
        const errorText = await response.text()
        console.log('[API] Sessions error:', response.status, errorText)
        throw new Error(`获取会话列表失败 (HTTP ${response.status}: ${errorText.slice(0, 200)})`)
      }
      const data = await response.json()
      console.log('[API] Sessions count:', data.sessions?.length || 0)
      return data.sessions || []
    } catch (err) {
      console.log('[API] getSessions error:', err)
      throw err
    }
  }

  async getMessages(sessionId: string): Promise<Message[]> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/sessions/${sessionId}/messages`)
    if (!response.ok) throw new Error('获取消息失败')
    const data = await response.json()
    console.log('Raw messages from backend:', data.messages?.slice(-2))
    return this.transformMessages(data.messages || [])
  }

  async createSession(workDir?: string): Promise<{ sessionId: string }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/sessions`, {
      method: 'POST',
      body: JSON.stringify(workDir ? { workDir } : {}),
    })
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '创建会话失败')
    }
    return response.json()
  }

  async getRecentProjects(): Promise<RecentProject[]> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/sessions/recent-projects`)
    if (!response.ok) throw new Error('获取最近项目失败')
    const data = await response.json()
    return data.projects || []
  }

  async deleteSession(sessionId: string): Promise<void> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/sessions/${sessionId}`, {
      method: 'DELETE',
    })
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '删除会话失败')
    }
  }

  async renameSession(sessionId: string, title: string): Promise<void> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/sessions/${sessionId}`, {
      method: 'PATCH',
      body: JSON.stringify({ title }),
    })
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '重命名失败')
    }
  }

  private transformMessages(messages: any[]): Message[] {
    const result: Message[] = []

    for (const msg of messages) {
      if (!msg) continue

      const msgId = msg.id || `${msg.type}-${msg.timestamp || Date.now()}-${result.length}`
      const timestamp = msg.timestamp || String(Date.now())

      // User message
      if (msg.type === 'user') {
        let text = this.extractText(msg.content)
        if (text.trim()) {
          result.push({
            id: msgId,
            type: 'user_text',
            content: text.trim(),
            timestamp,
          })
        }
        continue
      }

      // Assistant message - may contain text + tool_use blocks mixed together
      if (msg.type === 'assistant') {
        if (Array.isArray(msg.content)) {
          // Process each block separately
          for (let blockIdx = 0; blockIdx < msg.content.length; blockIdx++) {
            const block = msg.content[blockIdx]
            if (!block) continue

            if (block.type === 'text') {
              const text = (block.text || '').trim()
              if (text) {
                result.push({
                  id: `${msgId}-text-${blockIdx}`,
                  type: 'assistant_text',
                  content: text,
                  timestamp,
                })
              }
            } else if (block.type === 'tool_use') {
              result.push({
                id: `${msgId}-tool-${blockIdx}`,
                type: 'tool_use',
                content: '',
                timestamp,
                toolName: block.name || 'Unknown',
                toolInput: block.input || {},
              })
            } else if (block.type === 'thinking') {
              const text = (block.thinking || block.text || '').trim()
              if (text) {
                result.push({
                  id: `${msgId}-thinking-${blockIdx}`,
                  type: 'thinking',
                  content: text,
                  timestamp,
                })
              }
            }
          }
        } else if (typeof msg.content === 'string') {
          if (msg.content.trim()) {
            result.push({
              id: msgId,
              type: 'assistant_text',
              content: msg.content.trim(),
              timestamp,
            })
          }
        } else if (msg.content && typeof msg.content === 'object' && typeof msg.content.text === 'string') {
          if (msg.content.text.trim()) {
            result.push({
              id: msgId,
              type: 'assistant_text',
              content: msg.content.text.trim(),
              timestamp,
            })
          }
        }
        continue
      }

      // Tool result message
      if (msg.type === 'tool_result') {
        const resultContent = typeof msg.content === 'string'
          ? msg.content
          : Array.isArray(msg.content)
            ? msg.content.map((b: any) => b?.text || '').join('')
            : JSON.stringify(msg.content)

        result.push({
          id: msgId,
          type: 'tool_result',
          content: '',
          timestamp,
          toolResult: resultContent,
          toolStatus: msg.is_error ? 'failed' : 'completed',
        })
        continue
      }

      // System/thinking messages - skip system, keep thinking
      if (msg.type === 'thinking') {
        const text = (msg.thinking || msg.content || '').trim()
        if (typeof text === 'string' && text) {
          result.push({
            id: msgId,
            type: 'thinking',
            content: text,
            timestamp,
          })
        }
        continue
      }

      // Skip other types (system, etc.)
    }

    // After collecting all messages, pair tool_use with their tool_result
    this.pairToolResults(result)

    console.log('Transformed messages:', result.length)
    return result
  }

  private extractText(content: any): string {
    if (typeof content === 'string') return content
    if (Array.isArray(content)) {
      return content
        .filter((b: any) => b?.type === 'text' && typeof b.text === 'string')
        .map((b: any) => b.text)
        .join('')
    }
    if (content && typeof content === 'object' && typeof content.text === 'string') {
      return content.text
    }
    return ''
  }

  private pairToolResults(messages: Message[]) {
    // 找到所有 tool_result 消息并配对到最近的未配对 tool_use
    const toRemove = new Set<number>()

    for (let i = 0; i < messages.length; i++) {
      if (messages[i].type === 'tool_result') {
        // 找到这条 tool_result 之前最近的未配对 tool_use
        for (let j = i - 1; j >= 0; j--) {
          if (messages[j].type === 'tool_use' && !messages[j].toolResult) {
            messages[j].toolResult = messages[i].toolResult
            messages[j].toolStatus = messages[i].toolStatus || 'completed'
            toRemove.add(i)
            break
          }
        }
      }
    }

    // 使用 filter 方式移除已配对的 tool_result（更安全）
    if (toRemove.size > 0) {
      const remaining = messages.filter((_, idx) => !toRemove.has(idx))
      messages.length = 0
      messages.push(...remaining)
    }
  }

  // Providers API
  async getProviders(): Promise<{ providers: SavedProvider[]; activeId: string | null }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/providers`)
    if (!response.ok) throw new Error('获取服务商列表失败')
    return response.json()
  }

  async getProviderPresets(): Promise<{ presets: ProviderPreset[] }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/providers/presets`)
    if (!response.ok) throw new Error('获取服务商预设失败')
    return response.json()
  }

  async getAuthStatus(): Promise<{ hasAuth: boolean; source: string; activeProvider?: string }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/providers/auth-status`)
    if (!response.ok) throw new Error('获取认证状态失败')
    return response.json()
  }

  async createProvider(input: CreateProviderInput): Promise<{ provider: SavedProvider }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/providers`, {
      method: 'POST',
      body: JSON.stringify(input),
    })
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '创建服务商失败')
    }
    return response.json()
  }

  async updateProvider(id: string, input: UpdateProviderInput): Promise<{ provider: SavedProvider }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/providers/${id}`, {
      method: 'PUT',
      body: JSON.stringify(input),
    })
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '更新服务商失败')
    }
    return response.json()
  }

  async deleteProvider(id: string): Promise<{ ok: true }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/providers/${id}`, {
      method: 'DELETE',
    })
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '删除服务商失败')
    }
    return response.json()
  }

  async activateProvider(id: string): Promise<{ ok: true }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/providers/${id}/activate`, {
      method: 'POST',
    })
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '激活服务商失败')
    }
    return response.json()
  }

  async activateOfficialProvider(): Promise<{ ok: true }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/providers/official`, {
      method: 'POST',
    })
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '激活官方服务商失败')
    }
    return response.json()
  }

  async testProvider(id: string, overrides?: { baseUrl?: string; modelId?: string; apiFormat?: string }): Promise<{ result: ProviderTestResult }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/providers/${id}/test`, {
      method: 'POST',
      body: JSON.stringify(overrides || {}),
    })
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '测试服务商失败')
    }
    return response.json()
  }

  async testProviderConfig(input: TestProviderConfigInput): Promise<{ result: ProviderTestResult }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/providers/test`, {
      method: 'POST',
      body: JSON.stringify(input),
    })
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '测试配置失败')
    }
    return response.json()
  }

  // Models API
  async getModels(): Promise<{ models: ModelInfo[]; provider: { id: string; name: string } | null }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/models`)
    if (!response.ok) throw new Error('获取模型列表失败')
    return response.json()
  }

  async getCurrentModel(): Promise<{ model: ModelInfo }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/models/current`)
    if (!response.ok) throw new Error('获取当前模型失败')
    return response.json()
  }

  async setCurrentModel(modelId: string): Promise<{ ok: true; model: string }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/models/current`, {
      method: 'PUT',
      body: JSON.stringify({ modelId }),
    })
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '设置模型失败')
    }
    return response.json()
  }

  async getEffort(): Promise<{ level: string; available: string[] }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/effort`)
    if (!response.ok) throw new Error('获取 effort 失败')
    return response.json()
  }

  async setEffort(level: string): Promise<{ ok: true; level: string }> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/effort`, {
      method: 'PUT',
      body: JSON.stringify({ level }),
    })
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '设置 effort 失败')
    }
    return response.json()
  }

  // Pairing code and network settings API
  async getPairingCode(): Promise<{ pairingCode: string; expiresAt: number; createdAt: number }> {
    // 尝试多路径兼容性，兼容后端可能的路径变更（如 dash-/camelCase 等变体）
    const base = this.getBaseUrl()
    const urls = [
      `${base}/api/mobile/pairing-code`,
      `${base}/api/mobile/pairingCode`,
    ]
    const response = await this.fetchWithFallback(urls, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ttlHours: 1 }),
    })
    if (response.status === 404) {
      throw new Error('服务器暂不支持配对码功能')
    }
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '获取配对码失败')
    }
    return response.json()
  }

  async getNetworkInfo(): Promise<{ lanUrl: string | null; tunnelUrl: string | null; tunnelEnabled: boolean; serverPort: number }> {
    // 尝试多路径兼容性，覆盖可能的 API 路径变体
    const base = this.getBaseUrl()
    const urls = [
      `${base}/api/mobile/network-info`,
      `${base}/api/mobile/networkInfo`,
    ]
    const response = await this.fetchWithFallback(urls)
    if (response.status === 404) {
      return { lanUrl: null, tunnelUrl: null, tunnelEnabled: false, serverPort: 0 }
    }
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '获取网络信息失败')
    }
    return response.json()
  }

  async enableTunnel(enabled: boolean): Promise<{ ok: boolean; tunnelUrl?: string; error?: string }> {
    // 尝试多路径兼容性，以应对后端 API 变更导致的 404 情况
    const base = this.getBaseUrl()
    const urls = [
      `${base}/api/mobile/tunnel`,
      `${base}/api/mobile/tunnel/enable`,
    ]
    const response = await this.fetchWithFallback(urls, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ enabled }),
    })
    if (response.status === 404) {
      throw new Error('服务器暂不支持公网隧道功能')
    }
    if (!response.ok) {
      const error = await response.json().catch(() => ({}))
      throw new Error(error.message || '设置隧道失败')
    }
    return response.json()
  }

  // 多路径请求支持：按顺序尝试提供的 URL，直到其中一个成功或返回非 404
  private async fetchWithFallback(urls: string[], options?: RequestInit): Promise<Response> {
    for (let i = 0; i < urls.length; i++) {
      try {
        const res = await this.safeFetch(urls[i], options)
        // 如果请求成功，直接返回；若是 404 继续尝试下一个路径
        if (res.ok || res.status !== 404) return res
      } catch (err) {
        // 尝试下一个 URL
        continue
      }
    }
    // 所有路径均失败时，返回最后一次请求的响应或一个新的错误
    // 这里返回最后一次的错误状态以便调用方处理
    return await this.safeFetch(urls[urls.length - 1], options)
  }
}

export const apiClient = new ApiClient()
