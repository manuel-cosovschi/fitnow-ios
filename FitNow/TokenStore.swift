import Foundation

/// Centralizes access and refresh token persistence in Keychain.
/// Single source of truth for authentication tokens across the app.
final class TokenStore {
    static let shared = TokenStore()
    private init() {}

    private let accessKey  = "fn_access_token"
    private let refreshKey = "fn_refresh_token"

    var accessToken: String? {
        get { KeychainService.read(key: accessKey) }
        set {
            if let v = newValue { KeychainService.save(value: v, key: accessKey) }
            else { KeychainService.remove(key: accessKey) }
        }
    }

    var refreshToken: String? {
        get { KeychainService.read(key: refreshKey) }
        set {
            if let v = newValue { KeychainService.save(value: v, key: refreshKey) }
            else { KeychainService.remove(key: refreshKey) }
        }
    }

    var isAuthenticated: Bool { accessToken != nil }

    func store(access: String, refresh: String?) {
        accessToken = access
        if let r = refresh { refreshToken = r }
    }

    func clear() {
        accessToken  = nil
        refreshToken = nil
    }
}
