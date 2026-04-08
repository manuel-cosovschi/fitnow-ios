import SwiftUI
import Combine

// MARK: - HomeViewModel

final class HomeViewModel: ObservableObject {
    @Published var upcomingCount = 0
    @Published var weeklyRunKm: Double = 0
    @Published var streakDays = 0
    @Published var featuredOffer: SpecialOffer? = nil

    private var bag = Set<AnyCancellable>()

    func load() {
        // Featured special offer
        let offerQ = [URLQueryItem(name: "status", value: "approved"), URLQueryItem(name: "limit", value: "1")]
        APIClient.shared.request("offers", authorized: false, query: offerQ)
            .sink { _ in }
            receiveValue: { [weak self] (resp: OffersListResponse) in
                self?.featuredOffer = resp.items.first
            }
            .store(in: &bag)

        // Upcoming enrollments count
        let q = [URLQueryItem(name: "when", value: "upcoming")]
        APIClient.shared.request("enrollments/mine", authorized: true, query: q)
            .sink { _ in }
            receiveValue: { [weak self] (resp: ListResponse<EnrollmentItem>) in
                self?.upcomingCount = resp.items.count
                self?.computeStreak(from: resp.items)
            }
            .store(in: &bag)

        // Weekly run km from run sessions
        APIClient.shared.request("run/sessions/mine", authorized: true)
            .sink { _ in }
            receiveValue: { [weak self] (resp: RunSessionsResponse) in
                let weekAgo = Date().addingTimeInterval(-7 * 86_400)
                let recentSessions = resp.items.filter { s in
                    guard let ds = s.started_at else { return false }
                    let fracF = ISO8601DateFormatter()
                    fracF.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let basicF = ISO8601DateFormatter()
                    basicF.formatOptions = [.withInternetDateTime]
                    let date = fracF.date(from: ds) ?? basicF.date(from: ds)
                    return (date ?? .distantPast) >= weekAgo
                }
                self?.weeklyRunKm = recentSessions.compactMap { $0.distance_m }.reduce(0, +) / 1000
            }
            .store(in: &bag)
    }

    private func computeStreak(from items: [EnrollmentItem]) {
        // Count distinct days with upcoming activities starting from today
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var days = Set<Date>()
        for item in items {
            guard let ds = item.date_start else { continue }
            let fracF = ISO8601DateFormatter(); fracF.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let basicF = ISO8601DateFormatter(); basicF.formatOptions = [.withInternetDateTime]
            if let d = fracF.date(from: ds) ?? basicF.date(from: ds) {
                days.insert(cal.startOfDay(for: d))
            }
        }
        // Streak = consecutive days from today that have at least one activity
        var streak = 0
        var cursor = today
        while days.contains(cursor) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }
        streakDays = streak
    }
}

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var vm = HomeViewModel()
    @State private var greeting = ""
    @State private var appeared = false

    private var firstName: String {
        let name = auth.user?.name ?? ""
        let first = name.components(separatedBy: " ").first ?? ""
        return first.isEmpty ? "Atleta" : first
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroHeader
                    contentBody
                        .padding(.top, 24)
                }
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .ignoresSafeArea(edges: .top)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            updateGreeting()
            vm.load()
            NotificationsService.shared.requestPermission()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color.fnPrimary,
                    Color.fnSecondary.opacity(0.85),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 260)

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 200, height: 200)
                .offset(x: 140, y: -30)
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 120, height: 120)
                .offset(x: 200, y: 20)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.80))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(.spring(response: 0.5).delay(0.1), value: appeared)

                    Text("Hola, \(firstName)!")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.5).delay(0.15), value: appeared)

                    Text("¿Listo para entrenar hoy?")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(.spring(response: 0.5).delay(0.2), value: appeared)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 60, height: 60)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.5)
                .animation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.25), value: appeared)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Content Body

    private var contentBody: some View {
        VStack(spacing: 28) {
            statsSection
            quickActionsSection
            upcomingSection
            promoBannerSection
            newsSection
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.3), value: appeared)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Tu semana")
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                StatCard(
                    value: "\(vm.upcomingCount)",
                    label: "Próximas",
                    icon: "figure.run",
                    color: .fnPrimary
                )
                StatCard(
                    value: vm.weeklyRunKm > 0 ? String(format: "%.1f", vm.weeklyRunKm) : "0",
                    label: "Km corridos",
                    icon: "map.fill",
                    color: .fnCyan
                )
                StatCard(
                    value: vm.streakDays > 0 ? "\(vm.streakDays) 🔥" : "0",
                    label: "Días activos",
                    icon: "flame.fill",
                    color: .fnYellow
                )
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Accesos rápidos")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    NavigationLink { ActivitiesListView() } label: {
                        quickActionCard(title: "Explorar", subtitle: "Gyms, trainers, clubes",
                                        icon: "magnifyingglass", gradient: FNGradient.primary)
                    }
                    NavigationLink { CalendarView() } label: {
                        quickActionCard(title: "Calendario", subtitle: "Tus próximas clases",
                                        icon: "calendar", gradient: FNGradient.run)
                    }
                    NavigationLink { FavoritesView() } label: {
                        quickActionCard(title: "Favoritos", subtitle: "Actividades guardadas",
                                        icon: "heart.fill", gradient: FNGradient.club)
                    }
                    NavigationLink { RunPlannerView() } label: {
                        quickActionCard(title: "Correr", subtitle: "Planificá tu ruta",
                                        icon: "figure.run", gradient: FNGradient.sport)
                    }
                    NavigationLink { GymHubView() } label: {
                        quickActionCard(title: "Gym", subtitle: "Entrená con IA",
                                        icon: "dumbbell.fill", gradient: FNGradient.gym)
                    }
                    NavigationLink { AnalyticsView() } label: {
                        quickActionCard(title: "Rendimiento", subtitle: "Estadísticas y más",
                                        icon: "chart.bar.fill", gradient: FNGradient.run)
                    }
                    NavigationLink { TrainingPlanHubView() } label: {
                        quickActionCard(title: "Plan", subtitle: "Tu plan personalizado",
                                        icon: "brain.head.profile", gradient: FNGradient.club)
                    }
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func quickActionCard(
        title: String,
        subtitle: String,
        icon: String,
        gradient: LinearGradient
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            Spacer(minLength: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
        .frame(width: 136, alignment: .leading)
        .padding(18)
        .frame(height: 136)
        .background(RoundedRectangle(cornerRadius: 22).fill(gradient))
        .fnShadowBrand()
    }

    // MARK: - Upcoming activities teaser

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "Mis inscripciones",
                actionTitle: "Ver todas",
                action: nil   // navigation handled via tab
            )
            .padding(.horizontal, 20)

            NavigationLink(destination: { NavigationStack { MyEnrollmentsView() } }) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(FNGradient.primary)
                            .frame(width: 50, height: 50)
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .fnShadowBrand()

                    VStack(alignment: .leading, spacing: 3) {
                        Text(vm.upcomingCount > 0
                             ? "\(vm.upcomingCount) actividad\(vm.upcomingCount == 1 ? "" : "es") próxima\(vm.upcomingCount == 1 ? "" : "s")"
                             : "Sin actividades próximas")
                            .font(.system(size: 15, weight: .bold))
                        Text(vm.upcomingCount > 0
                             ? "Tus clases y membresías activas"
                             : "Explorá y agendá tu próximo entreno")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
                        )
                )
                .fnShadow()
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Promo Banner

    private var promoBannerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Oferta especial")
                Spacer()
                NavigationLink { SpecialOffersView() } label: {
                    Text("Ver todas")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.fnPrimary)
                }
            }
            .padding(.horizontal, 20)

            if let offer = vm.featuredOffer {
                // Real offer from backend
                NavigationLink { SpecialOffersView() } label: {
                    let kindInfo = ActivityTypeInfo.from(kind: offer.activity_kind ?? "")
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(offer.discount_label)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.white.opacity(0.22), in: Capsule())
                            Text(offer.title)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.white)
                            if let desc = offer.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.80))
                                    .lineLimit(2)
                            }
                            HStack(spacing: 4) {
                                Text("Ver oferta")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 2)
                        }
                        Spacer()
                        Image(systemName: offer.icon_name ?? kindInfo.icon)
                            .font(.system(size: 52))
                            .foregroundColor(.white.opacity(0.22))
                    }
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(offer.activity_kind == nil ? FNGradient.primary : kindInfo.gradient)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)
            } else {
                // Fallback banner when no approved offers exist
                NavigationLink { SpecialOffersView() } label: {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ofertas especiales")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.white)
                            Text("Descuentos exclusivos de entrenadores, gimnasios y clubes")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.80))
                            HStack(spacing: 4) {
                                Text("Ver ofertas")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 2)
                        }
                        Spacer()
                        Image(systemName: "tag.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.white.opacity(0.22))
                    }
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                LinearGradient(
                                    colors: [.fnPurple, Color(red: 0.38, green: 0.10, blue: 0.92)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - News Section

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Novedades")
                .padding(.horizontal, 20)

            VStack(spacing: 10) {
                FNInfoRow(
                    icon: "checkmark.seal.fill",
                    iconColor: .fnGreen,
                    title: "Nuevos entrenadores verificados",
                    subtitle: "Encontramos profesionales cerca tuyo"
                )
                FNInfoRow(
                    icon: "creditcard.fill",
                    iconColor: .fnCyan,
                    title: "Pagá con tarjeta o transferencia",
                    subtitle: "Todas las formas de pago disponibles"
                )
                FNInfoRow(
                    icon: "bell.badge.fill",
                    iconColor: .fnYellow,
                    title: "Recordatorios automáticos",
                    subtitle: "Te avisamos 24h y 1h antes de cada clase"
                )
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helpers

    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: greeting = "Buenos días"
        case 12..<18: greeting = "Buenas tardes"
        default: greeting = "Buenas noches"
        }
    }
}

#if DEBUG
#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
#endif
