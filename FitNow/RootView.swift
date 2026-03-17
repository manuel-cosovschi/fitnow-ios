import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated {
                switch auth.user?.role {
                case "provider":
                    ProviderDashboardView()
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





