// API 服务

import Foundation

class APIService {
    static let shared = APIService()

    private var baseUrl: String = ""

    private init() {}

    func setBaseUrl(_ url: String) {
        self.baseUrl = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    // MARK: - 会话 API

    func getSessions() async throws -> [Session] {
        let data = try await request("/api/sessions")
        let response = try JSONDecoder().decode([Session].self, from: data)
        return response
    }

    func createSession(projectPath: String? = nil) async throws -> Session {
        var body: [String: String] = [:]
        if let path = projectPath {
            body["projectPath"] = path
        }
        let data = try await request("/api/sessions", method: "POST", body: body)
        let response = try JSONDecoder().decode(Session.self, from: data)
        return response
    }

    func deleteSession(_ sessionId: String) async throws {
        _ = try await request("/api/sessions/\(sessionId)", method: "DELETE")
    }

    func renameSession(_ sessionId: String, title: String) async throws {
        _ = try await request("/api/sessions/\(sessionId)/rename", method: "POST", body: ["title": title])
    }

    // MARK: - 消息 API

    func getMessages(_ sessionId: String) async throws -> [Message] {
        let data = try await request("/api/sessions/\(sessionId)/messages")
        let response = try JSONDecoder().decode([Message].self, from: data)
        return response
    }

    // MARK: - 服务商 API

    func getProviders() async throws -> [Provider] {
        let data = try await request("/api/providers")
        let response = try JSONDecoder().decode([Provider].self, from: data)
        return response
    }

    func createProvider(_ input: CreateProviderInput) async throws -> Provider {
        let data = try await request("/api/providers", method: "POST", body: input)
        let response = try JSONDecoder().decode(Provider.self, from: data)
        return response
    }

    func updateProvider(_ id: String, _ input: UpdateProviderInput) async throws -> Provider {
        let data = try await request("/api/providers/\(id)", method: "PUT", body: input)
        let response = try JSONDecoder().decode(Provider.self, from: data)
        return response
    }

    func deleteProvider(_ id: String) async throws {
        _ = try await request("/api/providers/\(id)", method: "DELETE")
    }

    func testProvider(_ id: String) async throws -> ProviderTestResult {
        let data = try await request("/api/providers/\(id)/test", method: "POST")
        let response = try JSONDecoder().decode(ProviderTestResult.self, from: data)
        return response
    }

    // MARK: - 网络 API

    func getNetworkInfo() async throws -> NetworkInfo {
        let data = try await request("/api/network/info")
        let response = try JSONDecoder().decode(NetworkInfo.self, from: data)
        return response
    }

    func getPairingCode() async throws -> PairingCodeResponse {
        let data = try await request("/api/network/pairing-code", method: "POST")
        let response = try JSONDecoder().decode(PairingCodeResponse.self, from: data)
        return response
    }

    func enableTunnel(_ enabled: Bool) async throws -> TunnelResponse {
        let data = try await request("/api/network/tunnel", method: "POST", body: ["enabled": enabled])
        let response = try JSONDecoder().decode(TunnelResponse.self, from: data)
        return response
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try? JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        return data
    }
}

// MARK: - 响应模型

struct ProviderTestResult: Codable {
    let result: TestResult

    struct TestResult: Codable {
        let connectivity: Connectivity

        struct Connectivity: Codable {
            let success: Bool
            let latencyMs: Int?
            let error: String?
        }
    }
}

struct NetworkInfo: Codable {
    let lanUrl: String
    let tunnelUrl: String?
    let tunnelEnabled: Bool
}

struct PairingCodeResponse: Codable {
    let pairingCode: String
    let expiresAt: String
}

struct TunnelResponse: Codable {
    let tunnelUrl: String?
    let enabled: Bool
}

// MARK: - 错误类型

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .decodingError:
            return "数据解析错误"
        }
    }
}
