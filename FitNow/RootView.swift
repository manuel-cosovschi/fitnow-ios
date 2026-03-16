import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated {
                HomeView()            // NO agregar .environmentObject acá
            } else {
                LoginView()
            }
        }
    }
}





