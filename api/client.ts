import { useAuthStore } from '@/stores/authStore'
import type { Session, Message } from '@/types/session'

class ApiClient {
  private getBaseUrl(): string {
    return useAuthStore.getState().serverUrl
  }

  async getSessions(): Promise<Session[]> {
    const response = await fetch(`${this.getBaseUrl()}/api/sessions`)
    if (!response.ok) {
      throw new Error('Failed to fetch sessions')
    }
    const data = await response.json()
    return data.sessions
  }

  async getSession(id: string): Promise<Session | null> {
    const response = await fetch(`${this.getBaseUrl()}/api/sessions/${id}`)
    if (response.status === 404) {
      return null
    }
    if (!response.ok) {
      throw new Error('Failed to fetch session')
    }
    return response.json()
  }

  async getMessages(sessionId: string): Promise<Message[]> {
    const response = await fetch(
      `${this.getBaseUrl()}/api/sessions/${sessionId}/messages`
    )
    if (!response.ok) {
      throw new Error('Failed to fetch messages')
    }
    const data = await response.json()
    return data.messages
  }

  getWebSocketUrl(sessionId: string): string {
    const baseUrl = this.getBaseUrl()
      .replace('http://', 'ws://')
      .replace('https://', 'wss://')
    return `${baseUrl}/ws/${sessionId}`
  }
}

export const apiClient = new ApiClient()
