import { useAuthStore } from '@/stores/authStore'
import type { Session, Message } from '@/types/session'

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
  private getBaseUrl(): string {
    return useAuthStore.getState().serverUrl
  }

  private async safeFetch(url: string, options?: RequestInit): Promise<Response> {
    try {
      const response = await fetch(url, {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          ...options?.headers,
        },
      })
      return response
    } catch (err) {
      throw new Error(`无法连接服务器，请检查服务器地址是否正确`)
    }
  }

  async getSessions(): Promise<Session[]> {
    const response = await this.safeFetch(`${this.getBaseUrl()}/api/sessions`)
    if (!response.ok) throw new Error('获取会话列表失败')
    const data = await response.json()
    return data.sessions || []
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

  private transformMessages(messages: any[]): Message[] {
    const result: Message[] = []

    for (const msg of messages) {
      if (!msg) continue

      // Backend format: type = 'user' | 'assistant'
      const isUser = msg.type === 'user'
      const isAssistant = msg.type === 'assistant'

      // Skip non-text messages (tool_use, tool_result, system)
      if (!isUser && !isAssistant) continue

      // Extract text content
      let text = ''

      if (typeof msg.content === 'string') {
        text = msg.content
      } else if (Array.isArray(msg.content)) {
        // Content is array of blocks
        for (const block of msg.content) {
          if (block?.type === 'text' && typeof block.text === 'string') {
            text += block.text
          }
        }
      } else if (msg.content && typeof msg.content === 'object') {
        // Single object with text
        if (typeof msg.content.text === 'string') {
          text = msg.content.text
        }
      }

      // Skip empty messages
      if (!text.trim()) continue

      result.push({
        id: msg.id || `msg-${result.length}`,
        type: isUser ? 'user_text' : 'assistant_text',
        content: text.trim(),
        timestamp: msg.timestamp || String(Date.now()),
      })
    }

    console.log('Transformed messages:', result.length)
    return result
  }
}

export const apiClient = new ApiClient()
