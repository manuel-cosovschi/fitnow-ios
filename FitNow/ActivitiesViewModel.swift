import Foundation
import Combine

final class ActivitiesViewModel: ObservableObject {
    @Published var items: [Activity] = []
    @Published var loading = false
    @Published var error: String?
    @Published var query: String = ""

    // Filtros
    @Published var selectedKind: String = ""         // "", "trainer", "gym", "club", "club_sport"
    @Published var selectedDifficulty: String = ""   // "", "baja", "media", "alta"
    @Published var selectedModality: String = ""     // "", "outdoor", "gimnasio", "clase"
    @Published var minPrice: Int?
    @Published var maxPrice: Int?
    @Published var selectedSort: String = "popular"  // "popular", "price_asc", "price_desc", "rating", "distance"

    let difficultyOptions = ["", "baja", "media", "alta"]
    let modalityOptions = ["", "outdoor", "gimnasio", "clase"]
    let sortOptions: [(label: String, value: String)] = [
        ("Popular",   "popular"),
        ("Precio ↑",  "price_asc"),
        ("Precio ↓",  "price_desc"),
        ("Rating",    "rating"),
        ("Cercanía",  "distance"),
    ]

    private var bag = Set<AnyCancellable>()

    func clearFilters() {
        selectedKind = ""
        selectedDifficulty = ""
        selectedModality = ""
        minPrice = nil
        maxPrice = nil
        selectedSort = "popular"
    }

    func fetch() {
        loading = true
        error = nil

        var qItems: [URLQueryItem] = []
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            qItems.append(URLQueryItem(name: "q", value: query))
        }
        if !selectedKind.isEmpty {
            qItems.append(URLQueryItem(name: "kind", value: selectedKind))
        }
        if !selectedDifficulty.isEmpty {
            qItems.append(URLQueryItem(name: "difficulty", value: selectedDifficulty))
        }
        if !selectedModality.isEmpty {
            qItems.append(URLQueryItem(name: "modality", value: selectedModality))
        }
        if let minPrice { qItems.append(URLQueryItem(name: "min_price", value: String(minPrice))) }
        if let maxPrice { qItems.append(URLQueryItem(name: "max_price", value: String(maxPrice))) }
        if !selectedSort.isEmpty { qItems.append(URLQueryItem(name: "sort", value: selectedSort)) }

        APIClient.shared.requestPublisher("activities", authorized: false, query: qItems)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: Paged<Activity>) in
                self?.items = resp.items
            }
            .store(in: &bag)
    }
}




