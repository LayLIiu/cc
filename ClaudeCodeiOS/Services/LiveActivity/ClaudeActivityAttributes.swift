// 灵动岛活动属性
// 注意：这个文件必须与 ClaudeWidget/ClaudeWidgetLiveActivity.swift 中的定义保持一致

import ActivityKit
import Foundation

/// Claude Code 工作状态灵动岛属性
struct ClaudeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 工作状态
        var status: ClaudeWorkStatus
        /// 状态文字
        var statusText: String
        /// 最后一条消息摘要
        var lastMessage: String
        /// 会话标题
        var sessionTitle: String
        /// 已用时间（秒）
        var elapsedSeconds: Int
        /// 已完成任务数
        var completedTasks: Int
        /// 总任务数
        var totalTasks: Int
    }

    /// 会话 ID
    var sessionId: String
    /// 吉祥物颜色（十六进制）
    var mascotColorHex: String
}

/// 工作状态枚举（简化版：只有三个状态）
enum ClaudeWorkStatus: String, Codable {
    case idle = "idle"           // 休闲中
    case working = "working"     // 工作中
    case completed = "completed" // 已完成

    var displayText: String {
        switch self {
        case .idle: return "休闲中"
        case .working: return "工作中"
        case .completed: return "已完成"
        }
    }
}
