import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var name: String = ""
    @Published var providerName: String = ""          // used during provider registration
    @Published var selectedRole: String = "user"      // "user" | "provider_admin"
    @Published var isAuthenticated: Bool = false
    @Published var loading = false
    @Published var error: String?
    @Published var user: User? = nil

    private static let userKey    = "saved_user"
    private static let roleMapKey = "email_role_map"
    private var bag = Set<AnyCancellable>()

    init() {
        if APIClient.shared.token != nil {
            isAuthenticated = true
            if let data = UserDefaults.standard.data(forKey: Self.userKey),
               let saved = try? JSONDecoder().decode(User.self, from: data) {
                user = saved
            }
        }
    }

    // MARK: - Role cache

    private func storeRole(_ role: String, forEmail email: String) {
        var map = (UserDefaults.standard.dictionary(forKey: Self.roleMapKey) as? [String: String]) ?? [:]
        map[email] = role
        UserDefaults.standard.set(map, forKey: Self.roleMapKey)
    }

    private func cachedRole(forEmail email: String) -> String? {
        let map = (UserDefaults.standard.dictionary(forKey: Self.roleMapKey) as? [String: String]) ?? [:]
        return map[email]
    }

    private func resolvedRole(from backendUser: User, fallbackRole: String? = nil) -> String {
        // Prefer any non-"user" role returned by the backend
        if let r = backendUser.role, r != "user", !r.isEmpty { return r }
        // Fall back to local cache (handles backends that always echo "user")
        if let cached = cachedRole(forEmail: backendUser.email) { return cached }
        return fallbackRole ?? backendUser.role ?? "user"
    }

    private func saveUser(_ u: User) {
        if let data = try? JSONEncoder().encode(u) {
            UserDefaults.standard.set(data, forKey: Self.userKey)
        }
    }

    private func applyAuth(_ resp: AuthResponse, intendedRole: String? = nil) {
        APIClient.shared.setToken(resp.token)
        let role = resolvedRole(from: resp.user, fallbackRole: intendedRole)
        let u = User(id: resp.user.id, name: resp.user.name, email: resp.user.email,
                     role: role, provider_id: resp.user.provider_id)
        storeRole(role, forEmail: u.email)
        user = u
        saveUser(u)
        isAuthenticated = true
    }

    // MARK: - Auth actions

    func login() {
        error = nil; loading = true
        let payload = ["email": email, "password": password]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        APIClient.shared.request("auth/login", method: "POST", body: data, authorized: false)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion {
                    if case APIError.http(let code, _) = e {
                        switch code {
                        case 401: self?.error = "Email o contraseña incorrectos."
                        case 404: self?.error = "No existe una cuenta con ese email."
                        default:  self?.error = "No se pudo iniciar sesión. Intentá de nuevo."
                        }
                    } else {
                        self?.error = "Sin conexión. Verificá tu red."
                    }
                }
            } receiveValue: { [weak self] (resp: AuthResponse) in
                self?.applyAuth(resp)
            }.store(in: &bag)
    }

    func register() {
        error = nil; loading = true

        if selectedRole == "provider_admin" {
            // Use the dedicated register-provider endpoint
            let pName = providerName.trimmingCharacters(in: .whitespaces)
            let payload: [String: String] = [
                "name": name,
                "email": email,
                "password": password,
                "provider_name": pName.isEmpty ? name : pName
            ]
            let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
            APIClient.shared.request("auth/register-provider", method: "POST", body: data, authorized: false)
                .sink { [weak self] completion in
                    self?.loading = false
                    if case .failure(let e) = completion {
                    if case APIError.http(let code, _) = e {
                        self?.error = code == 409 ? "Ya existe una cuenta con ese email." : "No se pudo crear la cuenta. Intentá de nuevo."
                    } else { self?.error = "Sin conexión. Verificá tu red." }
                }
                } receiveValue: { [weak self] (resp: AuthResponse) in
                    self?.applyAuth(resp, intendedRole: "provider_admin")
                }.store(in: &bag)
        } else {
            let payload: [String: String] = ["name": name, "email": email, "password": password]
            let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
            APIClient.shared.request("auth/register", method: "POST", body: data, authorized: false)
                .sink { [weak self] completion in
                    self?.loading = false
                    if case .failure(let e) = completion {
                    if case APIError.http(let code, _) = e {
                        self?.error = code == 409 ? "Ya existe una cuenta con ese email." : "No se pudo crear la cuenta. Intentá de nuevo."
                    } else { self?.error = "Sin conexión. Verificá tu red." }
                }
                } receiveValue: { [weak self] (resp: AuthResponse) in
                    self?.applyAuth(resp, intendedRole: "user")
                }.store(in: &bag)
        }
    }

    func logout() {
        APIClient.shared.clearToken()
        UserDefaults.standard.removeObject(forKey: Self.userKey)
        user = nil
        isAuthenticated = false
    }
}
