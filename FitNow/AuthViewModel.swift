import Foundation
import Combine
import AuthenticationServices

// MARK: - AuthViewModel

final class AuthViewModel: ObservableObject {
    // Form fields
    @Published var email        = ""
    @Published var password     = ""
    @Published var name         = ""
    @Published var providerName = ""
    @Published var selectedRole = "user"

    // Auth state
    @Published var isAuthenticated = false
    @Published var loading         = false
    @Published var error: String?
    @Published var user: User?

    // 2FA state
    @Published var pendingTwoFactor: String?  // tempToken when 2FA required
    @Published var twoFactorError: String?

    // Apple Sign In stored user ID (to verify credential state on relaunch)
    @Published var appleUserID: String?

    private static let userKey      = "saved_user"
    private static let appleUserKey = "fn_apple_user_id"
    private let tokenStore          = TokenStore.shared
    private let appleSignIn         = AppleSignInService()

    init() {
        appleUserID = UserDefaults.standard.string(forKey: Self.appleUserKey)
        restoreSession()
        observeSessionExpiry()
        Task { await verifyAppleCredentialState() }
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

    // MARK: - Email / password login

    func login() {
        guard !loading else { return }
        loading = true; error = nil
        Task { @MainActor in
            defer { loading = false }
            do {
                guard let body = try? JSONEncoder().encode(
                    ["email": email, "password": password]
                ) else { return }
                let resp: LoginFlexResponse = try await APIClient.shared.request(
                    "auth/login", method: "POST", body: body, authorized: false
                )
                handleLoginFlexResponse(resp)
            } catch {
                self.error = humanError(error)
            }
        }
    }

    // MARK: - Register

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
                    guard let body = try? JSONEncoder().encode(payload) else { return }
                    let resp: AuthResponse = try await APIClient.shared.request(
                        "auth/register-provider", method: "POST", body: body, authorized: false
                    )
                    applyAuth(resp, intendedRole: "provider_admin")
                } else {
                    let payload = UserRegisterPayload(name: name, email: email, password: password)
                    guard let body = try? JSONEncoder().encode(payload) else { return }
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

    // MARK: - Sign in with Apple

    func signInWithApple() {
        guard !loading else { return }
        loading = true; error = nil
        Task { @MainActor in
            defer { loading = false }
            do {
                let authorization = try await appleSignIn.signIn()
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData  = credential.identityToken,
                      let token      = String(data: tokenData, encoding: .utf8) else {
                    self.error = "No se pudo obtener las credenciales de Apple."
                    return
                }

                let fullName = [
                    credential.fullName?.givenName,
                    credential.fullName?.familyName
                ].compactMap { $0 }.joined(separator: " ")

                struct ApplePayload: Encodable {
                    let identityToken: String
                    let fullName: String?
                    enum CodingKeys: String, CodingKey {
                        case identityToken = "identity_token"
                        case fullName      = "full_name"
                    }
                }

                let payload = ApplePayload(
                    identityToken: token,
                    fullName: fullName.isEmpty ? nil : fullName
                )
                guard let body = try? JSONEncoder().encode(payload) else { return }

                let resp: AuthResponse = try await APIClient.shared.request(
                    "auth/apple", method: "POST", body: body, authorized: false
                )

                // Persist Apple user ID for credential state checks on relaunch
                UserDefaults.standard.set(credential.user, forKey: Self.appleUserKey)
                appleUserID = credential.user

                applyAuth(resp)
            } catch let error as ASAuthorizationError where error.code == .canceled {
                // User cancelled — not an error
            } catch {
                self.error = "No se pudo iniciar sesión con Apple. Intentá de nuevo."
            }
        }
    }

    // MARK: - Two-Factor Authentication

    func verifyTwoFactor(tempToken: String, code: String) {
        guard !loading else { return }
        loading = true; twoFactorError = nil
        Task { @MainActor in
            defer { loading = false }
            do {
                struct TwoFAPayload: Encodable {
                    let tempToken: String
                    let code: String
                    enum CodingKeys: String, CodingKey {
                        case tempToken = "temp_token"
                        case code
                    }
                }
                guard let body = try? JSONEncoder().encode(
                    TwoFAPayload(tempToken: tempToken, code: code)
                ) else { return }
                let resp: AuthResponse = try await APIClient.shared.request(
                    "auth/2fa/verify", method: "POST", body: body, authorized: false
                )
                pendingTwoFactor = nil
                applyAuth(resp)
            } catch {
                twoFactorError = "Código incorrecto. Verificá tu app de autenticación."
            }
        }
    }

    func cancelTwoFactor() {
        pendingTwoFactor  = nil
        twoFactorError    = nil
    }

    // MARK: - Logout

    func logout() {
        tokenStore.clear()
        UserDefaults.standard.removeObject(forKey: Self.userKey)
        user           = nil
        isAuthenticated = false
        pendingTwoFactor = nil
    }

    // MARK: - Private helpers

    private func handleLoginFlexResponse(_ resp: LoginFlexResponse) {
        if let requiresTwoFactor = resp.requiresTwoFactor, requiresTwoFactor,
           let tempToken = resp.tempToken {
            pendingTwoFactor = tempToken
            return
        }
        guard let token = resp.token, let apiUser = resp.user else {
            error = "Respuesta inesperada del servidor."
            return
        }
        tokenStore.store(access: token, refresh: resp.refreshToken)
        let resolvedRole = apiUser.role.flatMap { $0.isEmpty ? nil : $0 } ?? "user"
        let u = User(id: apiUser.id, name: apiUser.name, email: apiUser.email,
                     role: resolvedRole, provider_id: apiUser.provider_id)
        save(user: u)
        user = u
        isAuthenticated = true
    }

    private func applyAuth(_ resp: AuthResponse, intendedRole: String? = nil) {
        tokenStore.store(access: resp.token, refresh: resp.refreshToken)
        let resolvedRole = resp.user.role.flatMap { $0.isEmpty ? nil : $0 }
            ?? intendedRole ?? "user"
        let u = User(id: resp.user.id, name: resp.user.name,
                     email: resp.user.email, role: resolvedRole,
                     provider_id: resp.user.provider_id)
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
        user            = nil
        isAuthenticated = false
        pendingTwoFactor = nil
    }

    private func humanError(_ error: Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .unauthorized:
                return "Email o contraseña incorrectos."
            case .http(let code, _):
                switch code {
                case 401: return "Email o contraseña incorrectos."
                case 404: return "No existe una cuenta con ese email."
                case 409: return "Ya existe una cuenta con ese email."
                default:  return "Error del servidor (\(code)). Intentá de nuevo."
                }
            default: break
            }
        }
        return "Sin conexión. Verificá tu red."
    }

    // MARK: - Apple credential state verification on relaunch

    private func verifyAppleCredentialState() async {
        guard let uid = appleUserID else { return }
        let state = await AppleSignInService.checkCredentialState(userID: uid)
        if state == .revoked || state == .notFound {
            await MainActor.run { forceLogout() }
        }
    }
}

// MARK: - Codable payloads

private struct UserRegisterPayload: Encodable {
    let name, email, password: String
}

private struct ProviderRegisterPayload: Encodable {
    let name, email, password, provider_name: String
}
