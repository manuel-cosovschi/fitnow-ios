import SwiftUI

struct FavoritesView: View {
    @ObservedObject private var fav = FavoritesService.shared
    @State private var appeared = false

    var body: some View {
        Group {
            if fav.favorites.isEmpty {
                emptyState
            } else {
                favoritesList
            }
        }
        .navigationTitle("Favoritos")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
    }

    // MARK: - List

    private var favoritesList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(Array(fav.favorites.enumerated()), id: \.element.id) { index, activity in
                    NavigationLink(destination: ActivityDetailLoader(activityId: activity.id, title: activity.title)) {
                        ActivityListCard(activity: activity)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation { fav.toggle(activity) }
                        } label: {
                            Label("Quitar de favoritos", systemImage: "heart.slash")
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.8)
                            .delay(Double(index) * 0.05),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(FNGradient.primary)
                    .frame(width: 80, height: 80)
                    .fnShadowBrand()
                Image(systemName: "heart.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text("Sin favoritos aún")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text("Guardá actividades que te interesen\ntocando el corazón en cada una.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
            Spacer()
        }
    }
}
