import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth:      AuthViewModel
    @Environment(BiometricService.self) var biometric

    @State private var showSplash = true
    @AppStorage("fn_onboarding_done") private var onboardingDone = false

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
            if !onboardingDone {
                OnboardingView(onComplete: { onboardingDone = true })
            } else {
                MainTabView()
            }
        }
    }
}
