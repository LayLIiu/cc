// 数据模型定义

import Foundation
import SwiftUI

// MARK: - 会话模型

/// 权限模式枚举（与桌面端保持一致）
enum PermissionMode: String, Codable, CaseIterable {
    case `default` = "default"              // 询问权限
    case acceptEdits = "acceptEdits"        // 自动接受编辑
    case plan = "plan"                      // 计划模式
    case bypassPermissions = "bypassPermissions"  // 跳过权限

    var displayName: String {
        switch self {
        case .default: return "询问权限"
        case .acceptEdits: return "自动接受编辑"
        case .plan: return "计划模式"
        case .bypassPermissions: return "跳过权限"
        }
    }

    var description: String {
        switch self {
        case .default: return "CLR请求时，确定文件编辑和高风险命令"
        case .acceptEdits: return "Cloud无需询问即可写入磁盘"
        case .plan: return "仅架构和推理，不操作文件"
        case .bypassPermissions: return "对shell和文件系统完全工具访问"
        }
    }

    var color: Color {
        switch self {
        case .default: return .orange
        case .acceptEdits: return .green
        case .plan: return .blue
        case .bypassPermissions: return .red
        }
    }
}

struct Session: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    let projectPath: String
    let workDir: String?
    let workDirExists: Bool
    let createdAt: String
    let modifiedAt: String
    let messageCount: Int

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 消息模型

enum MessageType: String, Codable {
    case user
    case assistant
    case thinking
    case toolUse = "tool_use"
    case toolResult = "tool_result"
    case permissionRequest = "permission_request"
    case question
    case taskList = "task_list"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "user", "user_text":
            self = .user
        case "assistant", "assistant_text":
            self = .assistant
        case "thinking":
            self = .thinking
        case "tool_use":
            self = .toolUse
        case "tool_result":
            self = .toolResult
        case "permission_request":
            self = .permissionRequest
        case "question":
            self = .question
        case "task_list":
            self = .taskList
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown MessageType: \(rawValue)"
            )
        }
    }
}

enum ToolStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
}

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let type: MessageType
    let content: String
    let timestamp: String
    var toolName: String?
    var toolInput: [String: AnyCodable]?
    var toolResult: String?
    var toolStatus: ToolStatus?
    var isStreaming: Bool?

    // 权限请求相关
    var permissionId: String?
    var permissionDescription: String?
    var isPermissionHandled: Bool = false
    var permissionResult: Bool?

    // 问题选项相关
    var questionId: String?
    var options: [String]?
    var selectedAnswer: String?
    var isQuestionAnswered: Bool = false

    // 任务列表相关
    var tasks: [TaskItem]?

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

// 任务状态
enum TaskStatus: String, Codable {
    case pending
    case inProgress = "in_progress"
    case completed
    case failed
}

// 任务项
struct TaskItem: Identifiable, Codable, Equatable {
    let id: String
    var content: String
    var status: TaskStatus
    var activeForm: String?   // 进行中描述（如"修复认证模块"）
    var owner: String?        // 负责人

    var icon: String {
        switch status {
        case .pending: return "circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch status {
        case .pending: return .secondary
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - 服务商模型

enum ApiFormat: String, Codable, CaseIterable {
    case anthropic = "anthropic"
    case openAIChat = "openai_chat"
    case openAIResponses = "openai_responses"

    var label: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openAIChat: return "OpenAI Chat"
        case .openAIResponses: return "OpenAI Responses"
        }
    }
}

struct ModelMapping: Codable {
    let main: String
    let haiku: String
    let sonnet: String
    let opus: String
}

struct Provider: Identifiable, Codable {
    let id: String
    let presetId: String
    var name: String
    var apiKey: String
    var baseUrl: String
    let apiFormat: ApiFormat
    var models: ModelMapping
    var notes: String?
}

// MARK: - 用户模型

struct User: Codable {
    let id: String
    let name: String
    let email: String?
}

// MARK: - WebSocket 消息类型

enum WSMessageType: String, Codable {
    case connected
    case contentStart = "content_start"
    case contentDelta = "content_delta"
    case thinking
    case toolUseComplete = "tool_use_complete"
    case toolResult = "tool_result"
    case messageComplete = "message_complete"
    case status
    case userMessageEcho = "user_message_echo"
    case permissionRequest = "permission_request"
    case question
    case questions  // 桌面端发送的是 questions（复数）
    case error
    case tokenUsage = "token_usage"
    case sessionTitleUpdated = "session_title_updated"
    case taskList = "task_list"
    case taskUpdate = "task_update"
    case unknown  // 容错：未知类型

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let type = WSMessageType(rawValue: rawValue) {
            self = type
        } else {
            self = .unknown
        }
    }
}

struct WSMessage: Codable {
    var type: WSMessageType?  // 改为可选，因为桌面端有些消息没有 type 字段
    var text: String?
    var blockType: String?
    var toolName: String?
    var toolUseId: String?
    var input: [String: AnyCodable]?
    var content: AnyCodable?
    var isError: Bool?
    var requestId: String?
    var description: String?
    var questionId: String?
    var questionText: String?
    var options: [String]?
    var sessionId: String?
    var state: String?
    var verb: String?
    var timestamp: String?
    var id: String?
    var percentage: Double?
    var used: Int?
    var total: Int?
    var title: String?

    // 桌面端发送的 questions 数组格式
    var questions: [QuestionItem]?

    // 任务列表相关
    var tasks: [TaskItem]?

    // 自定义解码，处理没有 type 字段但有 questions 字段的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 如果有 questions 字段但没有 type 字段，自动设置 type 为 questions
        if container.contains(.questions) && !container.contains(.type) {
            type = .questions
        } else {
            type = try container.decodeIfPresent(WSMessageType.self, forKey: .type)
        }

        text = try container.decodeIfPresent(String.self, forKey: .text)
        blockType = try container.decodeIfPresent(String.self, forKey: .blockType)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        toolUseId = try container.decodeIfPresent(String.self, forKey: .toolUseId)
        input = try container.decodeIfPresent([String: AnyCodable].self, forKey: .input)
        content = try container.decodeIfPresent(AnyCodable.self, forKey: .content)
        isError = try container.decodeIfPresent(Bool.self, forKey: .isError)
        requestId = try container.decodeIfPresent(String.self, forKey: .requestId)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        questionId = try container.decodeIfPresent(String.self, forKey: .questionId)
        questionText = try container.decodeIfPresent(String.self, forKey: .questionText)
        options = try container.decodeIfPresent([String].self, forKey: .options)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        verb = try container.decodeIfPresent(String.self, forKey: .verb)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        percentage = try container.decodeIfPresent(Double.self, forKey: .percentage)
        used = try container.decodeIfPresent(Int.self, forKey: .used)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        questions = try container.decodeIfPresent([QuestionItem].self, forKey: .questions)
        tasks = try container.decodeIfPresent([TaskItem].self, forKey: .tasks)
    }

    private enum CodingKeys: String, CodingKey {
        case type, text, blockType, toolName, toolUseId, input, content
        case isError, requestId, description, questionId, questionText, options
        case sessionId, state, verb, timestamp, id, percentage, used, total, title, questions, tasks
    }

    // 显式初始化器（用于备用解析 fallback）
    init(
        type: WSMessageType? = nil,
        text: String? = nil,
        blockType: String? = nil,
        toolName: String? = nil,
        toolUseId: String? = nil,
        input: [String: AnyCodable]? = nil,
        content: AnyCodable? = nil,
        isError: Bool? = nil,
        requestId: String? = nil,
        description: String? = nil,
        questionId: String? = nil,
        questionText: String? = nil,
        options: [String]? = nil,
        sessionId: String? = nil,
        state: String? = nil,
        verb: String? = nil,
        timestamp: String? = nil,
        id: String? = nil,
        percentage: Double? = nil,
        used: Int? = nil,
        total: Int? = nil,
        title: String? = nil,
        questions: [QuestionItem]? = nil,
        tasks: [TaskItem]? = nil
    ) {
        self.type = type
        self.text = text
        self.blockType = blockType
        self.toolName = toolName
        self.toolUseId = toolUseId
        self.input = input
        self.content = content
        self.isError = isError
        self.requestId = requestId
        self.description = description
        self.questionId = questionId
        self.questionText = questionText
        self.options = options
        self.sessionId = sessionId
        self.state = state
        self.verb = verb
        self.timestamp = timestamp
        self.id = id
        self.percentage = percentage
        self.used = used
        self.total = total
        self.title = title
        self.questions = questions
        self.tasks = tasks
    }
}

// 桌面端发送的问题项格式
struct QuestionItem: Codable {
    var question: String?
    var header: String?
    var options: [QuestionOption]?
    var multiSelect: Bool?

    init(question: String? = nil, header: String? = nil, options: [QuestionOption]? = nil, multiSelect: Bool? = nil) {
        self.question = question
        self.header = header
        self.options = options
        self.multiSelect = multiSelect
    }
}

// 问题选项格式 - 支持两种桌面端格式：字符串数组 ["A", "B"] 和对象数组 [{"label":"A"}]
struct QuestionOption: Codable {
    var label: String?
    var description: String?

    init(label: String? = nil, description: String? = nil) {
        self.label = label
        self.description = description
    }

    init(from decoder: Decoder) throws {
        // 先尝试作为字符串解析（如 "选项A"）
        if let container = try? decoder.singleValueContainer(),
           let stringValue = try? container.decode(String.self) {
            self.label = stringValue
            self.description = nil
            return
        }
        // 否则作为对象解析
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.label = try container.decodeIfPresent(String.self, forKey: .label)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }

    enum CodingKeys: String, CodingKey {
        case label, description
    }
}

// MARK: - 会话状态

enum SessionStatus: String {
    case idle
    case thinking
    case toolExecuting = "tool_executing"
    case streaming
    case permissionPending = "permission_pending"
    case questionPending = "question_pending"
    case completed
}

// MARK: - 辅助类型

struct AnyCodable: Codable, Hashable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = ""
        }
    }

    init(value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable(value: $0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable(value: $0) })
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}

// MARK: - 权限请求

struct PermissionRequest {
    let requestId: String
    let toolName: String
    let input: [String: Any]
    let description: String?
}

// MARK: - 问题请求

struct QuestionRequest {
    let questionId: String
    let questionText: String
    let options: [String]
}

// MARK: - 最近项目

struct RecentProject: Codable {
    let projectName: String
    let projectPath: String
    let realPath: String
    let isGit: Bool
    let repoName: String?
    let branch: String?
    let modifiedAt: String
    let sessionCount: Int
}

// MARK: - 任务列表 API 响应

struct TasksListResponse: Codable {
    let tasks: [CLITaskResponse]
}

struct CLITaskResponse: Codable {
    let id: String
    let subject: String
    let description: String?
    let activeForm: String?
    let owner: String?
    let status: String
    let taskListId: String?
}
