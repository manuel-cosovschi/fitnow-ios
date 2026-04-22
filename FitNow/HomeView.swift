import SwiftUI
import Combine

// MARK: - HomeViewModel (unchanged business logic)

final class HomeViewModel: ObservableObject {
    @Published var upcomingCount = 0
    @Published var weeklyRunKm: Double = 0
    @Published var streakDays = 0
    @Published var featuredOffer: SpecialOffer? = nil

    private var bag = Set<AnyCancellable>()

    func load() {
        let offerQ = [
            URLQueryItem(name: "status", value: "approved"),
            URLQueryItem(name: "limit", value: "1")
        ]
        APIClient.shared.request("offers", authorized: false, query: offerQ)
            .sink { _ in }
            receiveValue: { [weak self] (resp: OffersListResponse) in
                self?.featuredOffer = resp.items.first
            }
            .store(in: &bag)

        let q = [URLQueryItem(name: "when", value: "upcoming")]
        APIClient.shared.request("enrollments/mine", authorized: true, query: q)
            .sink { _ in }
            receiveValue: { [weak self] (resp: ListResponse<EnrollmentItem>) in
                self?.upcomingCount = resp.items.count
                self?.computeStreak(from: resp.items)
            }
            .store(in: &bag)

        APIClient.shared.request("run/sessions/mine", authorized: true)
            .sink { _ in }
            receiveValue: { [weak self] (resp: RunSessionsResponse) in
                let weekAgo = Date().addingTimeInterval(-7 * 86_400)
                let fracF = ISO8601DateFormatter(); fracF.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let basicF = ISO8601DateFormatter(); basicF.formatOptions = [.withInternetDateTime]
                let recent = resp.items.filter { s in
                    guard let ds = s.started_at else { return false }
                    let d = fracF.date(from: ds) ?? basicF.date(from: ds)
                    return (d ?? .distantPast) >= weekAgo
                }
                self?.weeklyRunKm = recent.compactMap { $0.distance_m }.reduce(0, +) / 1000
            }
            .store(in: &bag)
    }

    private func computeStreak(from items: [EnrollmentItem]) {
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
    @State private var appeared = false

    private var firstName: String {
        let first = (auth.user?.name ?? "").components(separatedBy: " ").first ?? ""
        return first.isEmpty ? "Atleta" : first
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:  return "Buenos días"
        case 12..<18: return "Buenas tardes"
        default:      return "Buenas noches"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroHeader
                    contentBody.padding(.top, 20)
                }
                .padding(.bottom, 40)
            }
            .background(Color.fnBg)
            .ignoresSafeArea(edges: .top)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
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
                colors: [Color.fnBlue.opacity(0.22), Color.fnBg],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 230)

            Circle()
                .fill(Color.fnBlue.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: 120, y: -60)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.fnSlate)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                        .animation(.spring(response: 0.5).delay(0.1), value: appeared)

                    Text("Hola, \(firstName)!")
                        .font(.custom("DM Serif Display", size: 30))
                        .foregroundColor(.fnWhite)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.5).delay(0.15), value: appeared)

                    Text("¿Listo para entrenar hoy?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.fnSlate)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
                        .animation(.spring(response: 0.5).delay(0.2), value: appeared)
                }
                Spacer()

                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle().fill(FNGradient.primary).frame(width: 52, height: 52)
                        Text(String((auth.user?.name ?? "A").prefix(1)).uppercased())
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .fnShadowBrand()
                    Circle().fill(Color.fnGreen).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.fnBg, lineWidth: 2))
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.5)
                .animation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.25), value: appeared)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .padding(.top, 60)
        }
    }

    // MARK: - Body

    private var contentBody: some View {
        VStack(spacing: 28) {
            statsSection
            quickActionsSection
            promoBannerSection
            newsSection
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.3), value: appeared)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(vm.upcomingCount)",
                     label: "Próximas",
                     icon: "figure.run",
                     color: .fnBlue)
            StatCard(value: vm.weeklyRunKm > 0 ? String(format: "%.1f", vm.weeklyRunKm) : "0",
                     label: "Km corridos",
                     icon: "map.fill",
                     color: .fnGreen)
            StatCard(value: vm.streakDays > 0 ? "\(vm.streakDays)·" : "0",
                     label: "Días activos",
                     icon: "flame.fill",
                     color: .fnAmber)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Accesos rápidos")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    NavigationLink { ActivitiesListView() } label: {
                        quickCard(title: "Explorar",
                                  subtitle: "Gyms, trainers, clubes",
                                  icon: "magnifyingglass",
                                  gradient: FNGradient.primary)
                    }
                    NavigationLink { CalendarView() } label: {
                        quickCard(title: "Calendario",
                                  subtitle: "Tus próximas clases",
                                  icon: "calendar",
                                  gradient: FNGradient.success)
                    }
                    NavigationLink { MyEnrollmentsView() } label: {
                        quickCard(title: "Inscripciones",
                                  subtitle: "Tus actividades",
                                  icon: "list.bullet.rectangle.fill",
                                  gradient: FNGradient.provider)
                    }
                    NavigationLink { RunPlannerView() } label: {
                        quickCard(title: "Correr",
                                  subtitle: "Planificá tu ruta",
                                  icon: "figure.run",
                                  gradient: FNGradient.primary)
                    }
                    NavigationLink { FavoritesView() } label: {
                        quickCard(title: "Favoritos",
                                  subtitle: "Actividades guardadas",
                                  icon: "heart.fill",
                                  gradient: FNGradient.trainer)
                    }
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func quickCard(title: String,
                            subtitle: String,
                            icon: String,
                            gradient: LinearGradient) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle().fill(Color.white.opacity(0.20))
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
                    .lineLimit(2)
            }
        }
        .frame(width: 140, alignment: .leading)
        .padding(18)
        .frame(height: 140)
        .background(RoundedRectangle(cornerRadius: 22).fill(gradient))
        .fnShadowBrand()
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
                        .foregroundColor(.fnBlue)
                }
            }
            .padding(.horizontal, 20)

            NavigationLink { SpecialOffersView() } label: {
                promoBannerBody
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
        }
    }

    private var promoBannerBody: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vm.featuredOffer?.discount_label ?? "NUEVO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.95))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.22), in: Capsule())

                    Text(vm.featuredOffer?.title ?? "Ofertas especiales")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)

                    Text(vm.featuredOffer?.description ??
                         "Descuentos exclusivos de entrenadores, gimnasios y clubes")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.80))
                        .lineLimit(2)

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
            }
            .padding(22)

            Circle().fill(Color.white.opacity(0.08)).frame(width: 140).offset(x: 30, y: -10)
            Circle().fill(Color.white.opacity(0.05)).frame(width: 90).offset(x: 70, y: 40)
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(
                    colors: [.fnPurple, Color(hex: "#5533CC")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .fnShadowColored(.fnPurple)
    }

    // MARK: - News

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Novedades")
                .padding(.horizontal, 20)

            VStack(spacing: 10) {
                FNInfoRow(icon: "checkmark.seal.fill",
                          iconColor: .fnGreen,
                          title: "Nuevos entrenadores verificados",
                          subtitle: "Encontramos profesionales cerca tuyo")
                FNInfoRow(icon: "creditcard.fill",
                          iconColor: .fnBlue,
                          title: "Pagá con tarjeta o transferencia",
                          subtitle: "Todas las formas de pago disponibles")
                FNInfoRow(icon: "bell.badge.fill",
                          iconColor: .fnAmber,
                          title: "Recordatorios automáticos",
                          subtitle: "Te avisamos 24h y 1h antes de cada clase")
            }
            .padding(.horizontal, 20)
        }
    }
}
