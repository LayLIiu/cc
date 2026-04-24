// types/provider.ts

export type ApiFormat = 'anthropic' | 'openai_chat' | 'openai_responses'

export type ModelMapping = {
  main: string
  haiku: string
  sonnet: string
  opus: string
}

export type SavedProvider = {
  id: string
  presetId: string
  name: string
  apiKey: string
  baseUrl: string
  apiFormat: ApiFormat
  models: ModelMapping
  notes?: string
}

export type CreateProviderInput = {
  presetId: string
  name: string
  apiKey: string
  baseUrl: string
  apiFormat?: ApiFormat
  models: ModelMapping
  notes?: string
}

export type UpdateProviderInput = {
  name?: string
  apiKey?: string
  baseUrl?: string
  apiFormat?: ApiFormat
  models?: ModelMapping
  notes?: string
}

export type ProviderPreset = {
  id: string
  name: string
  baseUrl: string
  apiFormat: ApiFormat
  defaultModels: ModelMapping
  needsApiKey: boolean
  websiteUrl: string
}

export type ProviderTestStepResult = {
  success: boolean
  latencyMs: number
  error?: string
  modelUsed?: string
  httpStatus?: number
}

export type ProviderTestResult = {
  connectivity: ProviderTestStepResult
  proxy?: ProviderTestStepResult
}

export type TestProviderConfigInput = {
  baseUrl: string
  apiKey: string
  modelId: string
  apiFormat?: ApiFormat
}
