import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth:      AuthViewModel
    @Environment(BiometricService.self) var biometric

    @State private var showSplash = true
    // Fuerza a la vista a re-evaluarse cuando se completa el onboarding.
    @State private var onboardingTick = 0

    // El onboarding se marca POR USUARIO (no por dispositivo): si en el mismo
    // teléfono se crea una cuenta nueva, esa cuenta ve su propio onboarding.
    private var onboardingKey: String {
        "fn_onboarding_done_u\(auth.user?.id ?? 0)"
    }

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else if auth.isAuthenticated && biometric.lockState == .locked {
                BiometricLockView(biometric: biometric) {
                    // Fallback: force logout so user re-enters password
                    auth.logout()
                }
            } else if auth.isAuthenticated {
                authenticatedRoot
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.16), value: showSplash)
        .animation(.easeInOut(duration: 0.16), value: auth.isAuthenticated)
        .animation(.easeInOut(duration: 0.16), value: biometric.lockState == .locked)
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation { showSplash = false }
            }
        }
    }

    @ViewBuilder
    private var authenticatedRoot: some View {
        switch auth.user?.role ?? "user" {
        case "provider_admin":
            ProviderDashboardView(providerId: auth.user?.provider_id)
        case "admin":
            NavigationStack { AdminView() }
        default:
            if UserDefaults.standard.bool(forKey: onboardingKey) {
                MainTabView()
            } else {
                OnboardingView(onComplete: {
                    UserDefaults.standard.set(true, forKey: onboardingKey)
                    onboardingTick += 1
                })
                .id(onboardingTick)
            }
        }
    }
}
