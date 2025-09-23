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

final class APIClient {
    static let shared = APIClient()
    private init() {}

    // Lee la base desde Info.plist; si no existe, usa un fallback
    private let baseURL: URL = {
        let s = Bundle.main.object(
            forInfoDictionaryKey: "APIBaseURL"
        ) as? String ?? {
            #if targetEnvironment(simulator)
            return "http://127.0.0.1:3000/api/"
            #else
            // Reemplazá por tu IP en caso de no setear Info.plist
            return "http://192.168.0.113:3000/api/"
            #endif
        }()
        // Aseguramos barra final
        if s.hasSuffix("/") { return URL(string: s)! }
        return URL(string: s + "/")!
    }()

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

        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        comps.path += cleanPath
        comps.queryItems = query.isEmpty ? nil : query

        guard let url = comps.url else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = method
        if let body = body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if authorized, let t = token {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
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

// MARK: - Convenience
extension APIClient {
    func sessions(activityId: Int) -> AnyPublisher<ListResponse<ActivitySession>, Error> {
        request("activities/\(activityId)/sessions")
    }
    func book(sessionId: Int) -> AnyPublisher<SimpleOK, Error> {
        request("sessions/\(sessionId)/book", method: "POST", authorized: true)
    }
    func cancelBooking(sessionId: Int) -> AnyPublisher<SimpleOK, Error> {
        request("sessions/\(sessionId)/book", method: "DELETE", authorized: true)
    }
}




