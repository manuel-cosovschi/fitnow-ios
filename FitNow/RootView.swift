import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated {
                switch auth.user?.role {
                case "provider":
                    ProviderDashboardView()
                default:
                    MainTabView()
                }
            } else {
                LoginView()
            }
        }
    }
}





