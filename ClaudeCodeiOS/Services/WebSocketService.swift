// WebSocket 服务

import Foundation
import Combine

class WebSocketService: NSObject, ObservableObject {
    static let shared = WebSocketService()

    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastMessage: WSMessage?

    private var webSocketTask: URLSessionWebSocketTask?
    private var sessionId: String?
    private var cancellables = Set<AnyCancellable>()

    enum ConnectionStatus {
        case connecting
        case connected
        case disconnected
        case reconnecting
        case error(String)
    }

    private override init() {
        super.init()
    }

    // MARK: - 连接管理

    func connect(serverUrl: String, sessionId: String? = nil) {
        guard let url = URL(string: serverUrl) else { return }

        self.sessionId = sessionId
        connectionStatus = .connecting

        // 转换 HTTP URL 为 WebSocket URL
        var wsUrl = url.absoluteString
        if wsUrl.hasPrefix("https://") {
            wsUrl = "wss://" + wsUrl.dropFirst(8)
        } else if wsUrl.hasPrefix("http://") {
            wsUrl = "ws://" + wsUrl.dropFirst(7)
        }

        // 添加 WebSocket 路径
        if let sid = sessionId {
            wsUrl += "/ws?sessionId=\(sid)"
        } else {
            wsUrl += "/ws"
        }

        guard let websocketUrl = URL(string: wsUrl) else { return }

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

    // MARK: - 消息收发

    func send(_ message: OutgoingMessage) {
        guard let task = webSocketTask, isConnected else { return }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let data = try? encoder.encode(message),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }

        task.send(.string(jsonString)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
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

                // 继续接收下一条消息
                self.receiveMessage()

            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self.connectionStatus = .error(error.localizedDescription)
            }
        }
    }

    private func parseMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // 尝试解析消息
        if let message = try? decoder.decode(WSMessage.self, from: data) {
            DispatchQueue.main.async {
                self.lastMessage = message
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = .connected
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = .disconnected
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
