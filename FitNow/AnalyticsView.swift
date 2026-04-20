import SwiftUI
import Combine

// MARK: - Analytics ViewModel

final class AnalyticsViewModel: ObservableObject {
    @Published var runningSummary: RunningSummary?
    @Published var gymSummary: GymSummary?
    @Published var streak: StreakInfo?
    @Published var runWeekly: [WeeklyRunItem] = []
    @Published var gymWeekly: [GymWeeklyItem] = []
    @Published var muscleDist: [MuscleDistItem] = []
    @Published var loading = false

    private var bag = Set<AnyCancellable>()

    func loadAll() {
        loading = true

        let group = DispatchGroup()

        group.enter()
        APIClient.shared.request("analytics/running/summary", authorized: true)
            .sink { _ in group.leave() }
            receiveValue: { [weak self] (resp: RunningSummary) in self?.runningSummary = resp }
            .store(in: &bag)

        group.enter()
        APIClient.shared.request("analytics/gym/summary", authorized: true)
            .sink { _ in group.leave() }
            receiveValue: { [weak self] (resp: GymSummary) in self?.gymSummary = resp }
            .store(in: &bag)

        group.enter()
        APIClient.shared.request("analytics/combined/streak", authorized: true)
            .sink { _ in group.leave() }
            receiveValue: { [weak self] (resp: StreakInfo) in self?.streak = resp }
            .store(in: &bag)

        group.enter()
        let runQ = [URLQueryItem(name: "weeks", value: "8")]
        APIClient.shared.request("analytics/running/weekly", authorized: true, query: runQ)
            .sink { _ in group.leave() }
            receiveValue: { [weak self] (resp: WeeklyItemsResponse) in self?.runWeekly = resp.items }
            .store(in: &bag)

        group.enter()
        let gymQ = [URLQueryItem(name: "weeks", value: "8")]
        APIClient.shared.request("analytics/gym/weekly", authorized: true, query: gymQ)
            .sink { _ in group.leave() }
            receiveValue: { [weak self] (resp: GymWeeklyResponse) in self?.gymWeekly = resp.items }
            .store(in: &bag)

        group.enter()
        APIClient.shared.request("analytics/gym/muscle-distribution", authorized: true)
            .sink { _ in group.leave() }
            receiveValue: { [weak self] (resp: MuscleDistResponse) in self?.muscleDist = resp.items }
            .store(in: &bag)

        group.notify(queue: .main) { [weak self] in self?.loading = false }
    }
}

// MARK: - Analytics View

struct AnalyticsView: View {
    @StateObject private var vm = AnalyticsViewModel()
    @State private var selectedTab = 0
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Streak banner
                if let streak = vm.streak {
                    streakBanner(streak)
                        .padding(.horizontal, 16)
                }

                // Segment
                Picker("", selection: $selectedTab) {
                    Text("Running").tag(0)
                    Text("Gimnasio").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                if selectedTab == 0 {
                    runningSection
                } else {
                    gymSection
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Rendimiento")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            vm.loadAll()
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
    }

    // MARK: - Streak Banner

    private func streakBanner(_ s: StreakInfo) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(FNGradient.primary).frame(width: 50, height: 50)
                Image(systemName: "flame.fill").font(.system(size: 24, weight: .bold)).foregroundColor(.white)
            }
            .fnShadowBrand()

            VStack(alignment: .leading, spacing: 4) {
                Text("Racha de \(s.current_streak) días")
                    .font(.system(size: 17, weight: .bold))
                HStack(spacing: 12) {
                    Label("Récord: \(s.longest_streak)", systemImage: "trophy.fill")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                    Label("\(s.active_days_last_7)/7 esta semana", systemImage: "calendar")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.fnPrimary.opacity(0.2), lineWidth: 1))
        )
    }

    // MARK: - Running Section

    private var runningSection: some View {
        VStack(spacing: 20) {
            if let rs = vm.runningSummary {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Resumen de running").padding(.horizontal, 16)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(value: "\(rs.total_sessions ?? 0)", label: "Sesiones", icon: "figure.run", color: .fnCyan)
                        StatCard(value: formatDist(rs.total_distance_m ?? 0), label: "Km total", icon: "map.fill", color: .fnGreen)
                        StatCard(value: formatPace(rs.avg_pace_s ?? 0), label: "Pace prom.", icon: "stopwatch.fill", color: .fnYellow)
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        miniStat("Mejor pace", formatPace(rs.best_pace_s ?? 0), .fnGreen)
                        miniStat("Más larga", formatDist(rs.longest_run_m ?? 0), .fnCyan)
                        miniStat("Desnivel", "\(Int(rs.total_elevation_gain_m ?? 0))m", .fnYellow)
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Weekly chart representation
            if !vm.runWeekly.isEmpty {
                weeklyRunChart
            }
        }
    }

    private var weeklyRunChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Km por semana").padding(.horizontal, 16)

            let maxDist = vm.runWeekly.map { $0.distance_m }.max() ?? 1

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(vm.runWeekly.suffix(8)) { week in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(FNGradient.run)
                            .frame(width: 28, height: max(4, CGFloat(week.distance_m / maxDist) * 100))
                        Text(String(week.week_start.suffix(5)))
                            .font(.system(size: 8)).foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 120, alignment: .bottom)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Gym Section

    private var gymSection: some View {
        VStack(spacing: 20) {
            if let gs = vm.gymSummary {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Resumen de gym").padding(.horizontal, 16)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(value: "\(gs.total_sessions ?? 0)", label: "Sesiones", icon: "dumbbell.fill", color: .fnPurple)
                        StatCard(value: "\(gs.total_sets ?? 0)", label: "Sets", icon: "bolt.fill", color: .fnCyan)
                        StatCard(value: String(format: "%.0f", gs.total_volume_kg ?? 0), label: "Kg total", icon: "scalemass.fill", color: .fnYellow)
                    }
                    .padding(.horizontal, 16)

                    if let fav = gs.favorite_exercise {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill").foregroundColor(.fnYellow)
                            Text("Ejercicio favorito: \(fav)").font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }

            // Muscle distribution
            if !vm.muscleDist.isEmpty {
                muscleDistSection
            }
        }
    }

    private var muscleDistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Distribución muscular").padding(.horizontal, 16)

            ForEach(vm.muscleDist) { item in
                HStack(spacing: 12) {
                    Text(item.muscle_group.capitalized)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 80, alignment: .leading)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(FNGradient.gym)
                            .frame(width: max(4, geo.size.width * CGFloat(item.percentage / 100)))
                    }
                    .frame(height: 16)

                    Text(String(format: "%.0f%%", item.percentage))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Helpers

    private func miniStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    private func formatDist(_ meters: Double) -> String {
        let km = meters / 1000
        return km >= 10 ? String(format: "%.0f km", km) : String(format: "%.1f km", km)
    }

    private func formatPace(_ s: Double) -> String {
        guard s > 0 else { return "—" }
        let mins = Int(s) / 60; let secs = Int(s) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
}
