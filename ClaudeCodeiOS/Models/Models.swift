// 数据模型定义

import Foundation
import SwiftUI

// MARK: - 会话模型

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
    case error
    case tokenUsage = "token_usage"
    case sessionTitleUpdated = "session_title_updated"
}

struct WSMessage: Codable {
    let type: WSMessageType
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
