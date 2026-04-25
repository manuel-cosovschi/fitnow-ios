import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var selectedTab = 0
    @State private var messagesVM  = MessagesViewModel()

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

            NavigationStack { MessagesView() }
                .tabItem {
                    Label("Mensajes",
                          systemImage: selectedTab == 4 ? "bell.fill" : "bell")
                }
                .badge(messagesVM.unreadCount > 0 ? messagesVM.unreadCount : 0)
                .tag(4)

            ProfileView()
                .tabItem {
                    Label("Perfil",
                          systemImage: selectedTab == 5 ? "person.circle.fill" : "person.circle")
                }
                .tag(5)
        }
        .tint(.fnBlue)
        .task { await messagesVM.load() }
    }
}
