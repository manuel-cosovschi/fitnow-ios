import Foundation
import SwiftUI

// MARK: - Deep link routes

enum DeepLink: Equatable {
    case verifyEmail(token: String)
    case magicLink(token: String)
    case resetPassword(token: String)
    case activity(id: Int)
    case enrollment(id: Int)
    case profile
    case run

    // MARK: - Parser

    static func from(url: URL) -> DeepLink? {
        // Universal links: https://fitnow.app/...
        // URL scheme:      fitnow://...
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = components?.path ?? url.path
        let host = components?.host ?? url.host ?? ""

        // Normalize: strip leading slash
        let route = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let queryItems = components?.queryItems ?? []

        func q(_ name: String) -> String? {
            queryItems.first { $0.name == name }?.value
        }

        switch host.isEmpty ? route : "\(host)/\(route)" {
        // Universal: fitnow.app/verify-email?token=xxx
        // Scheme:    fitnow://verify-email?token=xxx
        case "verify-email", "fitnow.app/verify-email":
            if let token = q("token") { return .verifyEmail(token: token) }
        case "magic-link", "fitnow.app/magic-link":
            if let token = q("token") { return .magicLink(token: token) }
        case "reset-password", "fitnow.app/reset-password":
            if let token = q("token") { return .resetPassword(token: token) }
        case let r where r.hasPrefix("activity/"):
            if let idStr = r.split(separator: "/").last,
               let id = Int(idStr) { return .activity(id: id) }
        case let r where r.hasPrefix("enrollment/"):
            if let idStr = r.split(separator: "/").last,
               let id = Int(idStr) { return .enrollment(id: id) }
        case "profile", "fitnow.app/profile":
            return .profile
        case "run", "fitnow.app/run":
            return .run
        default: break
        }
        return nil
    }
}

// MARK: - Handler (Observable)

@Observable
final class DeepLinkHandler {
    static let shared = DeepLinkHandler()
    private init() {}

    var pendingLink: DeepLink?
    var emailVerificationResult: VerificationResult?

    enum VerificationResult {
        case success(message: String)
        case failure(message: String)
    }

    // Called from FitNowApp.onOpenURL / onContinueUserActivity
    func handle(url: URL) {
        guard let link = DeepLink.from(url: url) else { return }
        pendingLink = link
    }

    // Consume the pending link (view reads and clears it)
    func consume() -> DeepLink? {
        defer { pendingLink = nil }
        return pendingLink
    }

    // MARK: - Email verification

    @MainActor
    func verifyEmail(token: String) async {
        struct VerifyPayload: Encodable { let token: String }
        struct VerifyResponse: Decodable { let message: String? }

        guard let body = try? JSONEncoder().encode(VerifyPayload(token: token)) else { return }
        do {
            let resp: VerifyResponse = try await APIClient.shared.request(
                "auth/verify-email", method: "POST", body: body, authorized: false
            )
            emailVerificationResult = .success(
                message: resp.message ?? "Email verificado correctamente."
            )
        } catch {
            emailVerificationResult = .failure(
                message: "No se pudo verificar el email. El enlace puede haber expirado."
            )
        }
    }

    // MARK: - Magic link login

    @MainActor
    func handleMagicLink(token: String, auth: AuthViewModel) async {
        struct MagicPayload: Encodable { let token: String }
        guard let body = try? JSONEncoder().encode(MagicPayload(token: token)) else { return }
        do {
            let resp: AuthResponse = try await APIClient.shared.request(
                "auth/magic-link", method: "POST", body: body, authorized: false
            )
            TokenStore.shared.store(access: resp.token, refresh: resp.refreshToken)
            let role = resp.user.role ?? "user"
            let u = User(id: resp.user.id, name: resp.user.name,
                         email: resp.user.email, role: role,
                         provider_id: resp.user.provider_id)
            if let d = try? JSONEncoder().encode(u) {
                UserDefaults.standard.set(d, forKey: "saved_user")
            }
            auth.user = u
            auth.isAuthenticated = true
        } catch {
            // Magic link expired or invalid — silently fail
        }
    }
}

// MARK: - Email Verification Banner

struct EmailVerificationBanner: View {
    let result: DeepLinkHandler.VerificationResult
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(isSuccess ? .fnGreen : .fnCrimson)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.fnWhite)
            Spacer()
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.fnSlate)
            }
        }
        .padding(16)
        .background(Color.fnElevated, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSuccess ? Color.fnGreen.opacity(0.4) : Color.fnCrimson.opacity(0.4),
                        lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var isSuccess: Bool {
        if case .success = result { return true }
        return false
    }

    private var message: String {
        switch result {
        case .success(let m): return m
        case .failure(let m): return m
        }
    }
}
