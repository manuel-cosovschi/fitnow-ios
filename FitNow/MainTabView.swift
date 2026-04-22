import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Inicio",
                          systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            NavigationStack { ActivitiesListView() }
                .tabItem { Label("Explorar", systemImage: "magnifyingglass") }
                .tag(1)

            NavigationStack { RunPlannerView() }
                .tabItem {
                    Label("Run",
                          systemImage: selectedTab == 2 ? "figure.run" : "figure.walk")
                }
                .tag(2)

            NavigationStack { MyEnrollmentsView() }
                .tabItem {
                    Label("Inscripciones",
                          systemImage: selectedTab == 3
                                        ? "list.bullet.rectangle.fill"
                                        : "list.bullet.rectangle")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("Perfil",
                          systemImage: selectedTab == 4 ? "person.circle.fill" : "person.circle")
                }
                .tag(4)
        }
        .tint(.fnBlue)
    }
}
