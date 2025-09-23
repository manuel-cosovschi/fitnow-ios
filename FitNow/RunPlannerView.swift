import SwiftUI
import Combine
import CoreLocation
import MapKit

/// Fallback (solo si todavía no hay fix del GPS)
private let MDP_FALLBACK = CLLocationCoordinate2D(latitude: -38.0055, longitude: -57.5426)

struct RunPlannerView: View {
    // Distancia objetivo (km)
    @State private var distanceKm: Double = 5
    @State private var generating = false
    @State private var error: String?
    @State private var options: [RunRouteOption] = []

    // Para requests
    @State private var bag = Set<AnyCancellable>()

    var body: some View {
        VStack(spacing: 16) {

            // Selector de distancia
            VStack(alignment: .leading) {
                HStack {
                    Text("Distancia objetivo")
                    Spacer()
                    Text("\(Int(distanceKm)) km").bold()
                }
                Slider(value: $distanceKm, in: 2...20, step: 1)
            }

            Button(generating ? "Generando..." : "Generar rutas") {
                generate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(generating)

            if let e = error {
                Text(e).foregroundColor(.red)
            }

            if !options.isEmpty {
                List(options) { opt in
                    NavigationLink {
                        RunRoutePreviewView(option: opt)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(opt.label).bold()
                            Text(opt.rationale)
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)
            } else if !generating {
                Text("Elegí una distancia y generá rutas. Se usará tu ubicación actual.")
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("Rutas de running")
        .onAppear { LocationService.shared.start() }
    }

    private func generate() {
        generating = true
        error = nil
        options = []

        // Usamos la última ubicación real disponible; si aún no hay, usamos el fallback
        let origin = LocationService.shared.lastLocation?.coordinate ?? MDP_FALLBACK

        let body: [String: Any] = [
            "origin_lat": origin.latitude,
            "origin_lng": origin.longitude,
            "distance_m": Int(distanceKm * 1000)
        ]
        let data = try! JSONSerialization.data(withJSONObject: body)

        APIClient.shared.request("run/routes", method: "POST", body: data, authorized: true)
            .sink { completion in
                self.generating = false
                if case .failure(let e) = completion { self.error = e.localizedDescription }
            } receiveValue: { (resp: RunRoutesResponse) in
                self.options = resp.items
            }
            .store(in: &bag)
    }
}





