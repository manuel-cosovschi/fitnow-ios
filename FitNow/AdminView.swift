import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AdminView (Entry Point)
// Accessed via ProfileView when role == "admin", or via hidden 5-tap gesture
// on the version row. Checks auth role before showing dashboard.
// ─────────────────────────────────────────────────────────────────────────────

struct AdminView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        if auth.user?.role == "admin" {
            AdminDashboardView()
        } else {
            AdminLockedView()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AdminLockedView
// Shown when a non-admin user navigates to the admin section.
// ─────────────────────────────────────────────────────────────────────────────

struct AdminLockedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.fnSurface, Color.fnElevated],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 90, height: 90)
                Image(systemName: "lock.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(Color.fnSlate)
            }
            VStack(spacing: 8) {
                Text("Acceso restringido")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Esta sección es exclusiva para administradores de FitNow.")
                    .font(.system(size: 14))
                    .foregroundColor(.fnSlate)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
            }
            Spacer()
        }
        .navigationTitle("Administración")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AdminDashboardView
// Full admin panel with tabs: Offers, Stats, Users, Providers
// ─────────────────────────────────────────────────────────────────────────────

struct AdminDashboardView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Admin header
            adminHeader

            // Tab picker
            Picker("Sección", selection: $selectedTab) {
                Text("Ofertas").tag(0)
                Text("Estadísticas").tag(1)
                Text("Usuarios").tag(2)
                Text("Proveedores").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Content
            switch selectedTab {
            case 0: AdminOffersTab()
            case 1: AdminStatsTab()
            case 2: AdminUsersTab()
            case 3: AdminProvidersTab()
            default: EmptyView()
            }
        }
        .background(Color.fnBg)
        .navigationTitle("Panel Admin")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var adminHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.fnSecondary, .fnPurple],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                Image(systemName: "shield.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Panel de administración")
                    .font(.system(size: 15, weight: .bold))
                Text("FitNow · Acceso interno")
                    .font(.system(size: 12))
                    .foregroundColor(.fnSlate)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.fnSurface)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Admin Offers Tab
// List of pending offers to approve or reject
// ─────────────────────────────────────────────────────────────────────────────

struct AdminOffersTab: View {
    @StateObject private var vm = SpecialOffersViewModel()
    @State private var appeared = false

    var body: some View {
        Group {
            if vm.loading && vm.offers.isEmpty {
                ProgressView("Cargando ofertas…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.offers.isEmpty {
                emptyOffersState
            } else {
                offersList
            }
        }
        .onAppear {
            vm.loadPending()
            withAnimation(.spring(response: 0.5).delay(0.1)) { appeared = true }
        }
    }

    private var offersList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(vm.offers) { offer in
                    adminOfferCard(offer)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.4), value: appeared)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func adminOfferCard(_ offer: SpecialOffer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.title)
                        .font(.system(size: 15, weight: .bold))
                    if let provider = offer.provider_name, !provider.isEmpty {
                        Text("Por: \(provider)")
                            .font(.system(size: 12))
                            .foregroundColor(.fnSlate)
                    }
                }
                Spacer()
                Text(offer.discount_label)
                    .font(.custom(\"DM Serif Display\", size: 14))
                    .foregroundColor(.fnPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.fnPrimary.opacity(0.10), in: Capsule())
            }

            if let desc = offer.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(.fnSlate)
                    .lineLimit(2)
            }

            if let kind = offer.activity_kind {
                let info = ActivityTypeInfo.from(kind: kind)
                HStack(spacing: 5) {
                    Image(systemName: info.icon).font(.system(size: 11)).foregroundColor(info.color)
                    Text(info.label).font(.system(size: 11, weight: .semibold)).foregroundColor(info.color)
                }
            }

            // Approve / Reject buttons
            HStack(spacing: 10) {
                Button {
                    withAnimation { vm.reject(offerId: offer.id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Rechazar")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.fnSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.fnSecondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.fnSecondary.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    withAnimation { vm.approve(offerId: offer.id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Aprobar")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(FNGradient.success, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(16)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.fnBorder.opacity(0.3), lineWidth: 0.5))
    }

    private var emptyOffersState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundColor(.fnGreen)
            Text("Sin ofertas pendientes")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text("Todas las ofertas han sido revisadas.")
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)
            Spacer()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Admin Stats Tab
// ─────────────────────────────────────────────────────────────────────────────

struct AdminStatsTab: View {
    @StateObject private var vm = AdminStatsViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if vm.loading {
                    ProgressView("Cargando estadísticas…")
                        .padding(.top, 60)
                } else if let s = vm.stats {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        adminStatCard(value: "\(s.total_users ?? 0)",       label: "Usuarios",         icon: "person.3.fill",                 color: .fnCyan)
                        adminStatCard(value: "\(s.total_providers ?? 0)",   label: "Proveedores",      icon: "briefcase.fill",                color: .fnPurple)
                        adminStatCard(value: "\(s.total_activities ?? 0)",  label: "Publicaciones",    icon: "list.bullet.rectangle.fill",    color: .fnPrimary)
                        adminStatCard(value: "\(s.total_enrollments ?? 0)", label: "Inscripciones",   icon: "checkmark.seal.fill",           color: .fnGreen)
                        if let pending = s.pending_offers, pending > 0 {
                            adminStatCard(value: "\(pending)",              label: "Ofertas pendientes", icon: "tag.fill",                   color: .fnYellow)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                } else if let err = vm.error {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.fnSecondary)
                        .padding(30)
                }
            }
        }
        .onAppear { vm.load() }
    }

    private func adminStatCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(value)
                .font(.custom(\"DM Serif Display\", size: 28))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.fnSlate)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
    }
}

final class AdminStatsViewModel: ObservableObject {
    @Published var stats: AdminStats?
    @Published var loading = false
    @Published var error: String?
    private var bag = Set<AnyCancellable>()

    func load() {
        loading = true; error = nil
        APIClient.shared.request("admin/stats", authorized: true)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (s: AdminStats) in
                self?.stats = s
            }
            .store(in: &bag)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Admin Users Tab
// ─────────────────────────────────────────────────────────────────────────────

struct AdminUsersTab: View {
    @StateObject private var vm = AdminUsersViewModel()

    var body: some View {
        usersContent
            .onAppear { vm.load() }
    }

    @ViewBuilder
    private var usersContent: some View {
        if vm.loading && vm.users.isEmpty {
            ProgressView("Cargando usuarios…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.users.isEmpty {
            Text("Sin usuarios registrados.")
                .foregroundColor(.fnSlate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(vm.users) { user in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(user.name).font(.system(size: 14, weight: .semibold))
                        Spacer()
                        roleBadge(user.role ?? "user")
                    }
                    Text(user.email).font(.system(size: 12)).foregroundColor(.fnSlate)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func roleBadge(_ role: String) -> some View {
        let (label, color): (String, Color) = {
            switch role {
            case "provider": return ("Proveedor", .fnPurple)
            case "admin":    return ("Admin", .fnSecondary)
            default:         return ("Usuario", .fnCyan)
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

final class AdminUsersViewModel: ObservableObject {
    @Published var users: [AdminUserItem] = []
    @Published var loading = false
    private var bag = Set<AnyCancellable>()

    struct UsersResponse: Decodable { let items: [AdminUserItem] }

    func load() {
        loading = true
        APIClient.shared.request("admin/users", authorized: true)
            .sink { [weak self] _ in self?.loading = false }
            receiveValue: { [weak self] (resp: UsersResponse) in
                self?.users = resp.items; self?.loading = false
            }
            .store(in: &bag)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Admin Providers Tab
// ─────────────────────────────────────────────────────────────────────────────

struct AdminProvidersTab: View {
    @StateObject private var vm = AdminProvidersViewModel()

    var body: some View {
        providersContent
            .onAppear { vm.load() }
    }

    @ViewBuilder
    private var providersContent: some View {
        if vm.loading && vm.providers.isEmpty {
            ProgressView("Cargando proveedores…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.providers.isEmpty {
            Text("Sin proveedores registrados.")
                .foregroundColor(.fnSlate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(vm.providers) { p in
                providerRow(p)
            }
        }
    }

    private func providerRow(_ p: AdminProviderItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(p.name).font(.system(size: 14, weight: .semibold))
                Spacer()
                if let kind = p.kind {
                    let info = ActivityTypeInfo.from(kind: kind)
                    Text(info.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(info.color)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(info.color.opacity(0.12), in: Capsule())
                }
            }
            if let email = p.email {
                Text(email).font(.system(size: 12)).foregroundColor(.fnSlate)
            }
        }
        .padding(.vertical, 4)
    }
}

final class AdminProvidersViewModel: ObservableObject {
    @Published var providers: [AdminProviderItem] = []
    @Published var loading = false
    private var bag = Set<AnyCancellable>()

    struct ProvidersResponse: Decodable { let items: [AdminProviderItem] }

    func load() {
        loading = true
        APIClient.shared.request("admin/providers", authorized: true)
            .sink { [weak self] _ in self?.loading = false }
            receiveValue: { [weak self] (resp: ProvidersResponse) in
                self?.providers = resp.items; self?.loading = false
            }
            .store(in: &bag)
    }
}
