import SwiftUI
import Combine
import MapKit
import CoreLocation

private let MDP_FALLBACK = CLLocationCoordinate2D(latitude: -38.0055, longitude: -57.5426)

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RunRoutePreviewView
// ─────────────────────────────────────────────────────────────────────────────

struct RunRoutePreviewView: View {
    let option: RunRouteOption

    @State private var mapRegion = MKCoordinateRegion(
        center: MDP_FALLBACK,
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var polyline: MKPolyline?
    @State private var rating: Int = 5
    @State private var feedbackSent = false
    @State private var message: String?
    @State private var bag = Set<AnyCancellable>()
    @State private var appeared = false
    @State private var showNavigator = false
    @State private var startOrigin = MDP_FALLBACK

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Map section
                mapSection

                // Info + actions
                infoSection
                    .padding(20)
                    .padding(.bottom, 20)
            }
        }
        .background(Color.fnBg)
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Vista previa")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showNavigator) {
            RunNavigatorView(option: option, origin: startOrigin, userPrefs: .default)
        }
        .onAppear {
            LocationService.shared.start()
            buildPolyline()
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
    }

    // MARK: - Map Section

    private var mapSection: some View {
        ZStack(alignment: .bottom) {
            MapViewRepresentable(polyline: polyline, region: $mapRegion)
                .frame(height: 300)
                .ignoresSafeArea(edges: .top)

            // Gradient fade at bottom
            LinearGradient(
                colors: [.clear, Color.fnBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)

            // Distance badge overlay
            HStack {
                Spacer()
                distanceBadge
                    .padding(.trailing, 16)
                    .padding(.bottom, 24)
            }
        }
    }

    private var distanceBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 12, weight: .bold))
            Text(distanceText)
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(FNGradient.run)
                .shadow(color: Color.fnCyan.opacity(0.4), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 20) {
            // Title + rationale
            VStack(alignment: .leading, spacing: 10) {
                Text(option.label)
                    .font(.custom("DM Serif Display", size: 24))
                    .foregroundColor(.white)
                Text(option.rationale)
                    .font(.system(size: 15))
                    .foregroundColor(.fnSlate)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.spring(response: 0.5).delay(0.1), value: appeared)

            // Route stats
            routeStatsRow
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.15), value: appeared)

            // Navigate CTA
            FitNowButton(
                title: "Iniciar ruta",
                icon: "location.north.line.fill",
                gradient: FNGradient.run
            ) {
                startOrigin = LocationService.shared.lastLocation?.coordinate ?? MDP_FALLBACK
                showNavigator = true
            }
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5).delay(0.2), value: appeared)

            // Feedback card
            feedbackCard
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.25), value: appeared)
        }
    }

    // MARK: - Route Stats

    private var routeStatsRow: some View {
        HStack(spacing: 0) {
            routeStat(value: distanceText, label: "Distancia", icon: "arrow.triangle.swap", color: .fnCyan)
            Divider().frame(height: 36).padding(.horizontal, 8)
            routeStat(value: estimatedTime, label: "Estimado", icon: "clock.fill", color: .fnPrimary)
            Divider().frame(height: 36).padding(.horizontal, 8)
            routeStat(value: estimatedCalories, label: "Calorías", icon: "flame.fill", color: .fnYellow)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.fnSurface)
        )
    }

    private func routeStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.custom("DM Serif Display", size: 16))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.fnSlate)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Feedback Card

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Calificar ruta", systemImage: "star.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if let msg = message {
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.fnGreen)
                }
            }

            // Star rating
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.3)) { rating = star }
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundColor(star <= rating ? .fnYellow : Color.white.opacity(0.1))
                            .scaleEffect(star <= rating ? 1.05 : 0.95)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                Spacer()
                if !feedbackSent {
                    Button("Enviar") { sendFeedback() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.fnPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.fnPrimary.opacity(0.12)))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.fnGreen)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.fnSurface)
        )
    }

    // MARK: - Computed Helpers

    private var distanceText: String {
        let m = option.distance_m
        if m < 1000 { return "\(m) m" }
        return String(format: "%.1f km", Double(m) / 1000.0)
    }

    private var estimatedTime: String {
        let km = Double(option.distance_m) / 1000.0
        let minutes = Int(km * 6.0)
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes) min"
    }

    private var estimatedCalories: String {
        "\(Int(Double(option.distance_m) / 1000.0 * 60))"
    }

    // MARK: - Logic

    private func buildPolyline() {
        let mkCoords = option.geojson.coords2D
        guard !mkCoords.isEmpty else { return }
        let pl = MKPolyline(coordinates: mkCoords, count: mkCoords.count)
        self.polyline = pl
        fit(to: pl)
    }

    private func fit(to poly: MKPolyline) {
        let rect = poly.boundingMapRect
        let center = MKMapPoint(x: rect.midX, y: rect.midY).coordinate
        let tl = MKMapPoint(x: rect.minX, y: rect.minY).coordinate
        let br = MKMapPoint(x: rect.maxX, y: rect.maxY).coordinate
        let latD = max(abs(tl.latitude - br.latitude) * 1.3, 0.01)
        let lngD = max(abs(tl.longitude - br.longitude) * 1.3, 0.01)
        mapRegion = MKCoordinateRegion(center: center,
                                       span: MKCoordinateSpan(latitudeDelta: latD, longitudeDelta: lngD))
    }

    private func sendFeedback() {
        let body: [String: Any] = ["rating": rating]
        let data = try! JSONSerialization.data(withJSONObject: body)
        APIClient.shared.request("run/routes/\(option.id)/feedback", method: "POST", body: data, authorized: true)
            .sink { completion in
                if case .failure(let e) = completion { self.message = e.localizedDescription }
            } receiveValue: { (_: SimpleOK) in
                withAnimation { self.feedbackSent = true }
                self.message = "¡Gracias!"
            }
            .store(in: &bag)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Map Representable
// ─────────────────────────────────────────────────────────────────────────────

struct MapViewRepresentable: UIViewRepresentable {
    var polyline: MKPolyline?
    @Binding var region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsCompass = false
        map.showsScale = false
        map.isRotateEnabled = false
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        map.setRegion(region, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let cur = map.region
        let new = region
        let changed = abs(cur.center.latitude - new.center.latitude) > 0.0001 ||
                      abs(cur.center.longitude - new.center.longitude) > 0.0001 ||
                      abs(cur.span.latitudeDelta - new.span.latitudeDelta) > 0.0001
        if changed { map.setRegion(new, animated: false) }
        map.removeOverlays(map.overlays)
        if let pl = polyline { map.addOverlay(pl, level: .aboveLabels) }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let pl = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: pl)
                r.lineWidth = 5
                r.strokeColor = UIColor(Color.fnCyan)
                r.lineJoin = .round
                r.lineCap = .round
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
