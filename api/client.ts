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
    const url = `${this.getBaseUrl()}/api/sessions`
    console.log('[API] Fetching sessions from:', url)
    try {
      const response = await this.safeFetch(url)
      console.log('[API] Sessions response status:', response.status)
      if (!response.ok) {
        const errorText = await response.text()
        console.log('[API] Sessions error:', errorText)
        throw new Error('获取会话列表失败')
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
    // Find tool_use messages that don't have a paired tool_result yet
    // and attach the result to the tool_use message
    const toolUseMap = new Map<string, number>() // tool_use_id -> index in messages
    for (let i = 0; i < messages.length; i++) {
      if (messages[i].type === 'tool_use') {
        toolUseMap.set(messages[i].id, i)
      }
    }

    // Process tool_result messages - attach to the most recent unpaired tool_use
    const toRemove: number[] = []
    let lastToolUseIdx = -1
    for (let i = 0; i < messages.length; i++) {
      if (messages[i].type === 'tool_result') {
        // Find the most recent tool_use before this tool_result
        for (let j = i - 1; j >= 0; j--) {
          if (messages[j].type === 'tool_use' && !messages[j].toolResult) {
            messages[j].toolResult = messages[i].toolResult
            messages[j].toolStatus = messages[i].toolStatus || 'completed'
            toRemove.push(i)
            break
          }
        }
      }
    }

    // Remove tool_result messages that have been paired
    for (let i = toRemove.length - 1; i >= 0; i--) {
      messages.splice(toRemove[i], 1)
    }
  }
}

export const apiClient = new ApiClient()
