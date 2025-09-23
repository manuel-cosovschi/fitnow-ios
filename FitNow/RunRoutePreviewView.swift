import SwiftUI
import Combine
import MapKit
import CoreLocation

/// Fallback a Mar del Plata si no hay GPS todavía
private let MDP_FALLBACK = CLLocationCoordinate2D(latitude: -38.0055, longitude: -57.5426)

struct RunRoutePreviewView: View {
    let option: RunRouteOption

    @State private var mapRegion = MKCoordinateRegion(
        center: MDP_FALLBACK,
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var polyline: MKPolyline?
    @State private var rating: Int = 5
    @State private var message: String?

    // Combine bag local
    @State private var bag = Set<AnyCancellable>()

    var body: some View {
        VStack(spacing: 12) {
            MapViewRepresentable(polyline: polyline, region: $mapRegion)
                .frame(height: 260)
                .onAppear {
                    LocationService.shared.start()
                    buildPolyline()
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(option.label).font(.headline)
                Text(option.rationale).font(.subheadline).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // --- Navegar esta ruta (usa ubicación real si existe)
            NavigationLink {
                let origin = LocationService.shared.lastLocation?.coordinate ?? MDP_FALLBACK
                RunNavigatorView(option: option, origin: origin, userPrefs: .default)
            } label: {
                Label("Navegar esta ruta", systemImage: "location.north.line")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Divider().padding(.top, 4)

            HStack {
                Text("Calificar ruta")
                Spacer()
                Stepper(value: $rating, in: 1...5) { Text("\(rating) ★") }
                    .labelsHidden()
            }

            if let msg = message {
                Text(msg).foregroundColor(.secondary)
            }

            Button("Enviar feedback") { sendFeedback() }
                .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Vista previa")
    }

    private func buildPolyline() {
        let mkCoords = option.geojson.coords2D
        guard !mkCoords.isEmpty else { return }
        let pl = MKPolyline(coordinates: mkCoords, count: mkCoords.count)
        self.polyline = pl
        fit(to: pl)
    }

    private func fit(to poly: MKPolyline) {
        let rect = poly.boundingMapRect
        let centerPoint = MKMapPoint(x: rect.midX, y: rect.midY)
        let center = centerPoint.coordinate

        let topLeft     = MKMapPoint(x: rect.minX, y: rect.minY).coordinate
        let bottomRight = MKMapPoint(x: rect.maxX, y: rect.maxY).coordinate

        var latDelta = abs(topLeft.latitude - bottomRight.latitude)
        var lngDelta = abs(topLeft.longitude - bottomRight.longitude)
        latDelta *= 1.2; lngDelta *= 1.2

        let minDelta: CLLocationDegrees = 0.01
        latDelta = max(latDelta, minDelta)
        lngDelta = max(lngDelta, minDelta)

        mapRegion = MKCoordinateRegion(center: center,
                                       span: MKCoordinateSpan(latitudeDelta: latDelta,
                                                              longitudeDelta: lngDelta))
    }

    private func sendFeedback() {
        message = nil
        let body: [String: Any] = [
            "route_id": option.id,
            "rating": rating
        ]
        let data = try! JSONSerialization.data(withJSONObject: body)

        APIClient.shared.request("run/feedback", method: "POST", body: data, authorized: true)
            .sink { completion in
                if case .failure(let e) = completion { self.message = e.localizedDescription }
            } receiveValue: { (_: SimpleOK) in
                self.message = "¡Gracias por tu feedback!"
            }
            .store(in: &bag)
    }
}

// MARK: - Map wrapper
struct MapViewRepresentable: UIViewRepresentable {
    var polyline: MKPolyline?
    @Binding var region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsCompass = false
        map.showsScale = false
        map.isRotateEnabled = false
        map.setRegion(region, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        if map.region.center.latitude != region.center.latitude ||
            map.region.center.longitude != region.center.longitude ||
            map.region.span.latitudeDelta != region.span.latitudeDelta ||
            map.region.span.longitudeDelta != region.span.longitudeDelta {
            map.setRegion(region, animated: false)
        }

        map.removeOverlays(map.overlays)
        if let pl = polyline { map.addOverlay(pl) }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let pl = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: pl)
                r.lineWidth = 5
                r.strokeColor = .systemBlue
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}





