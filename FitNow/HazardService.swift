import Foundation
import CoreLocation
import Combine

struct HazardArea: Codable, Identifiable {
    let id: Int
    let lat: Double
    let lng: Double
    let type: String
    let note: String?
    let severity: Int?
    let votes: Int?
    let status: String?
    let distance_m: Double?

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

final class HazardService {
    static let shared = HazardService()

    @Published private(set) var hazards: [HazardArea] = []
    private var lastFetchCenter: CLLocationCoordinate2D?
    private var lastFetchDate: Date?
    private var bag = Set<AnyCancellable>()

    private init() {}

    // Pide hazards al backend si nos movimos ~150m o pasaron > 45s
    func refreshIfNeeded(around c: CLLocationCoordinate2D) {
        let needByDistance: Bool = {
            guard let prev = lastFetchCenter else { return true }
            let d = CLLocation(latitude: c.latitude, longitude: c.longitude)
                .distance(from: CLLocation(latitude: prev.latitude, longitude: prev.longitude))
            return d > 150
        }()

        let needByTime: Bool = {
            guard let t = lastFetchDate else { return true }
            return Date().timeIntervalSince(t) > 45
        }()

        guard needByDistance || needByTime else { return }
        fetch(around: c)
    }

    private func fetch(around c: CLLocationCoordinate2D) {
        lastFetchCenter = c
        lastFetchDate = Date()

        let query = [
            URLQueryItem(name: "lat", value: "\(c.latitude)"),
            URLQueryItem(name: "lng", value: "\(c.longitude)"),
            URLQueryItem(name: "radius_m", value: "800")
        ]

        APIClient.shared.request("hazards/near", authorized: true, query: query)
            .sink { completion in
                if case .failure(let e) = completion {
                    print("Hazards fetch error:", e.localizedDescription)
                }
            } receiveValue: { (resp: [HazardArea]) in
                self.hazards = resp
            }
            .store(in: &bag)
    }

    /// Devuelve el hazard más cercano dentro de `within` metros, si existe
    func nearestHazard(to c: CLLocationCoordinate2D, within: CLLocationDistance) -> HazardArea? {
        var best: (idx: Int, dist: CLLocationDistance)?
        for (i, h) in hazards.enumerated() {
            let d = CLLocation(latitude: c.latitude, longitude: c.longitude)
                .distance(from: CLLocation(latitude: h.lat, longitude: h.lng))
            if d <= within {
                if best == nil || d < best!.dist { best = (i, d) }
            }
        }
        return best.map { hazards[$0.idx] }
    }

    /// Solo la distancia al hazard más cercano (si está dentro de `within`)
    func nearestHazardDistance(from c: CLLocationCoordinate2D, within: CLLocationDistance) -> CLLocationDistance? {
        var best: CLLocationDistance?
        for h in hazards {
            let d = CLLocation(latitude: c.latitude, longitude: c.longitude)
                .distance(from: CLLocation(latitude: h.lat, longitude: h.lng))
            if d <= within {
                if best == nil || d < best! { best = d }
            }
        }
        return best
    }
}
