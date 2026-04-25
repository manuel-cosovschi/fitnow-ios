import Foundation
import AuthenticationServices
import SwiftUI

// MARK: - Service

final class AppleSignInService: NSObject, ASAuthorizationControllerDelegate,
                                ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    // MARK: - Public API

    func signIn() async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Credential state check

extension AppleSignInService {
    static func checkCredentialState(userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }
}

// MARK: - Sign in with Apple Button (SwiftUI wrapper)

struct SignInWithAppleButton: UIViewRepresentable {
    var onRequest: (ASAuthorizationAppleIDRequest) -> Void = { req in
        req.requestedScopes = [.fullName, .email]
    }
    var onCompletion: (Result<ASAuthorization, Error>) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let btn = ASAuthorizationAppleIDButton(type: .continue, style: .white)
        btn.addTarget(context.coordinator,
                      action: #selector(Coordinator.handleTap),
                      for: .touchUpInside)
        return btn
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, ASAuthorizationControllerDelegate,
                             ASAuthorizationControllerPresentationContextProviding {
        let parent: SignInWithAppleButton

        init(parent: SignInWithAppleButton) { self.parent = parent }

        @objc func handleTap() {
            let provider = ASAuthorizationAppleIDProvider()
            let request  = provider.createRequest()
            parent.onRequest(request)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithAuthorization auth: ASAuthorization) {
            parent.onCompletion(.success(auth))
        }

        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithError error: Error) {
            parent.onCompletion(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
