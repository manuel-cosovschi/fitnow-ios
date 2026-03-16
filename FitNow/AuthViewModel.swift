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

    private var bag = Set<AnyCancellable>()

    func login() {
        error = nil; loading = true
        let payload = ["email": email, "password": password]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        APIClient.shared.request("auth/login", method: "POST", body: data, authorized: false)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: AuthResponse) in
                APIClient.shared.setToken(resp.token)
                self?.user = resp.user
                self?.isAuthenticated = true
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
                APIClient.shared.setToken(resp.token)
                self?.user = resp.user
                self?.isAuthenticated = true
            }.store(in: &bag)
    }

    func logout() {
        APIClient.shared.clearToken()
        user = nil
        isAuthenticated = false
    }
}
