import Foundation
import Combine

enum APIError: LocalizedError {
    case http(Int, String)
    var errorDescription: String? {
        switch self {
        case .http(let code, let body): return "HTTP \(code): \(body)"
        }
    }
}

struct APIConfig {
    static var baseURL: URL = {
        return URL(string: "https://fitnow-api-production.up.railway.app/api")!
    }()
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    let baseURL = APIConfig.baseURL
    private let tokenKey = "auth_token"

    var token: String? { KeychainService.readToken(for: tokenKey) }
    func setToken(_ t: String) { KeychainService.save(token: t, for: tokenKey) }
    func clearToken() { KeychainService.remove(key: tokenKey) }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        authorized: Bool = false,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:]
    ) -> AnyPublisher<T, Error> {

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        if components.path.hasSuffix("/") {
            components.path += cleanPath
        } else {
            components.path += "/\(cleanPath)"
        }
        components.queryItems = query.isEmpty ? nil : query

        guard let url = components.url else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = method

        if let body = body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if authorized, let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        return URLSession.shared.dataTaskPublisher(for: req)
            .tryMap { data, resp in
                guard let http = resp as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200..<300).contains(http.statusCode) else {
                    let bodyText = String(data: data, encoding: .utf8) ?? ""
                    throw APIError.http(http.statusCode, bodyText)
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}



