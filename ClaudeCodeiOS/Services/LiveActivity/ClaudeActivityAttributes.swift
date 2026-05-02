// 灵动岛活动属性
// 注意：这个文件必须与 ClaudeWidget/ClaudeWidgetLiveActivity.swift 中的定义保持一致

import ActivityKit
import Foundation

/// 会话摘要（用于锁屏显示多个会话）
struct SessionSummary: Codable, Hashable {
    var title: String
    var content: String
    var type: ActivityType
}

/// Claude Code 工作状态灵动岛属性
struct ClaudeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 工作状态
        var status: ClaudeWorkStatus
        /// 状态文字
        var statusText: String
        /// 工具名称（如 Bash, Edit, Read 等）
        var toolName: String
        /// 当前活动内容（描述）
        var activityContent: String
        /// 活动内容类型
        var activityType: ActivityType
        /// 会话标题
        var sessionTitle: String
        /// 已用时间（秒）
        var elapsedSeconds: Int
        /// 正在工作的会话数
        var activeSessions: Int
        /// 总会话数
        var totalSessions: Int
        /// 动画时间戳
        var animationTimestamp: Double
        /// 多会话摘要列表（用于锁屏显示）
        var sessionSummaries: [SessionSummary]
    }

    /// 会话 ID
    var sessionId: String
    /// 吉祥物颜色（十六进制）
    var mascotColorHex: String
}

/// 活动内容类型
enum ActivityType: String, Codable {
    case thinking    // 思考中
    case toolUse     // 工具调用
    case streaming   // 生成回复
    case completed   // 已完成
    case idle        // 空闲
}

/// 工作状态枚举
enum ClaudeWorkStatus: String, Codable {
    case idle = "idle"
    case working = "working"
    case completed = "completed"

    var displayText: String {
        switch self {
        case .idle: return "休闲中"
        case .working: return "工作中"
        case .completed: return "已完成"
        }
    }
}
