import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated {
                switch auth.user?.role {
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
    }
}





