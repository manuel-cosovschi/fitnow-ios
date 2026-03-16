import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var greeting = ""
    @State private var appeared = false
    @State private var showProfile = false

    private var firstName: String {
        let name = auth.user?.name ?? ""
        return name.components(separatedBy: " ").first ?? (name.isEmpty ? "Atleta" : name)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        auth.logout()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(auth)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            updateGreeting()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
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

            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 200, height: 200)
                .offset(x: 140, y: -30)
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 120, height: 120)
                .offset(x: 200, y: 20)

            // Content
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
                StatCard(value: "0", label: "Actividades", icon: "figure.run", color: .fnPrimary)
                StatCard(value: "0 km", label: "Distancia", icon: "map.fill", color: .fnCyan)
                StatCard(value: "0 🔥", label: "Días racha", icon: "flame.fill", color: .fnYellow)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Accesos rápidos")
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                NavigationLink {
                    ActivitiesListView()
                } label: {
                    quickActionCard(
                        title: "Explorar actividades",
                        subtitle: "Entrenadores, gyms, clubes",
                        icon: "magnifyingglass",
                        gradient: FNGradient.primary
                    )
                }

                NavigationLink {
                    MyEnrollmentsView()
                } label: {
                    quickActionCard(
                        title: "Mis inscripciones",
                        subtitle: "Clases y membresías",
                        icon: "list.bullet.rectangle.portrait.fill",
                        gradient: FNGradient.run
                    )
                }
            }
            .padding(.horizontal, 20)
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
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .frame(height: 136)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(gradient)
        )
        .fnShadowBrand()
    }

    // MARK: - Promo Banner

    private var promoBannerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Oferta especial")
                .padding(.horizontal, 20)

            NavigationLink { ActivitiesListView() } label: {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("2×1 en clases de Yoga")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(.white)
                        Text("Sólo esta semana para socios")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.80))
                        HStack(spacing: 4) {
                            Text("Ver actividades")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 2)
                    }
                    Spacer()
                    Image(systemName: "figure.yoga")
                        .font(.system(size: 58))
                        .foregroundColor(.white.opacity(0.22))
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [.fnPurple, Color(red: 0.38, green: 0.10, blue: 0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
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
                    title: "Activá recordatorios de clases",
                    subtitle: "Recibí notificaciones para no perder nada"
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
