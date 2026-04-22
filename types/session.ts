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
  type: string
  content: string
  timestamp: string
}

