import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case networkError(Error)
    case decodingError(Error)
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication expired — run Claude Code to refresh"
        case .rateLimited:
            return "Rate limited — will retry shortly"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        }
    }

    var isAuthError: Bool {
        if case .unauthorized = self { return true }
        return false
    }

    var isRateLimited: Bool {
        if case .rateLimited = self { return true }
        return false
    }
}

final class AnthropicAPIClient {
    static let shared = AnthropicAPIClient()

    private let session: URLSession
    private let baseURL = "https://api.anthropic.com/api/oauth"
    private let betaHeader = "oauth-2025-04-20"
    private let userAgent = "claude-code/2.1.44"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    func fetchUsage(token: String) async throws -> UsageResponse {
        let request = try buildRequest(path: "/usage", token: token)
        return try await perform(request)
    }

    func fetchProfile(token: String) async throws -> ProfileResponse {
        let request = try buildRequest(path: "/profile", token: token)
        return try await perform(request)
    }

    private func buildRequest(path: String, token: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.networkError(URLError(.badURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw APIError.unauthorized
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw APIError.rateLimited(retryAfter: retryAfter)
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(httpResponse.statusCode, body)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
