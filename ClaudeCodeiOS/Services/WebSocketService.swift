// WebSocket 服务

import Foundation
import Combine

// 单个会话连接的状态
struct SessionWSConnection {
    var task: URLSessionWebSocketTask?
    var status: WSConnectionStatus
    var lastActivity: Date
    var reconnectAttempts: Int = 0
}

enum WSConnectionStatus {
    case connecting
    case connected
    case disconnected
    case error
}

class WebSocketService: NSObject, ObservableObject {
    static let shared = WebSocketService()

    // 单会话模式（兼容旧代码）
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastMessage: WSMessage?

    // 多会话全局模式
    @Published var globalConnections: [String: SessionWSConnection] = [:]
    @Published var globalLastMessage: (sessionId: String, message: WSMessage)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var sessionId: String?

    // 全局连接管理
    private var urlSession: URLSession!
    private var serverUrl: String = ""
    var subscribedSessions: Set<String> = []  // 改为公开，供外部检查
    private var reconnectTimers: [String: Timer] = [:]
    private var cleanupTimer: Timer?
    private var heartbeatTimer: Timer?  // 心跳检测定时器

    enum ConnectionStatus {
        case connecting
        case connected
        case disconnected
        case reconnecting
        case error(String)
    }

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        // 定期清理空闲连接
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.cleanupIdleConnections()
        }

        // 心跳检测：每 30 秒检查一次连接状态
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkAndReconnectBrokenConnections()
        }
    }

    /// 检查并重连断开的连接
    private func checkAndReconnectBrokenConnections() {
        guard !serverUrl.isEmpty else { return }

        for sessionId in subscribedSessions {
            if let conn = globalConnections[sessionId] {
                // 如果连接状态是 disconnected 或 error，尝试重连
                if conn.status == .disconnected || conn.status == .error || conn.task == nil {
                    print("[GlobalWS] 💓 Heartbeat: reconnecting broken connection for \(sessionId)")
                    connectGlobal(sessionId: sessionId)
                }
            } else {
                // 如果连接不存在，创建新连接
                print("[GlobalWS] 💓 Heartbeat: creating missing connection for \(sessionId)")
                connectGlobal(sessionId: sessionId)
            }
        }
    }

    // MARK: - 单会话模式（兼容旧代码）

    func connect(serverUrl: String, sessionId: String? = nil) {
        guard !serverUrl.isEmpty else { return }

        self.sessionId = sessionId
        connectionStatus = .connecting

        var wsUrl = serverUrl

        // 1. 移除协议前缀（如果有）
        if wsUrl.hasPrefix("https://") {
            wsUrl = String(wsUrl.dropFirst(8))
        } else if wsUrl.hasPrefix("http://") {
            wsUrl = String(wsUrl.dropFirst(7))
        }

        // 2. 处理特殊格式：host:port:token
        let colonCount = wsUrl.filter { $0 == ":" }.count
        if colonCount >= 2 {
            let parts = wsUrl.split(separator: ":")
            if parts.count >= 2 {
                let host = String(parts[0])
                let port = String(parts[1])
                wsUrl = "\(host):\(port)"
                print("[WebSocket] 🔧 Parsed host:port:token format, extracted: \(wsUrl)")
            }
        }

        // 3. 根据原始 URL 决定使用 ws:// 还是 wss://
        let useSecure = serverUrl.hasPrefix("https://") ||
                        serverUrl.contains(".tunnel.") ||
                        serverUrl.contains("trycloudflare") ||
                        serverUrl.contains("loca.lt")

        let scheme = useSecure ? "wss://" : "ws://"
        wsUrl = scheme + wsUrl

        if let sid = sessionId {
            wsUrl += "/ws/\(sid)"
        } else {
            wsUrl += "/ws"
        }

        guard let websocketUrl = URL(string: wsUrl) else {
            print("[WebSocket] ❌ Invalid URL: \(wsUrl)")
            return
        }

        print("[WebSocket] Connecting to: \(wsUrl)")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: websocketUrl)
        webSocketTask?.resume()

        receiveMessage()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        connectionStatus = .disconnected
    }

    func send(_ message: OutgoingMessage) {
        guard let task = webSocketTask else {
            print("[WebSocket] ❌ send: no task")
            return
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let data = try? encoder.encode(message),
              let jsonString = String(data: data, encoding: .utf8) else {
            print("[WebSocket] ❌ send: failed to encode")
            return
        }

        print("[WebSocket] 📤 Sending: \(jsonString.prefix(100))")
        task.send(.string(jsonString)) { error in
            if let error = error {
                print("[WebSocket] ❌ send error: \(error)")
            } else {
                print("[WebSocket] ✅ Sent successfully")
            }
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.parseMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.parseMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveMessage()

            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self.connectionStatus = .error(error.localizedDescription)
            }
        }
    }

    private func parseMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        print("[WebSocket] Received: \(text.prefix(200))")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        if let message = try? decoder.decode(WSMessage.self, from: data) {
            DispatchQueue.main.async {
                self.lastMessage = message
            }
        } else {
            print("[WebSocket] Failed to parse message")
        }
    }

    // MARK: - 全局多会话模式

    /// 订阅所有会话的消息
    func subscribeToAllSessions(serverUrl: String, sessionIds: [String]) {
        print("[GlobalWS] 🚀 subscribeToAllSessions: \(sessionIds.count) sessions, serverUrl: \(serverUrl)")
        self.serverUrl = serverUrl

        for sessionId in sessionIds {
            if !subscribedSessions.contains(sessionId) {
                subscribedSessions.insert(sessionId)
                connectGlobal(sessionId: sessionId)
            }
        }

        // 清理不再需要的连接
        for existingId in globalConnections.keys {
            if !sessionIds.contains(existingId) {
                disconnectGlobal(sessionId: existingId)
            }
        }

        print("[GlobalWS] ✅ Total subscribed sessions: \(subscribedSessions.count)")
    }

    /// 发送消息到指定会话
    func sendGlobal(sessionId: String, message: OutgoingMessage) -> Bool {
        // 如果连接不存在，尝试立即建立连接
        if globalConnections[sessionId] == nil || globalConnections[sessionId]?.task == nil {
            print("[GlobalWS] ⚠️ No connection for \(sessionId), attempting to connect...")
            if !serverUrl.isEmpty {
                // 确保会话在订阅列表中
                if !subscribedSessions.contains(sessionId) {
                    subscribedSessions.insert(sessionId)
                    print("[GlobalWS] 📝 Added \(sessionId) to subscribedSessions")
                }
                connectGlobal(sessionId: sessionId)
            } else {
                print("[GlobalWS] ❌ Cannot connect: serverUrl empty")
                return false
            }
        }

        guard let conn = globalConnections[sessionId],
              let task = conn.task else {
            print("[GlobalWS] ❌ Still no connection for \(sessionId) after retry")
            return false
        }

        // 只要 task 存在就尝试发送，不要求必须是 .connected 状态
        // 因为 task 已经 resume 后就可以发送了
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let data = try? encoder.encode(message),
              let jsonString = String(data: data, encoding: .utf8) else {
            return false
        }

        print("[GlobalWS] 📤 Sending to \(sessionId): \(jsonString.prefix(100))")
        task.send(.string(jsonString)) { error in
            if let error = error {
                print("[GlobalWS] ❌ Send error for \(sessionId): \(error)")
            } else {
                print("[GlobalWS] ✅ Sent successfully to \(sessionId)")
            }
        }

        return true
    }

    /// 断开指定会话连接
    func disconnectGlobal(sessionId: String) {
        guard var conn = globalConnections[sessionId] else { return }
        conn.task?.cancel(with: .normalClosure, reason: nil)
        conn.task = nil
        conn.status = .disconnected
        globalConnections[sessionId] = conn
        subscribedSessions.remove(sessionId)

        reconnectTimers[sessionId]?.invalidate()
        reconnectTimers.removeValue(forKey: sessionId)
    }

    /// 断开所有全局连接
    func disconnectAllGlobal() {
        for sessionId in globalConnections.keys {
            disconnectGlobal(sessionId: sessionId)
        }
    }

    /// 检查是否已订阅全局
    var isGlobalSubscribed: Bool {
        return !subscribedSessions.isEmpty
    }

    /// 检查指定会话的连接状态
    func isSessionConnected(_ sessionId: String) -> Bool {
        guard let conn = globalConnections[sessionId] else { return false }
        return conn.status == .connected && conn.task != nil
    }

    /// 确保会话已连接（如果未连接则尝试连接）
    func ensureSessionConnected(serverUrl: String, sessionId: String) {
        if !isSessionConnected(sessionId) {
            print("[GlobalWS] ⚠️ Session \(sessionId) not connected, reconnecting...")
            if !subscribedSessions.contains(sessionId) {
                subscribedSessions.insert(sessionId)
            }
            connectGlobal(sessionId: sessionId)
        }
    }

    private func connectGlobal(sessionId: String) {
        print("[GlobalWS] 🔧 connectGlobal called for \(sessionId)")
        print("[GlobalWS] 🔧 serverUrl = '\(serverUrl)'")

        guard !serverUrl.isEmpty else {
            print("[GlobalWS] ❌ serverUrl is empty, cannot connect")
            return
        }

        var wsUrl = serverUrl
        print("[GlobalWS] 🔧 Original serverUrl: \(wsUrl)")

        // 1. 移除协议前缀（如果有）
        if wsUrl.hasPrefix("https://") {
            wsUrl = String(wsUrl.dropFirst(8))
        } else if wsUrl.hasPrefix("http://") {
            wsUrl = String(wsUrl.dropFirst(7))
        }

        // 2. 处理特殊格式：host:port:token
        // 如果有多个冒号，可能是 IP:Port:Token 格式
        let colonCount = wsUrl.filter { $0 == ":" }.count
        if colonCount >= 2 {
            // 格式可能是 host:port:token 或 host:port:token:xxx
            let parts = wsUrl.split(separator: ":")
            if parts.count >= 2 {
                // 取前两部分作为 host:port
                let host = String(parts[0])
                let port = String(parts[1])
                wsUrl = "\(host):\(port)"
                print("[GlobalWS] 🔧 Parsed host:port:token format, extracted: \(wsUrl)")
            }
        }

        // 3. 根据原始 URL 决定使用 ws:// 还是 wss://
        let useSecure = serverUrl.hasPrefix("https://") ||
                        serverUrl.contains(".tunnel.") ||
                        serverUrl.contains("trycloudflare") ||
                        serverUrl.contains("loca.lt")

        let scheme = useSecure ? "wss://" : "ws://"
        wsUrl = scheme + wsUrl + "/ws/\(sessionId)"

        print("[GlobalWS] 🔧 Final wsUrl: \(wsUrl)")

        guard let url = URL(string: wsUrl) else {
            print("[GlobalWS] ❌ Invalid URL: \(wsUrl)")
            return
        }

        print("[GlobalWS] 🚀 Connecting to: \(wsUrl)")

        // 先检查是否已有连接
        if let existingConn = globalConnections[sessionId],
           let existingTask = existingConn.task,
           existingConn.status == .connected {
            print("[GlobalWS] ⚠️ Already connected to \(sessionId)")
            return
        }

        // 创建新连接
        let task = urlSession.webSocketTask(with: url)
        var conn = SessionWSConnection(
            task: task,
            status: .connecting,
            lastActivity: Date()
        )
        globalConnections[sessionId] = conn

        task.resume()
        print("[GlobalWS] 📡 Task resumed for \(sessionId)")

        receiveGlobalMessage(sessionId: sessionId)
    }

    private func receiveGlobalMessage(sessionId: String) {
        guard let conn = globalConnections[sessionId], let task = conn.task else { return }

        task.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.parseGlobalMessage(sessionId: sessionId, text: text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.parseGlobalMessage(sessionId: sessionId, text: text)
                    }
                @unknown default:
                    break
                }
                self.receiveGlobalMessage(sessionId: sessionId)

            case .failure(let error):
                print("[GlobalWS] Receive error for \(sessionId): \(error)")
                if var c = self.globalConnections[sessionId] {
                    c.status = .error
                    self.globalConnections[sessionId] = c
                }
                self.scheduleGlobalReconnect(sessionId: sessionId)
            }
        }
    }

    private func parseGlobalMessage(sessionId: String, text: String) {
        guard let data = text.data(using: .utf8) else { return }

        print("[GlobalWS] 📩 Raw JSON for \(sessionId): \(text)")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard var message = try? decoder.decode(WSMessage.self, from: data) else {
            print("[GlobalWS] ❌ Failed to parse message for \(sessionId): \(text)")
            return
        }

        if message.sessionId == nil {
            message.sessionId = sessionId
        }

        if var conn = globalConnections[sessionId] {
            conn.lastActivity = Date()
            conn.reconnectAttempts = 0
            globalConnections[sessionId] = conn
        }

        print("[GlobalWS] 📩 Received \(message.type) for \(sessionId)")
        if message.type == .userMessageEcho {
            print("[GlobalWS] 📩 user_message_echo content: \(message.content?.value ?? "nil")")
        }

        DispatchQueue.main.async {
            self.globalLastMessage = (sessionId, message)
        }

        if message.type == .connected {
            if var conn = self.globalConnections[sessionId] {
                conn.status = .connected
                self.globalConnections[sessionId] = conn
                print("[GlobalWS] ✅ Connected: \(sessionId)")
            }
        }
    }

    private func scheduleGlobalReconnect(sessionId: String) {
        guard subscribedSessions.contains(sessionId) else { return }

        var conn = globalConnections[sessionId] ?? SessionWSConnection(
            task: nil,
            status: .disconnected,
            lastActivity: Date()
        )

        if conn.reconnectAttempts >= 5 {
            print("[GlobalWS] Max reconnect attempts for \(sessionId)")
            return
        }

        conn.reconnectAttempts += 1
        globalConnections[sessionId] = conn

        let delay = min(1000 * Int(pow(2.0, Double(conn.reconnectAttempts))), 10000)

        print("[GlobalWS] Reconnecting to \(sessionId) in \(delay)ms")

        reconnectTimers[sessionId]?.invalidate()
        reconnectTimers[sessionId] = Timer.scheduledTimer(withTimeInterval: Double(delay) / 1000, repeats: false) { [weak self] _ in
            self?.connectGlobal(sessionId: sessionId)
        }
    }

    private func cleanupIdleConnections() {
        let now = Date()
        // 只清理不在订阅列表中的连接（超过 5 分钟无活动）
        // 订阅中的连接不会被清理，因为需要持续接收消息
        for (sessionId, conn) in globalConnections {
            // 如果还在订阅列表中，不清理
            if subscribedSessions.contains(sessionId) {
                continue
            }
            // 超过 5 分钟无活动且没有订阅者的连接才清理
            if now.timeIntervalSince(conn.lastActivity) > 300 {
                print("[GlobalWS] Cleaning up idle connection: \(sessionId)")
                disconnectGlobal(sessionId: sessionId)
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // 查找对应的 sessionId
        let sessionId = globalConnections.first { $0.value.task === webSocketTask }?.key

        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = .connected
            print("[WebSocket] Connected")

            // 更新全局连接状态
            if let sid = sessionId, var conn = self.globalConnections[sid] {
                conn.status = .connected
                self.globalConnections[sid] = conn
                print("[GlobalWS] ✅ WebSocket task opened for \(sid)")
            }
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        // 查找对应的 sessionId
        let sessionId = globalConnections.first { $0.value.task === webSocketTask }?.key

        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = .disconnected
            print("[WebSocket] Disconnected")

            // 更新全局连接状态并触发重连
            if let sid = sessionId, var conn = self.globalConnections[sid] {
                conn.status = .disconnected
                conn.task = nil  // 清空 task
                self.globalConnections[sid] = conn
                print("[GlobalWS] 🔌 WebSocket task closed for \(sid), scheduling reconnect...")
                // 断开后自动重连
                self.scheduleGlobalReconnect(sessionId: sid)
            }
        }
    }
}

// MARK: - 发送消息类型

struct OutgoingMessage: Encodable {
    let type: String
    var content: String?
    var requestId: String?
    var allowed: Bool?
    var rule: String?
    var questionId: String?
    var answer: String?

    static func userMessage(_ content: String) -> OutgoingMessage {
        OutgoingMessage(type: "user_message", content: content)
    }

    static func stop() -> OutgoingMessage {
        OutgoingMessage(type: "stop")
    }

    static func permissionResponse(requestId: String, allowed: Bool, always: Bool = false) -> OutgoingMessage {
        var msg = OutgoingMessage(type: "permission_response", requestId: requestId, allowed: allowed)
        if always {
            msg.rule = "always"
        }
        return msg
    }

    static func questionResponse(questionId: String, answer: String) -> OutgoingMessage {
        OutgoingMessage(type: "question_response", questionId: questionId, answer: answer)
    }
}
