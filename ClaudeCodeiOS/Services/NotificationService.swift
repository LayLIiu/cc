// 通知服务

import Foundation
import UserNotifications

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false

    // 当前任务列表（用于常驻通知）
    @Published var currentTasks: [TaskItem] = []
    @Published var currentSessionId: String?
    @Published var currentSessionTitle: String = ""

    // 常驻通知标识符
    private let taskListNotificationId = "claude-code-task-list"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // 请求通知权限
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("通知权限请求失败: \(error)")
            return false
        }
    }

    // MARK: - 任务列表通知

    // 更新任务列表通知
    func updateTaskListNotification(sessionId: String, sessionTitle: String, tasks: [TaskItem]) async {
        guard isAuthorized else { return }

        // 更新本地状态
        await MainActor.run {
            self.currentSessionId = sessionId
            self.currentSessionTitle = sessionTitle
            self.currentTasks = tasks
        }

        let completed = tasks.filter { $0.status == .completed }.count
        let total = tasks.count
        let inProgress = tasks.filter { $0.status == .inProgress }.first

        // 检查是否全部完成
        if completed == total && total > 0 {
            // 所有任务完成，发送完成通知并移除常驻通知
            await removeTaskListNotification()
            await sendCompletionNotification(title: sessionTitle, message: "所有任务已完成")
            return
        }

        let content = UNMutableNotificationContent()

        // 标题显示进度
        content.title = "📋 \(sessionTitle)"
        content.subtitle = "进度: \(completed)/\(total)"

        // 正文显示任务列表（最多显示5个）
        let displayTasks = tasks.prefix(5)
        let taskLines = displayTasks.map { task -> String in
            let icon = task.status == .completed ? "✅" : (task.status == .inProgress ? "⏳" : "⭕️")
            return "\(icon) \(task.content)"
        }
        content.body = taskLines.joined(separator: "\n")

        // 如果有进行中的任务，显示在摘要中
        if let current = inProgress {
            content.threadIdentifier = "task-list"
            content.categoryIdentifier = "TASK_LIST_CATEGORY"
        }

        // 设置通知数据
        content.userInfo = [
            "sessionId": sessionId,
            "type": "taskList"
        ]

        // 创建请求（使用固定ID以便更新）
        let request = UNNotificationRequest(
            identifier: taskListNotificationId,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("更新任务通知失败: \(error)")
        }
    }

    // 移除任务列表通知
    func removeTaskListNotification() async {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [taskListNotificationId])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [taskListNotificationId])

        await MainActor.run {
            self.currentTasks = []
            self.currentSessionId = nil
            self.currentSessionTitle = ""
        }
    }

    // 更新单个任务状态
    func updateTaskStatus(taskId: String, status: TaskStatus) async {
        guard let sessionId = currentSessionId else { return }

        var tasks = currentTasks
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index].status = status
        }

        await updateTaskListNotification(
            sessionId: sessionId,
            sessionTitle: currentSessionTitle,
            tasks: tasks
        )
    }

    // MARK: - 完成通知

    // 发送任务完成通知
    func sendCompletionNotification(title: String, message: String) async {
        guard isAuthorized else { return }

        // 截断消息
        let truncatedMessage = message.count > 100 ? String(message.prefix(100)) + "..." : message

        let content = UNMutableNotificationContent()
        content.title = "✅ \(title.isEmpty ? "工作完成" : title)"
        content.body = truncatedMessage
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("发送通知失败: \(error)")
        }
    }

    // MARK: - 问题通知

    // 发送问题通知（带操作按钮）
    func sendQuestionNotification(sessionId: String, questionId: String, question: String, options: [String]) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "❓ 需要您的选择"
        content.body = question
        content.sound = .default
        content.categoryIdentifier = "QUESTION_CATEGORY"
        content.userInfo = [
            "sessionId": sessionId,
            "questionId": questionId,
            "options": options
        ]

        // 添加选项作为动作（最多4个）
        let actions = options.prefix(4).enumerated().map { index, option in
            UNNotificationAction(
                identifier: "OPTION_\(index)",
                title: option,
                options: [.foreground]
            )
        }

        let category = UNNotificationCategory(
            identifier: "QUESTION_CATEGORY",
            actions: actions,
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])

        let request = UNNotificationRequest(
            identifier: "question-\(questionId)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("发送问题通知失败: \(error)")
        }
    }

    // MARK: - 权限通知

    // 发送权限请求通知
    func sendPermissionNotification(sessionId: String, permissionId: String, toolName: String, description: String) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "🔐 权限请求"
        content.body = "\(toolName): \(description)"
        content.sound = .default
        content.categoryIdentifier = "PERMISSION_CATEGORY"
        content.userInfo = [
            "sessionId": sessionId,
            "permissionId": permissionId
        ]

        let allowAction = UNNotificationAction(
            identifier: "ALLOW",
            title: "允许",
            options: [.foreground]
        )
        let denyAction = UNNotificationAction(
            identifier: "DENY",
            title: "拒绝",
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: "PERMISSION_CATEGORY",
            actions: [allowAction, denyAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])

        let request = UNNotificationRequest(
            identifier: "permission-\(permissionId)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("发送权限通知失败: \(error)")
        }
    }
}

// MARK: - 通知代理

extension NotificationService: UNUserNotificationCenterDelegate {
    // 前台收到通知时显示
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 任务列表通知在前台也显示
        if notification.request.identifier == taskListNotificationId {
            completionHandler([.banner, .sound, .list])
        } else {
            completionHandler([.banner, .sound])
        }
    }

    // 用户点击通知或动作时处理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "ALLOW":
            // 处理允许权限
            if let permissionId = userInfo["permissionId"] as? String {
                NotificationCenter.default.post(
                    name: .handlePermission,
                    object: nil,
                    userInfo: ["permissionId": permissionId, "allowed": true]
                )
            }

        case "DENY":
            // 处理拒绝权限
            if let permissionId = userInfo["permissionId"] as? String {
                NotificationCenter.default.post(
                    name: .handlePermission,
                    object: nil,
                    userInfo: ["permissionId": permissionId, "allowed": false]
                )
            }

        case let actionId where actionId.starts(with: "OPTION_"):
            // 处理问题选项
            if let options = userInfo["options"] as? [String],
               let index = Int(actionId.replacingOccurrences(of: "OPTION_", with: "")),
               index < options.count {
                NotificationCenter.default.post(
                    name: .handleQuestion,
                    object: nil,
                    userInfo: ["questionId": userInfo["questionId"] ?? "", "answer": options[index]]
                )
            }

        default:
            // 点击通知本身，打开应用
            if let sessionId = userInfo["sessionId"] as? String {
                NotificationCenter.default.post(
                    name: .openSession,
                    object: nil,
                    userInfo: ["sessionId": sessionId]
                )
            }
        }

        completionHandler()
    }
}

// MARK: - 通知名称扩展

extension Notification.Name {
    static let handlePermission = Notification.Name("handlePermission")
    static let handleQuestion = Notification.Name("handleQuestion")
    static let openSession = Notification.Name("openSession")
    static let taskListUpdated = Notification.Name("taskListUpdated")
}
