// API 服务

import Foundation

class APIService {
    static let shared = APIService()

    private var baseUrl: String = ""

    private init() {}

    func setBaseUrl(_ url: String) {
        var processedUrl = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var isSecure = false

        // 1. 先移除协议前缀并记录是否使用 HTTPS
        if processedUrl.hasPrefix("https://") {
            isSecure = true
            processedUrl = String(processedUrl.dropFirst(8))
        } else if processedUrl.hasPrefix("http://") {
            processedUrl = String(processedUrl.dropFirst(7))
        }

        // 2. 处理特殊格式：host:port:token
        // 格式可能是：192.168.3.34:50427:UVU248 或 xxx.tunnel.com:443:token
        let colonCount = processedUrl.filter { $0 == ":" }.count
        if colonCount >= 2 {
            let parts = processedUrl.split(separator: ":")
            if parts.count >= 2 {
                let host = String(parts[0])
                let port = String(parts[1])
                processedUrl = "\(host):\(port)"
                print("[APIService] 🔧 Parsed host:port:token format, extracted: \(processedUrl)")
            }
        }

        // 3. 根据 tunnel 或安全连接决定协议
        let isTunnel = processedUrl.contains(".tunnel.") ||
                       processedUrl.contains("trycloudflare") ||
                       processedUrl.contains("loca.lt")

        if isSecure || isTunnel {
            processedUrl = "https://" + processedUrl
        } else {
            processedUrl = "http://" + processedUrl
        }

        self.baseUrl = processedUrl
        print("[APIService] 🔧 Final baseUrl: \(self.baseUrl)")
    }

    // MARK: - 会话 API

    func getSessions() async throws -> [Session] {
        let data = try await request("/api/sessions")
        let response = try JSONDecoder().decode(SessionsResponse.self, from: data)
        return response.sessions
    }

    func createSession(workDir: String? = nil) async throws -> CreateSessionResponse {
        var body: [String: String] = [:]
        if let dir = workDir {
            body["workDir"] = dir
        }
        let data = try await request("/api/sessions", method: "POST", body: body.isEmpty ? nil : body)
        return try JSONDecoder().decode(CreateSessionResponse.self, from: data)
    }

    func deleteSession(_ sessionId: String) async throws {
        _ = try await request("/api/sessions/\(sessionId)", method: "DELETE")
    }

    func renameSession(_ sessionId: String, title: String) async throws {
        _ = try await request("/api/sessions/\(sessionId)", method: "PATCH", body: ["title": title])
    }

    func getRecentProjects() async throws -> [RecentProject] {
        let data = try await request("/api/sessions/recent-projects")
        let response = try JSONDecoder().decode(RecentProjectsResponse.self, from: data)
        return response.projects
    }

    // MARK: - 消息 API

    func getMessages(_ sessionId: String) async throws -> [Message] {
        let data = try await request("/api/sessions/\(sessionId)/messages")
        let response = try JSONDecoder().decode(MessagesResponse.self, from: data)
        return transformMessages(response.messages.compactMap { $0 })
    }

    // MARK: - 服务商 API

    func getProviders() async throws -> ProvidersResponse {
        let data = try await request("/api/providers")
        return try JSONDecoder().decode(ProvidersResponse.self, from: data)
    }

    func createProvider(_ input: ProviderInput) async throws -> ProviderResponse {
        let data = try await request("/api/providers", method: "POST", body: input)
        return try JSONDecoder().decode(ProviderResponse.self, from: data)
    }

    func updateProvider(_ id: String, _ input: ProviderInput) async throws -> ProviderResponse {
        let data = try await request("/api/providers/\(id)", method: "PUT", body: input)
        return try JSONDecoder().decode(ProviderResponse.self, from: data)
    }

    func deleteProvider(_ id: String) async throws {
        _ = try await request("/api/providers/\(id)", method: "DELETE")
    }

    func testProvider(_ id: String, overrides: ProviderTestOverrides? = nil) async throws -> ProviderTestResultResponse {
        let data = try await request("/api/providers/\(id)/test", method: "POST", body: overrides)
        return try JSONDecoder().decode(ProviderTestResultResponse.self, from: data)
    }

    func activateProvider(_ id: String) async throws {
        _ = try await request("/api/providers/\(id)/activate", method: "POST")
    }

    func activateOfficialProvider() async throws {
        _ = try await request("/api/providers/official", method: "POST")
    }

    // MARK: - 模型 API

    func getModels() async throws -> ModelsResponse {
        let data = try await request("/api/models")
        return try JSONDecoder().decode(ModelsResponse.self, from: data)
    }

    func getCurrentModel() async throws -> CurrentModelResponse {
        let data = try await request("/api/models/current")
        return try JSONDecoder().decode(CurrentModelResponse.self, from: data)
    }

    func setCurrentModel(_ modelId: String) async throws {
        _ = try await request("/api/models/current", method: "PUT", body: ["modelId": modelId])
    }

    // MARK: - Effort API

    func getEffort() async throws -> EffortResponse {
        let data = try await request("/api/effort")
        return try JSONDecoder().decode(EffortResponse.self, from: data)
    }

    func setEffort(_ level: String) async throws {
        _ = try await request("/api/effort", method: "PUT", body: ["level": level])
    }

    // MARK: - 网络 API

    func getNetworkInfo() async throws -> NetworkInfo {
        let paths = ["/api/mobile/network-info", "/api/mobile/networkInfo"]
        for path in paths {
            do {
                let data = try await request(path)
                return try JSONDecoder().decode(NetworkInfo.self, from: data)
            } catch {
                continue
            }
        }
        return NetworkInfo(lanUrl: nil, tunnelUrl: nil, tunnelEnabled: false, serverPort: 0)
    }

    func getPairingCode() async throws -> PairingCodeResponse {
        let paths = ["/api/mobile/pairing-code", "/api/mobile/pairingCode"]
        var lastError: Error?
        for path in paths {
            do {
                let data = try await request(path, method: "POST", body: ["ttlHours": 1])
                return try JSONDecoder().decode(PairingCodeResponse.self, from: data)
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError ?? APIError.invalidResponse
    }

    func enableTunnel(_ enabled: Bool) async throws -> TunnelResponse {
        let paths = ["/api/mobile/tunnel", "/api/mobile/tunnel/enable"]
        var lastError: Error?
        for path in paths {
            do {
                let data = try await request(path, method: "POST", body: ["enabled": enabled])
                return try JSONDecoder().decode(TunnelResponse.self, from: data)
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError ?? APIError.invalidResponse
    }

    // MARK: - 消息转换

    private func transformMessages(_ rawMessages: [RawMessage]) -> [Message] {
        var result: [Message] = []

        for msg in rawMessages {
            let msgId = msg.id ?? "\(msg.type ?? "unknown")-\(msg.timestamp ?? "")-\(result.count)"
            let timestamp = msg.timestamp ?? ""

            // 用户消息
            if msg.type == "user" {
                let text = extractText(msg.content)
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(Message(
                        id: msgId,
                        type: .user,
                        content: text.trimmingCharacters(in: .whitespacesAndNewlines),
                        timestamp: timestamp
                    ))
                }
                continue
            }

            // 助手消息
            if msg.type == "assistant" {
                if let content = msg.content {
                    if let blocks = content.value as? [[String: Any]] {
                        for (blockIdx, block) in blocks.enumerated() {
                            let blockType = block["type"] as? String ?? ""

                            if blockType == "text" {
                                let text = (block["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                if !text.isEmpty {
                                    result.append(Message(
                                        id: "\(msgId)-text-\(blockIdx)",
                                        type: .assistant,
                                        content: text,
                                        timestamp: timestamp
                                    ))
                                }
                            } else if blockType == "tool_use" {
                                let toolName = block["name"] as? String ?? "Unknown"
                                let toolInput = (block["input"] as? [String: Any] ?? [:]).mapValues { AnyCodable(value: $0) }
                                result.append(Message(
                                    id: "\(msgId)-tool-\(blockIdx)",
                                    type: .toolUse,
                                    content: "",
                                    timestamp: timestamp,
                                    toolName: toolName,
                                    toolInput: toolInput
                                ))
                            } else if blockType == "thinking" {
                                let text = (block["thinking"] as? String ?? block["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                if !text.isEmpty {
                                    result.append(Message(
                                        id: "\(msgId)-thinking-\(blockIdx)",
                                        type: .thinking,
                                        content: text,
                                        timestamp: timestamp
                                    ))
                                }
                            }
                        }
                    } else if let text = content.value as? String {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        // 隐藏 JSON 格式的工具调用链消息
                        if !trimmed.isEmpty && !(trimmed.hasPrefix("[{") && (trimmed.contains("\"tool_use_id\"") || trimmed.contains("\"tool_result\""))) {
                            result.append(Message(
                                id: msgId,
                                type: .assistant,
                                content: trimmed,
                                timestamp: timestamp
                            ))
                        }
                    }
                }
                continue
            }

            // 工具结果消息
            if msg.type == "tool_result" {
                var resultContent = ""
                if let content = msg.content {
                    if let text = content.value as? String {
                        resultContent = text
                    } else if let blocks = content.value as? [[String: Any]] {
                        resultContent = blocks.compactMap { $0["text"] as? String }.joined()
                    } else {
                        resultContent = String(describing: content.value)
                    }
                }

                // 隐藏 JSON 格式的工具调用链消息
                let trimmed = resultContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("[{") && (trimmed.contains("\"tool_use_id\"") || trimmed.contains("\"tool_result\"")) {
                    continue // 跳过，不添加到结果中
                }

                let isError = msg.isError ?? false
                result.append(Message(
                    id: msgId,
                    type: .toolResult,
                    content: "",
                    timestamp: timestamp,
                    toolResult: resultContent,
                    toolStatus: isError ? .failed : .completed
                ))
                continue
            }

            // thinking 消息
            if msg.type == "thinking" {
                let text = (msg.thinking ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    result.append(Message(
                        id: msgId,
                        type: .thinking,
                        content: text,
                        timestamp: timestamp
                    ))
                }
            }
        }

        // 配对 tool_use 和 tool_result
        pairToolResults(&result)

        return result
    }

    private func extractText(_ content: AnyCodable?) -> String {
        guard let content = content else { return "" }
        if let text = content.value as? String {
            return text
        } else if let blocks = content.value as? [[String: Any]] {
            return blocks
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
        } else if let dict = content.value as? [String: Any], let text = dict["text"] as? String {
            return text
        }
        return ""
    }

    private func pairToolResults(_ messages: inout [Message]) {
        var toRemove: Set<Int> = []

        for i in 0..<messages.count {
            if messages[i].type == .toolResult {
                for j in stride(from: i - 1, through: 0, by: -1) {
                    if messages[j].type == .toolUse && messages[j].toolResult == nil {
                        messages[j].toolResult = messages[i].toolResult
                        messages[j].toolStatus = messages[i].toolStatus ?? .completed
                        toRemove.insert(i)
                        break
                    }
                }
            }
        }

        if !toRemove.isEmpty {
            messages = messages.enumerated().filter { !toRemove.contains($0.offset) }.map { $0.element }
        }
    }

    // MARK: - 私有方法

    private func request<T: Encodable>(
        _ path: String,
        method: String = "GET",
        body: T? = nil
    ) async throws -> Data {
        guard let url = URL(string: baseUrl + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["message"] as? String {
                throw APIError.httpError(httpResponse.statusCode, message)
            }
            throw APIError.httpError(httpResponse.statusCode, nil)
        }

        return data
    }

    private func request(
        _ path: String,
        method: String = "GET"
    ) async throws -> Data {
        guard let url = URL(string: baseUrl + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode, nil)
        }

        return data
    }
}

// MARK: - 响应模型

struct SessionsResponse: Codable {
    let sessions: [Session]
}

struct MessagesResponse: Codable {
    let messages: [RawMessage?]
}

struct CreateSessionResponse: Codable {
    let sessionId: String
}

struct RecentProjectsResponse: Codable {
    let projects: [RecentProject]
}

struct ProvidersResponse: Codable {
    let providers: [Provider]
    let activeId: String?
}

struct ProviderResponse: Codable {
    let provider: Provider
}

struct ProviderTestResultResponse: Codable {
    let result: ProviderTestResult

    struct ProviderTestResult: Codable {
        let connectivity: ConnectivityResult

        struct ConnectivityResult: Codable {
            let success: Bool
            let latencyMs: Int?
            let error: String?
        }
    }
}

struct ModelsResponse: Codable {
    let models: [ModelInfo]
    let provider: ProviderInfo?
}

struct CurrentModelResponse: Codable {
    let model: ModelInfo
}

struct ModelInfo: Codable {
    let id: String
    let name: String
    let description: String?
}

struct ProviderInfo: Codable {
    let id: String
    let name: String
}

struct EffortResponse: Codable {
    let level: String
    let available: [String]
}

// 原始消息格式
struct RawMessage: Codable {
    let id: String?
    let type: String?
    let content: AnyCodable?
    let timestamp: String?
    let isError: Bool?
    let thinking: String?
}

// 网络信息
struct NetworkInfo: Codable {
    let lanUrl: String?
    let tunnelUrl: String?
    let tunnelEnabled: Bool
    let serverPort: Int
}

// 配对码响应
struct PairingCodeResponse: Codable {
    let pairingCode: String
    let expiresAt: Int
    let createdAt: Int
}

// 隧道响应
struct TunnelResponse: Codable {
    let ok: Bool
    let tunnelUrl: String?
    let error: String?
}

// 服务商输入
struct ProviderInput: Codable {
    let presetId: String
    let name: String
    let apiKey: String
    let baseUrl: String
    let apiFormat: ApiFormat?
    let models: ModelMapping
    let notes: String?
}

struct ProviderTestOverrides: Codable {
    let baseUrl: String?
    let modelId: String?
    let apiFormat: String?
}

// 服务商测试结果
struct ProviderTestResult: Codable {
    let connectivity: ConnectivityResult

    struct ConnectivityResult: Codable {
        let success: Bool
        let latencyMs: Int?
        let error: String?
    }
}

// MARK: - 错误类型

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String?)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code, let message):
            if let msg = message {
                return "HTTP 错误 \(code): \(msg)"
            }
            return "HTTP 错误: \(code)"
        case .decodingError:
            return "数据解析错误"
        }
    }
}
