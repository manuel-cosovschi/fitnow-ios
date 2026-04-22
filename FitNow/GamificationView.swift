import SwiftUI
import Combine

// MARK: - ViewModel

final class GamificationViewModel: ObservableObject {
    @Published var profile: GamificationProfile?
    @Published var ranking: [RankingUser] = []
    @Published var allBadges: [BadgeItem] = []
    @Published var xpHistory: [XpLogEntry] = []
    @Published var loading = false
    @Published var rankingType = "global"
    @Published var error: String?

    private var bag = Set<AnyCancellable>()

    func loadProfile() {
        loading = true; error = nil
        APIClient.shared.request("gamification/me", authorized: true)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: GamificationProfile) in
                self?.profile = resp
            }
            .store(in: &bag)
    }

    func loadRanking() {
        let q = [URLQueryItem(name: "type", value: rankingType)]
        APIClient.shared.request("gamification/ranking", authorized: true, query: q)
            .sink { _ in }
            receiveValue: { [weak self] (resp: PagedGamification<RankingUser>) in
                self?.ranking = resp.items
            }
            .store(in: &bag)
    }

    func loadBadges() {
        APIClient.shared.request("gamification/badges", authorized: true)
            .sink { _ in }
            receiveValue: { [weak self] (badges: [BadgeItem]) in
                self?.allBadges = badges
            }
            .store(in: &bag)
    }

    func loadXpHistory() {
        APIClient.shared.request("gamification/me/history", authorized: true)
            .sink { _ in }
            receiveValue: { [weak self] (resp: PagedGamification<XpLogEntry>) in
                self?.xpHistory = resp.items
            }
            .store(in: &bag)
    }
}

// MARK: - Main View

struct GamificationView: View {
    @StateObject private var vm = GamificationViewModel()
    @State private var selectedTab = 0
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                if vm.loading && vm.profile == nil {
                    VStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in SkeletonView(cornerRadius: 16).frame(height: 80) }
                    }
                    .padding(.horizontal, 16)
                } else if let profile = vm.profile {
                    levelHeader(profile)
                    statsGrid(profile.stats)
                    badgesSection(profile.badges)
                    segmentedSection
                } else if let error = vm.error {
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.slash").font(.title).foregroundColor(.secondary)
                        Text(error).font(.caption).foregroundColor(.secondary)
                        Button("Reintentar") { vm.loadProfile() }
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.fnPrimary)
                    }
                    .padding(40)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.fnBg)
        .navigationTitle("Mi progreso")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            vm.loadProfile()
            vm.loadRanking()
            vm.loadBadges()
            vm.loadXpHistory()
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
    }

    // MARK: - Level Header

    private func levelHeader(_ p: GamificationProfile) -> some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [.fnPrimary, .fnSecondary.opacity(0.85), Color.fnBg],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 200)

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .frame(width: 80, height: 80)
                        Circle()
                            .trim(from: 0, to: xpProgress(p))
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        Text("\(p.level)")
                            .font(.custom(\"JetBrains Mono\", size: 32).weight(.heavy))
                            .foregroundColor(.white)
                    }

                    Text("\(p.total_xp) XP")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))

                    HStack(spacing: 16) {
                        Label("\(p.streak_days) días", systemImage: "flame.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                        Label("\(p.badges.count) badges", systemImage: "medal.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.top, 20)
            }
        }
    }

    private func xpProgress(_ p: GamificationProfile) -> CGFloat {
        let currentLevelXp = Double((p.level - 1) * (p.level - 1)) * 100
        let nextLevelXp = Double(p.level * p.level) * 100
        let range = nextLevelXp - currentLevelXp
        guard range > 0 else { return 1.0 }
        return CGFloat((Double(p.total_xp) - currentLevelXp) / range)
    }

    // MARK: - Stats Grid

    private func statsGrid(_ stats: UserStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Estadísticas")
                .padding(.horizontal, 20)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(value: "\(stats.total_run_sessions)", label: "Corridas", icon: "figure.run", color: .fnCyan)
                StatCard(value: String(format: "%.1f km", stats.total_run_km), label: "Distancia", icon: "map.fill", color: .fnGreen)
                StatCard(value: "\(stats.total_gym_sessions)", label: "Gym", icon: "dumbbell.fill", color: .fnPurple)
                StatCard(value: "\(stats.total_gym_sets)", label: "Sets", icon: "bolt.fill", color: .fnYellow)
                StatCard(value: "\(stats.total_enrollments)", label: "Clases", icon: "calendar", color: .fnPrimary)
                StatCard(value: "\(stats.total_feedbacks)", label: "Reviews", icon: "star.fill", color: .fnPink)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Badges Section

    private func badgesSection(_ badges: [UserBadge]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Badges obtenidos")
                .padding(.horizontal, 20)

            if badges.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "medal").font(.title2).foregroundColor(.secondary)
                        Text("Completá actividades para ganar badges")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                    }
                    .padding(20)
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(badges.enumerated()), id: \.element.code) { index, badge in
                            badgeCard(badge)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 12)
                                .animation(.spring(response: 0.45).delay(Double(index) * 0.06), value: appeared)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func badgeCard(_ badge: UserBadge) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badgeColor(badge.category).opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: badge.sfSymbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(badgeColor(badge.category))
            }
            Text(badge.name)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
            Text(badge.description)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 90)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.fnSurface))
        .fnShadow(radius: 6, y: 2)
    }

    private func badgeColor(_ category: String) -> Color {
        switch category {
        case "running": return .fnCyan
        case "gym":     return .fnPurple
        case "streak":  return .fnYellow
        case "social":  return .fnGreen
        default:        return .fnPrimary
        }
    }

    // MARK: - Segmented Section (Ranking / XP History)

    private var segmentedSection: some View {
        VStack(spacing: 14) {
            Picker("", selection: $selectedTab) {
                Text("Ranking").tag(0)
                Text("Historial XP").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            if selectedTab == 0 {
                rankingSection
            } else {
                xpHistorySection
            }
        }
    }

    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(["global", "weekly"], id: \.self) { type in
                    Button {
                        vm.rankingType = type
                        vm.loadRanking()
                    } label: {
                        Text(type == "global" ? "Global" : "Semanal")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(vm.rankingType == type ? .white : .primary)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(
                                Capsule().fill(vm.rankingType == type ? Color.fnPrimary : Color.fnElevated)
                            )
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            if vm.ranking.isEmpty {
                Text("Sin datos de ranking").font(.system(size: 13)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).padding(20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(vm.ranking.prefix(20).enumerated()), id: \.element.id) { index, user in
                        rankingRow(position: index + 1, user: user)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func rankingRow(position: Int, user: RankingUser) -> some View {
        HStack(spacing: 12) {
            Text("#\(position)")
                .font(.custom(\"JetBrains Mono\", size: 14).weight(.heavy))
                .foregroundColor(position <= 3 ? .fnPrimary : .secondary)
                .frame(width: 36)

            ZStack {
                Circle().fill(FNGradient.primary).frame(width: 36, height: 36)
                Text(String(user.name.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.system(size: 14, weight: .semibold))
                if let level = user.level {
                    Text("Nivel \(level)").font(.system(size: 11)).foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("\(user.total_xp ?? user.weekly_xp ?? 0) XP")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.fnPrimary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.fnSurface))
    }

    private var xpHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.xpHistory.isEmpty {
                Text("Sin historial de XP").font(.system(size: 13)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).padding(20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(vm.xpHistory.prefix(30)) { entry in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(sourceColor(entry.source).opacity(0.15)).frame(width: 36, height: 36)
                                Image(systemName: sourceIcon(entry.source))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(sourceColor(entry.source))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sourceLabel(entry.source)).font(.system(size: 13, weight: .semibold))
                                if let note = entry.note {
                                    Text(note).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            Text("+\(entry.xp) XP")
                                .font(.system(size: 13, weight: .bold)).foregroundColor(.fnGreen)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.fnSurface))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func sourceIcon(_ source: String) -> String {
        switch source {
        case "run_session":   return "figure.run"
        case "gym_session":   return "dumbbell.fill"
        case "enrollment":    return "calendar.badge.plus"
        case "hazard_report": return "exclamationmark.triangle.fill"
        case "route_feedback":return "star.fill"
        default:              return "bolt.fill"
        }
    }

    private func sourceColor(_ source: String) -> Color {
        switch source {
        case "run_session":   return .fnCyan
        case "gym_session":   return .fnPurple
        case "enrollment":    return .fnPrimary
        case "hazard_report": return .fnYellow
        case "route_feedback":return .fnGreen
        default:              return .fnPink
        }
    }

    private func sourceLabel(_ source: String) -> String {
        switch source {
        case "run_session":   return "Sesión de running"
        case "gym_session":   return "Sesión de gym"
        case "enrollment":    return "Inscripción"
        case "hazard_report": return "Reporte de peligro"
        case "route_feedback":return "Feedback de ruta"
        case "manual":        return "XP manual"
        default:              return source.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
