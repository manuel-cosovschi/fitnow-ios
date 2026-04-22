import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else if auth.isAuthenticated {
                switch auth.user?.role ?? "user" {
                case "provider_admin":
                    ProviderDashboardView(providerId: auth.user?.provider_id)
                case "admin":
                    NavigationStack { AdminView() }
                default:
                    MainTabView()
                }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.16), value: showSplash)
        .animation(.easeInOut(duration: 0.16), value: auth.isAuthenticated)
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation { showSplash = false }
            }
        }
    }
}
