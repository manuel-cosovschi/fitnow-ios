import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var name: String = ""
    @Published var selectedRole: String = "user"   // "user" | "provider"
    @Published var isAuthenticated: Bool = false
    @Published var loading = false
    @Published var error: String?
    @Published var user: User? = nil

    private static let userKey    = "saved_user"
    private static let roleMapKey = "email_role_map"   // email → role local cache
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

    // MARK: - Role cache (workaround for backends that don't echo the role)

    private func storeRole(_ role: String, forEmail email: String) {
        var map = (UserDefaults.standard.dictionary(forKey: Self.roleMapKey) as? [String: String]) ?? [:]
        map[email] = role
        UserDefaults.standard.set(map, forKey: Self.roleMapKey)
    }

    private func cachedRole(forEmail email: String) -> String? {
        let map = (UserDefaults.standard.dictionary(forKey: Self.roleMapKey) as? [String: String]) ?? [:]
        return map[email]
    }

    /// Returns the best-known role: prefers backend value if meaningful, falls back to local cache.
    private func resolvedRole(from backendUser: User, fallbackRole: String? = nil) -> String {
        if let r = backendUser.role, r != "user", !r.isEmpty { return r }
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
        let u = User(id: resp.user.id, name: resp.user.name, email: resp.user.email, role: role)
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
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: AuthResponse) in
                self?.applyAuth(resp)
            }.store(in: &bag)
    }

    func register() {
        error = nil; loading = true
        var payload: [String: String] = ["name": name, "email": email, "password": password]
        if selectedRole == "provider" { payload["role"] = "provider" }
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        APIClient.shared.request("auth/register", method: "POST", body: data, authorized: false)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: AuthResponse) in
                // Pass the role the user explicitly chose during registration
                self?.applyAuth(resp, intendedRole: self?.selectedRole)
            }.store(in: &bag)
    }

    func logout() {
        APIClient.shared.clearToken()
        UserDefaults.standard.removeObject(forKey: Self.userKey)
        user = nil
        isAuthenticated = false
    }
}
