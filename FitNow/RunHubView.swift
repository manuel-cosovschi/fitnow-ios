import SwiftUI
import Combine

// ─── Run Session model ─────────────────────────────────────────────────────────

struct RunSession: Identifiable, Decodable {
    let id: Int
    let started_at: String?
    let finished_at: String?
    let distance_m: Double?
    let duration_s: Double?
    let avg_pace_s_per_km: Double?
    let status: String?
}

struct RunSessionsResponse: Decodable {
    let items: [RunSession]
}

// ─── ViewModel ─────────────────────────────────────────────────────────────────

final class RunHistoryViewModel: ObservableObject {
    @Published var sessions: [RunSession] = []
    @Published var loading = false
    @Published var error: String?

    private var bag = Set<AnyCancellable>()

    func fetch() {
        loading = true; error = nil
        APIClient.shared.request("run/sessions/mine", authorized: true)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: RunSessionsResponse) in
                self?.sessions = resp.items
            }
            .store(in: &bag)
    }
}

// ─── Run Hub View ──────────────────────────────────────────────────────────────

struct RunHubView: View {
    @StateObject private var vm = RunHistoryViewModel()
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Hero CTA
                runCTA
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Stats summary
                if !vm.sessions.isEmpty {
                    runStatsSummary
                        .padding(.horizontal, 16)
                }

                // History
                historySection
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Correr")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            vm.fetch()
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
    }

    // MARK: - CTA

    private var runCTA: some View {
        NavigationLink(destination: RunPlannerView()) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 56, height: 56)
                    Image(systemName: "figure.run")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Planificar nueva ruta")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("Generá rutas con IA y salí a correr")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(FNGradient.run)
            )
            .fnShadowColored(.fnCyan)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Stats Summary

    private var runStatsSummary: some View {
        let totalKm = vm.sessions.compactMap { $0.distance_m }.reduce(0, +) / 1000
        let totalRuns = vm.sessions.count
        let avgPace = vm.sessions.compactMap { $0.avg_pace_s_per_km }.reduce(0, +) / Double(max(vm.sessions.count, 1))

        return VStack(alignment: .leading, spacing: 14) {
            Text("Tu historial")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            HStack(spacing: 12) {
                StatCard(value: "\(totalRuns)", label: "Corridas", icon: "figure.run", color: .fnCyan)
                StatCard(value: String(format: "%.1f", totalKm), label: "Km totales", icon: "map.fill", color: .fnGreen)
                StatCard(value: avgPace > 0 ? formatPace(avgPace) : "—", label: "Ritmo prom.", icon: "stopwatch.fill", color: .fnYellow)
            }
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Corridas recientes")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            if vm.loading && vm.sessions.isEmpty {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonView(cornerRadius: 16).frame(height: 80)
                    }
                }
            } else if vm.error != nil {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.secondary)
                    Text("No se pudo cargar el historial")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Reintentar") { vm.fetch() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.fnPrimary)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
            } else if vm.sessions.isEmpty {
                emptyHistory
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(vm.sessions.prefix(20).enumerated()), id: \.element.id) { index, session in
                        RunSessionCard(session: session)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.06),
                                value: appeared
                            )
                    }
                }
            }
        }
    }

    private var emptyHistory: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 36))
                .foregroundColor(Color(.tertiaryLabel))
            Text("Sin corridas registradas")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Tu historial aparecerá acá después de tu primera salida.")
                .font(.system(size: 13))
                .foregroundColor(Color(.tertiaryLabel))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func formatPace(_ secondsPerKm: Double) -> String {
        let mins = Int(secondsPerKm) / 60
        let secs = Int(secondsPerKm) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
}

// ─── Run Session Card ──────────────────────────────────────────────────────────

private let runDateDF: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "es_AR")
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
}()
private let runIsoFrac: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
}()
private let runIsoBasic: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
}()

struct RunSessionCard: View {
    let session: RunSession

    private var distanceKm: Double { (session.distance_m ?? 0) / 1000 }
    private var durationMin: Int { Int((session.duration_s ?? 0) / 60) }
    private var dateString: String {
        guard let s = session.started_at,
              let d = runIsoFrac.date(from: s) ?? runIsoBasic.date(from: s) else { return "—" }
        return runDateDF.string(from: d)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(FNGradient.run)
                    .frame(width: 46, height: 46)
                Image(systemName: "figure.run")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .fnShadowColored(.fnCyan, radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(dateString)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                HStack(spacing: 10) {
                    Label(String(format: "%.2f km", distanceKm), systemImage: "map.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    if durationMin > 0 {
                        Label("\(durationMin) min", systemImage: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if let pace = session.avg_pace_s_per_km, pace > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(formatPace(pace))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.fnCyan)
                    Text("min/km")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.fnCyan.opacity(0.12), lineWidth: 1)
                )
        )
        .fnShadow(radius: 8, y: 3)
    }

    private func formatPace(_ s: Double) -> String {
        let mins = Int(s) / 60; let secs = Int(s) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
}
