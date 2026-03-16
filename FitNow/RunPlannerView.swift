import SwiftUI
import Combine
import CoreLocation
import MapKit

private let MDP_FALLBACK = CLLocationCoordinate2D(latitude: -38.0055, longitude: -57.5426)

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RunPlannerView
// ─────────────────────────────────────────────────────────────────────────────

struct RunPlannerView: View {
    @State private var distanceKm: Double = 5
    @State private var generating = false
    @State private var error: String?
    @State private var options: [RunRouteOption] = []
    @State private var bag = Set<AnyCancellable>()
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Distance selector card
                distanceSelectorCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.5).delay(0.05), value: appeared)

                // Generate button
                FitNowButton(
                    title: "Generar rutas",
                    icon: "arrow.triangle.2.circlepath",
                    gradient: FNGradient.run,
                    isLoading: generating,
                    isDisabled: generating
                ) {
                    generate()
                }
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.10), value: appeared)

                // Error
                if let e = error {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.fnSecondary)
                        Text(e)
                            .font(.system(size: 14))
                            .foregroundColor(.fnSecondary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.fnSecondary.opacity(0.10)))
                    .transition(.opacity)
                }

                // Route options
                if !options.isEmpty {
                    routeOptionsSection
                } else if !generating {
                    hintCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.15), value: appeared)
                }
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Rutas de running")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            LocationService.shared.start()
            withAnimation(.spring(response: 0.55).delay(0.05)) { appeared = true }
        }
    }

    // MARK: - Distance Selector Card

    private var distanceSelectorCard: some View {
        VStack(spacing: 20) {
            // Distance display
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Distancia objetivo")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(.secondaryLabel))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(Int(distanceKm))")
                            .font(.system(size: 52, weight: .heavy, design: .rounded))
                            .foregroundStyle(FNGradient.run)
                        Text("km")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(.secondaryLabel))
                            .padding(.bottom, 6)
                    }
                }
                Spacer()
                // Activity estimate
                VStack(alignment: .trailing, spacing: 4) {
                    Text("~\(estimatedTime)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))
                    Text("estimado")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("~\(estimatedCalories) kcal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.fnYellow)
                }
            }

            // Custom slider
            VStack(spacing: 8) {
                Slider(value: $distanceKm, in: 2...20, step: 1)
                    .tint(.fnCyan)
                    .animation(.spring(response: 0.3), value: distanceKm)

                HStack {
                    Text("2 km")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.tertiaryLabel))
                    Spacer()
                    Text("20 km")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }

            // Quick distance buttons
            HStack(spacing: 8) {
                ForEach([3, 5, 8, 10, 15], id: \.self) { km in
                    Button {
                        withAnimation(.spring(response: 0.3)) { distanceKm = Double(km) }
                    } label: {
                        Text("\(km)k")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Int(distanceKm) == km ? .white : Color(.secondaryLabel))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Int(distanceKm) == km
                                          ? AnyShapeStyle(FNGradient.run)
                                          : AnyShapeStyle(Color(.tertiarySystemFill)))
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.fnCyan.opacity(0.2), lineWidth: 1)
                )
        )
        .fnShadowColored(.fnCyan)
    }

    // MARK: - Route Options

    private var routeOptionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Rutas sugeridas")

            ForEach(Array(options.enumerated()), id: \.element.id) { index, opt in
                NavigationLink {
                    RunRoutePreviewView(option: opt)
                } label: {
                    routeOptionCard(opt, index: index)
                }
                .buttonStyle(ScaleButtonStyle())
                .transition(.asymmetric(
                    insertion: .push(from: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }

    private func routeOptionCard(_ opt: RunRouteOption, index: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(FNGradient.run)
                    .frame(width: 46, height: 46)
                Text("\(index + 1)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .fnShadowColored(.fnCyan)

            VStack(alignment: .leading, spacing: 4) {
                Text(opt.label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(.label))
                Text(opt.rationale)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 10))
                        .foregroundColor(.fnCyan)
                    Text(distanceLabel(opt.distance_m))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.fnCyan)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.fnCyan.opacity(0.15), lineWidth: 1)
                )
        )
        .fnShadow()
    }

    // MARK: - Hint Card

    private var hintCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(FNGradient.run)
                    .frame(width: 64, height: 64)
                    .fnShadowColored(.fnCyan)
                Image(systemName: "figure.run")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("Generá tu ruta")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))
            Text("Seleccioná la distancia que querés correr y generá rutas personalizadas desde tu ubicación actual.")
                .font(.system(size: 14))
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Helpers

    private var estimatedTime: String {
        let minutes = Int(distanceKm / 0.1) // ~6 min/km
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)min"
        }
        return "\(minutes) min"
    }

    private var estimatedCalories: Int {
        Int(distanceKm * 60) // ~60 kcal/km
    }

    private func distanceLabel(_ meters: Int) -> String {
        if meters < 1000 { return "\(meters) m" }
        return String(format: "%.1f km", Double(meters) / 1000.0)
    }

    private func generate() {
        generating = true; error = nil
        withAnimation { options = [] }
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
                withAnimation(.spring(response: 0.5)) { self.options = resp.items }
            }
            .store(in: &bag)
    }
}
