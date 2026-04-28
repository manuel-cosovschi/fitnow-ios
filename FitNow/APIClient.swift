import Foundation
import Combine
import OSLog

// MARK: - Errors

enum APIError: LocalizedError {
    case http(Int, String)
    case unauthorized
    case badURL
    case noRefreshToken

    var errorDescription: String? {
        switch self {
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .unauthorized:             return "Sesión expirada. Por favor iniciá sesión nuevamente."
        case .badURL:                   return "URL inválida."
        case .noRefreshToken:           return "No hay token de renovación disponible."
        }
    }
}

// MARK: - Protocol

protocol APIClientProtocol {
    func request<T: Decodable>(
        _ path: String,
        method: String,
        body: Data?,
        authorized: Bool,
        query: [URLQueryItem],
        headers: [String: String]
    ) async throws -> T
}

// MARK: - Config

enum APIConfig {
    static let baseURL: URL = {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
              let url = URL(string: urlString) else {
            fatalError("APIBaseURL faltante o inválida en Info.plist")
        }
        return url
    }()
}

// MARK: - Notification

extension Notification.Name {
    static let sessionExpired = Notification.Name("FitNow.sessionExpired")
}

// MARK: - Logger (masks Authorization header)

private let log = Logger(subsystem: "com.fitnow.app", category: "Network")

// MARK: - Refresh coordinator
// Serializes concurrent token-refresh attempts inside a Swift actor so that
// only one refresh runs at a time; all latecomers await the same task.

private actor RefreshCoordinator {
    private var task: Task<Void, Error>?

    func coalesce(_ body: @escaping () async throws -> Void) async throws {
        if let existing = task {
            // A refresh is already in flight — piggyback on it.
            try await existing.value
            return
        }
        let t = Task { try await body() }
        task = t
        defer { task = nil }
        try await t.value
    }
}

// MARK: - Client

final class APIClient: APIClientProtocol {
    static let shared = APIClient()
    private init() {}

    private let tokenStore = TokenStore.shared

    let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 15
        cfg.timeoutIntervalForResource = 30
        return URLSession(configuration: cfg)
    }()

    private let refreshCoordinator = RefreshCoordinator()

    // MARK: - Primary API (async/await)

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        authorized: Bool = false,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:]
    ) async throws -> T {
        do {
            return try await performRequest(
                path, method: method, body: body,
                authorized: authorized, query: query, headers: headers
            )
        } catch APIError.unauthorized where authorized {
            try await refreshAccessToken()
            return try await performRequest(
                path, method: method, body: body,
                authorized: true, query: query, headers: headers
            )
        }
    }

    // MARK: - SSE helper
    // Exposes the configured session (with timeouts) for streaming callers.

    func bytesRequest(_ request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        try await session.bytes(for: request)
    }

    // MARK: - Combine bridge (legacy ViewModels)

    func requestPublisher<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        authorized: Bool = false,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:]
    ) -> AnyPublisher<T, Error> {
        Future { [weak self] promise in
            guard let self else { return }
            Task {
                do {
                    let result: T = try await self.request(
                        path, method: method, body: body,
                        authorized: authorized, query: query, headers: headers
                    )
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    // MARK: - Private

    private func performRequest<T: Decodable>(
        _ path: String,
        method: String,
        body: Data?,
        authorized: Bool,
        query: [URLQueryItem],
        headers: [String: String]
    ) async throws -> T {
        let req = try buildRequest(
            path, method: method, body: body,
            authorized: authorized, query: query, headers: headers
        )

        log.debug("→ \(method) \(path)")

        let (data, response) = try await withRetry { [self] in
            try await self.session.data(for: req)
        }

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        log.debug("← \(http.statusCode) \(path)")

        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 401 { throw APIError.unauthorized }
            throw APIError.http(http.statusCode, bodyText)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            log.error("Decode error \(path): \(error.localizedDescription)")
            throw error
        }
    }

    func buildRequest(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        authorized: Bool = false,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:]
    ) throws -> URLRequest {
        var components = URLComponents(url: APIConfig.baseURL, resolvingAgainstBaseURL: false)!
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let basePath  = components.path.hasSuffix("/") ? components.path : components.path + "/"
        components.path = basePath + cleanPath
        if !query.isEmpty { components.queryItems = query }

        guard let url = components.url else { throw APIError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if authorized, let token = tokenStore.accessToken {
            req.setValue("Bearer [REDACTED]", forHTTPHeaderField: "X-Debug-Auth") // debug only
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        return req
    }

    // MARK: - Refresh

    private func refreshAccessToken() async throws {
        try await refreshCoordinator.coalesce { [weak self] in
            guard let self else { return }

            guard let refreshToken = self.tokenStore.refreshToken else {
                self.expireSession()
                throw APIError.noRefreshToken
            }

            struct RefreshBody: Encodable { let refreshToken: String }
            struct RefreshResponse: Decodable { let token: String; let refreshToken: String? }

            let body = try JSONEncoder().encode(RefreshBody(refreshToken: refreshToken))

            do {
                let resp: RefreshResponse = try await self.performRequest(
                    "auth/refresh", method: "POST", body: body,
                    authorized: false, query: [], headers: [:]
                )
                self.tokenStore.store(access: resp.token, refresh: resp.refreshToken)
            } catch {
                self.expireSession()
                throw APIError.unauthorized
            }
        }
    }

    private func expireSession() {
        tokenStore.clear()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
        }
    }

    // MARK: - Retry (network errors only, exponential backoff)

    private func withRetry<T>(
        maxAttempts: Int = 3,
        _ work: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await work()
            } catch let error as URLError
                where [.notConnectedToInternet, .networkConnectionLost, .timedOut]
                    .contains(error.code) {
                lastError = error
                if attempt < maxAttempts - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    // MARK: - Convenience token accessors (for AuthViewModel compatibility)

    var token: String? { tokenStore.accessToken }
    func setToken(_ t: String) { tokenStore.accessToken = t }
    func clearToken() { tokenStore.clear() }
}
