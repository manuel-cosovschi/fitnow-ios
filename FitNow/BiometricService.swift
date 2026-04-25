import Foundation
import LocalAuthentication
import SwiftUI

// MARK: - BiometricService

@Observable
final class BiometricService {
    enum LockState { case unlocked, locked, unavailable }

    private(set) var lockState: LockState = .unlocked
    private(set) var biometricType: LABiometryType = .none

    private static let enabledKey = "fn_biometric_enabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    var canUseBiometrics: Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    init() {
        refreshBiometricType()
    }

    // MARK: - Lifecycle hooks

    func handleForeground() {
        guard isEnabled, canUseBiometrics else { return }
        lockState = .locked
    }

    func handleBackground() {
        // Lock will be applied on next foreground
    }

    // MARK: - Unlock

    @MainActor
    func unlock() async -> Bool {
        guard canUseBiometrics else {
            lockState = .unavailable
            return false
        }
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Usar contraseña"
        do {
            let success = try await ctx.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Verificá tu identidad para acceder a FitNow"
            )
            if success { lockState = .unlocked }
            return success
        } catch {
            return false
        }
    }

    // MARK: - Enroll

    @MainActor
    func enrollBiometrics() async -> Bool {
        guard canUseBiometrics else { return false }
        let success = await unlock()
        if success { isEnabled = true }
        return success
    }

    func disable() {
        isEnabled = false
        lockState = .unlocked
    }

    // MARK: - Private

    private func refreshBiometricType() {
        let ctx = LAContext()
        var error: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = ctx.biometryType
        }
    }
}

// MARK: - BiometricLockView

struct BiometricLockView: View {
    let biometric: BiometricService
    let onFallback: () -> Void

    @State private var attempting = false
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.fnBg.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.fnBlue.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Image(systemName: biometricIcon)
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.fnBlue)
                    }

                    VStack(spacing: 8) {
                        Text("FitNow bloqueado")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.fnWhite)
                        Text("Usá \(biometricLabel) para continuar")
                            .font(.system(size: 14))
                            .foregroundColor(.fnSlate)
                    }
                }

                if failed {
                    Text("No se pudo verificar. Intentá de nuevo.")
                        .font(.system(size: 13))
                        .foregroundColor(.fnCrimson)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 12) {
                    Button {
                        Task { await attemptUnlock() }
                    } label: {
                        HStack(spacing: 10) {
                            if attempting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: biometricIcon)
                                    .font(.system(size: 17, weight: .medium))
                                Text("Desbloquear con \(biometricLabel)")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.fnBlue, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(attempting)

                    Button("Usar contraseña de cuenta") {
                        onFallback()
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.fnSlate)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .task { await attemptUnlock() }
    }

    private var biometricIcon: String {
        switch biometric.biometricType {
        case .faceID:    return "faceid"
        case .touchID:   return "touchid"
        case .opticID:   return "opticid"
        default:         return "lock.fill"
        }
    }

    private var biometricLabel: String {
        switch biometric.biometricType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        default:       return "biometría"
        }
    }

    @MainActor
    private func attemptUnlock() async {
        attempting = true
        failed = false
        let success = await biometric.unlock()
        attempting = false
        if !success { failed = true }
    }
}
