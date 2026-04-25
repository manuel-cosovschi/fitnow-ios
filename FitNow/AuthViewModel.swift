import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    @Published var email        = ""
    @Published var password     = ""
    @Published var name         = ""
    @Published var providerName = ""
    @Published var selectedRole = "user"      // "user" | "provider_admin"
    @Published var isAuthenticated = false
    @Published var loading = false
    @Published var error: String?
    @Published var user: User?

    private static let userKey = "saved_user"
    private let tokenStore     = TokenStore.shared

    init() {
        restoreSession()
        observeSessionExpiry()
    }

    // MARK: - Session restore

    private func restoreSession() {
        guard tokenStore.isAuthenticated else { return }
        if let data = UserDefaults.standard.data(forKey: Self.userKey),
           let saved = try? JSONDecoder().decode(User.self, from: data) {
            user = saved
            isAuthenticated = true
        }
    }

    private func observeSessionExpiry() {
        NotificationCenter.default.addObserver(
            forName: .sessionExpired, object: nil, queue: .main
        ) { [weak self] _ in
            self?.forceLogout()
        }
    }

    // MARK: - Auth actions (async/await)

    func login() {
        guard !loading else { return }
        loading = true; error = nil
        Task { @MainActor in
            defer { loading = false }
            do {
                guard let body = try? JSONEncoder().encode(
                    ["email": email, "password": password]
                ) else { throw APIError.badURL }
                let resp: AuthResponse = try await APIClient.shared.request(
                    "auth/login", method: "POST", body: body, authorized: false
                )
                applyAuth(resp)
            } catch {
                self.error = humanError(error)
            }
        }
    }

    func register() {
        guard !loading else { return }
        loading = true; error = nil
        Task { @MainActor in
            defer { loading = false }
            do {
                if selectedRole == "provider_admin" {
                    let pName = providerName.trimmingCharacters(in: .whitespaces)
                    let payload = ProviderRegisterPayload(
                        name: name, email: email, password: password,
                        provider_name: pName.isEmpty ? name : pName
                    )
                    guard let body = try? JSONEncoder().encode(payload) else { throw APIError.badURL }
                    let resp: AuthResponse = try await APIClient.shared.request(
                        "auth/register-provider", method: "POST", body: body, authorized: false
                    )
                    applyAuth(resp, intendedRole: "provider_admin")
                } else {
                    let payload = UserRegisterPayload(name: name, email: email, password: password)
                    guard let body = try? JSONEncoder().encode(payload) else { throw APIError.badURL }
                    let resp: AuthResponse = try await APIClient.shared.request(
                        "auth/register", method: "POST", body: body, authorized: false
                    )
                    applyAuth(resp, intendedRole: "user")
                }
            } catch {
                self.error = humanError(error)
            }
        }
    }

    func logout() {
        tokenStore.clear()
        UserDefaults.standard.removeObject(forKey: Self.userKey)
        user = nil
        isAuthenticated = false
    }

    // MARK: - Private

    private func applyAuth(_ resp: AuthResponse, intendedRole: String? = nil) {
        tokenStore.store(access: resp.token, refresh: resp.refreshToken)
        let resolvedRole = resp.user.role.flatMap { $0.isEmpty ? nil : $0 }
            ?? intendedRole
            ?? "user"
        let u = User(
            id: resp.user.id, name: resp.user.name,
            email: resp.user.email, role: resolvedRole,
            provider_id: resp.user.provider_id
        )
        save(user: u)
        user = u
        isAuthenticated = true
    }

    private func save(user: User) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: Self.userKey)
        }
    }

    private func forceLogout() {
        user = nil
        isAuthenticated = false
    }

    private func humanError(_ error: Error) -> String {
        if let api = error as? APIError, case .http(let code, _) = api {
            switch code {
            case 401: return "Email o contraseña incorrectos."
            case 404: return "No existe una cuenta con ese email."
            case 409: return "Ya existe una cuenta con ese email."
            default:  return "Error del servidor (\(code)). Intentá de nuevo."
            }
        }
        return "Sin conexión. Verificá tu red."
    }
}

// MARK: - Codable payloads

private struct UserRegisterPayload: Encodable {
    let name, email, password: String
}

private struct ProviderRegisterPayload: Encodable {
    let name, email, password, provider_name: String
}
