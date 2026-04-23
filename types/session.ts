export type SessionStatus = 'idle' | 'thinking' | 'tool_executing' | 'streaming' | 'permission_pending'

export type Session = {
  id: string
  title: string
  createdAt: string
  modifiedAt: string
  messageCount: number
  projectPath: string
  workDir: string | null
  workDirExists: boolean
} | null

export type Message = {
  id: string
  type: string // 'user_text' | 'assistant_text' | 'tool_use' | 'tool_result' | 'thinking'
  content: string
  timestamp: string
  // Tool use fields
  toolName?: string
  toolInput?: Record<string, any>
  // Tool result fields
  toolResult?: any
  toolStatus?: 'pending' | 'running' | 'completed' | 'failed'
  toolDuration?: number
  // Thinking fields
  isStreaming?: boolean
}

