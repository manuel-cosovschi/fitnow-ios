import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Inicio
            HomeView()
                .tabItem {
                    Label("Inicio", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            // Explorar
            NavigationStack {
                ActivitiesListView()
            }
            .tabItem {
                Label("Explorar", systemImage: "magnifyingglass")
            }
            .tag(1)

            // Mis clases
            NavigationStack {
                MyEnrollmentsView()
            }
            .tabItem {
                Label("Mis clases", systemImage: selectedTab == 2 ? "calendar.badge.checkmark" : "calendar")
            }
            .tag(2)

            // Correr
            NavigationStack {
                RunHubView()
            }
            .tabItem {
                Label("Correr", systemImage: "figure.run")
            }
            .tag(3)

            // Perfil
            ProfileView()
                .tabItem {
                    Label("Perfil", systemImage: selectedTab == 4 ? "person.circle.fill" : "person.circle")
                }
                .tag(4)
        }
        .tint(.fnPrimary)
    }
}
