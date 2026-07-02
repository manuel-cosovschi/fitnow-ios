import Foundation
import Combine

final class FavoritesService: ObservableObject {
    static let shared = FavoritesService()

    @Published private(set) var favorites: [Activity] = []

    private let key = "favorite_activities_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([Activity].self, from: data) {
            favorites = saved
        }
    }

    // Agrega o saca de favoritos.
    func toggle(_ activity: Activity) {
        if let idx = favorites.firstIndex(where: { $0.id == activity.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(activity)
        }
        persist()
    }

    // Dice si una actividad está en favoritos.
    func isFavorite(_ id: Int) -> Bool {
        favorites.contains(where: { $0.id == id })
    }

    // Guarda los favoritos.
    private func persist() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
