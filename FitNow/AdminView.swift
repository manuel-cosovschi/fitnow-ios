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
    @EnvironmentObject private var auth: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                AdminOverviewTab()
            }
            .tabItem { Label("Resumen", systemImage: selectedTab == 0 ? "chart.bar.fill" : "chart.bar") }
            .tag(0)

            NavigationStack {
                AdminUsersTab()
            }
            .tabItem { Label("Usuarios", systemImage: selectedTab == 1 ? "person.3.fill" : "person.3") }
            .tag(1)

            NavigationStack {
                AdminProvidersTab()
            }
            .tabItem { Label("Proveedores", systemImage: selectedTab == 2 ? "briefcase.fill" : "briefcase") }
            .tag(2)

            NavigationStack {
                AdminOffersTab()
            }
            .tabItem { Label("Ofertas", systemImage: selectedTab == 3 ? "tag.fill" : "tag") }
            .tag(3)

            NavigationStack {
                AdminActivitiesTab()
            }
            .tabItem { Label("Actividades", systemImage: selectedTab == 4 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle") }
            .tag(4)

            NavigationStack {
                adminProfileTab
            }
            .tabItem { Label("Perfil", systemImage: selectedTab == 5 ? "person.circle.fill" : "person.circle") }
            .tag(5)
        }
        .tint(.fnPurple)
    }

    private var adminProfileTab: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)
            ZStack {
                Circle().fill(FNGradient.primary).frame(width: 80, height: 80)
                Text(String((auth.user?.name ?? "A").prefix(1)).uppercased())
                    .font(.system(size: 32, weight: .bold)).foregroundColor(.white)
            }
            VStack(spacing: 6) {
                Text(auth.user?.name ?? "Admin")
                    .font(.system(size: 20, weight: .bold))
                Text(auth.user?.email ?? "")
                    .font(.system(size: 14)).foregroundColor(.secondary)
                Text("Administrador").font(.system(size: 12, weight: .bold))
                    .foregroundColor(.fnCrimson)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.fnCrimson.opacity(0.12), in: Capsule())
            }
            Spacer()
            Button(role: .destructive) {
                auth.logout()
            } label: {
                Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.fnSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.fnSecondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.large)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Admin Overview Tab
// ─────────────────────────────────────────────────────────────────────────────

struct AdminOverviewTab: View {
    @StateObject private var vm = AdminStatsViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                if vm.loading && vm.stats == nil {
                    VStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonView(cornerRadius: 16).frame(height: 80)
                        }
                    }
                    .padding(.horizontal, 16)
                } else if let s = vm.stats {
                    kpiGrid(s).padding(.horizontal, 16)
                    if let pending = s.pending_offers, pending > 0 {
                        pendingBanner(pending).padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.fnBg)
        .navigationTitle("Panel Admin")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { vm.load() }
        .onAppear { vm.load() }
    }

    private var headerBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.fnPurple.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: "shield.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.fnPurple)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Administración FitNow")
                    .font(.system(size: 16, weight: .bold))
                Text("Panel de control interno")
                    .font(.system(size: 12))
                    .foregroundColor(.fnSlate)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func kpiGrid(_ s: AdminStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            kpiCard(value: "\(s.total_users ?? 0)",       label: "Usuarios",        icon: "person.3.fill",              color: .fnCyan)
            kpiCard(value: "\(s.total_providers ?? 0)",   label: "Proveedores",     icon: "briefcase.fill",             color: .fnPurple)
            kpiCard(value: "\(s.total_activities ?? 0)",  label: "Actividades",     icon: "list.bullet.rectangle.fill", color: .fnPrimary)
            kpiCard(value: "\(s.total_enrollments ?? 0)", label: "Inscripciones",   icon: "checkmark.seal.fill",        color: .fnGreen)
            if let rev = s.total_revenue, rev > 0 {
                kpiCard(value: "$\(Int(rev))", label: "Revenue total", icon: "dollarsign.circle.fill", color: .fnYellow)
            }
        }
    }

    private func kpiCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.custom("DM Serif Display", size: 28))
                .foregroundColor(.fnWhite)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.fnSlate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.15), lineWidth: 1))
    }

    private func pendingBanner(_ count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.fnYellow)
            Text("\(count) oferta\(count == 1 ? "" : "s") pendiente\(count == 1 ? "" : "s") de revisión")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.fnWhite)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.fnSlate)
        }
        .padding(14)
        .background(Color.fnYellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.fnYellow.opacity(0.25), lineWidth: 1))
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
                if let label = offer.discount_label, !label.isEmpty {
                    Text(label)
                        .font(.custom("DM Serif Display", size: 14))
                        .foregroundColor(.fnPrimary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.fnPrimary.opacity(0.10), in: Capsule())
                }
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


final class AdminStatsViewModel: ObservableObject {
    @Published var stats: AdminStats?
    @Published var loading = false
    @Published var error: String?
    private var bag = Set<AnyCancellable>()

    func load() {
        loading = true; error = nil
        APIClient.shared.requestPublisher("admin/stats", authorized: true)
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
    @State private var query = ""
    @State private var roleFilter = "all"
    private let roleOptions = [("all","Todos"), ("user","Usuarios"), ("provider_admin","Proveedores"), ("admin","Admins")]

    private var filtered: [AdminUserItem] {
        vm.users.filter { u in
            let matchesRole = roleFilter == "all" || u.role == roleFilter
            let matchesQuery = query.isEmpty ||
                u.name.localizedCaseInsensitiveContains(query) ||
                u.email.localizedCaseInsensitiveContains(query)
            return matchesRole && matchesQuery
        }
    }

    var body: some View {
        ZStack {
            Color.fnBg.ignoresSafeArea()
            VStack(spacing: 0) {
                searchBar
                roleFilterBar
                Rectangle().fill(Color.fnBorder.opacity(0.5)).frame(height: 0.5)
                usersContent
            }
        }
        .navigationTitle("Usuarios")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fnBg, for: .navigationBar)
        .onAppear { vm.load() }
        .refreshable { vm.load() }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(.fnSlate).font(.system(size: 14))
            TextField("Buscar por nombre o email…", text: $query)
                .font(.system(size: 14)).foregroundColor(.fnWhite)
        }
        .padding(12)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fnBorder, lineWidth: 1))
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var roleFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(roleOptions, id: \.0) { key, label in
                    Button { roleFilter = key } label: {
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(roleFilter == key ? .white : .fnSlate)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(roleFilter == key ? Color.fnPurple : Color.fnSurface,
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var usersContent: some View {
        if vm.loading && vm.users.isEmpty {
            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in SkeletonView(cornerRadius: 12).frame(height: 68) }
            }.padding(.horizontal, 16).padding(.top, 12)
        } else if filtered.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "person.slash").font(.system(size: 40)).foregroundColor(.fnAsh)
                Text("Sin resultados").font(.system(size: 15, weight: .semibold)).foregroundColor(.fnSlate)
            }
            Spacer()
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { user in userRow(user) }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
    }

    private func userRow(_ user: AdminUserItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.fnPurple.opacity(0.15)).frame(width: 40, height: 40)
                Text(String(user.name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.fnPurple)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.name).font(.system(size: 14, weight: .semibold)).foregroundColor(.fnWhite)
                    if user.is_banned == true {
                        Text("Baneado").font(.system(size: 9, weight: .bold))
                            .foregroundColor(.fnCrimson)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.fnCrimson.opacity(0.12), in: Capsule())
                    }
                }
                Text(user.email).font(.system(size: 12)).foregroundColor(.fnSlate).lineLimit(1)
            }
            Spacer()
            roleBadge(user.role ?? "user")
            Menu {
                if user.is_banned == true {
                    Button("Desbanear") { vm.setBanned(userId: user.id, banned: false) }
                } else {
                    Button("Banear usuario", role: .destructive) { vm.setBanned(userId: user.id, banned: true) }
                }
                Divider()
                Button("Hacer proveedor") { vm.setRole(userId: user.id, role: "provider_admin") }
                Button("Hacer usuario")   { vm.setRole(userId: user.id, role: "user") }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 18)).foregroundColor(.fnSlate)
            }
        }
        .padding(12)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 13))
    }

    private func roleBadge(_ role: String) -> some View {
        let (label, color): (String, Color) = {
            switch role {
            case "provider_admin": return ("Proveedor", .fnPurple)
            case "admin":          return ("Admin", .fnCrimson)
            default:               return ("Usuario", .fnCyan)
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .bold)).foregroundColor(color)
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
        APIClient.shared.requestPublisher("admin/users", authorized: true)
            .sink { [weak self] _ in self?.loading = false }
            receiveValue: { [weak self] (resp: UsersResponse) in
                self?.users = resp.items; self?.loading = false
            }
            .store(in: &bag)
    }

    func setBanned(userId: Int, banned: Bool) {
        guard let data = try? JSONSerialization.data(withJSONObject: ["is_banned": banned]) else { return }
        APIClient.shared.requestPublisher("admin/users/\(userId)", method: "PATCH", body: data, authorized: true)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] (_: AdminUserItem) in
                self?.load()
            })
            .store(in: &bag)
    }

    func setRole(userId: Int, role: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: ["role": role]) else { return }
        APIClient.shared.requestPublisher("admin/users/\(userId)", method: "PATCH", body: data, authorized: true)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] (_: AdminUserItem) in
                self?.load()
            })
            .store(in: &bag)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Admin Providers Tab
// ─────────────────────────────────────────────────────────────────────────────

struct AdminProvidersTab: View {
    @StateObject private var vm = AdminProvidersViewModel()
    @State private var query = ""
    @State private var statusFilter = "all"
    private let statusOptions = [("all","Todos"), ("active","Activos"), ("suspended","Suspendidos"), ("pending","Pendientes")]

    private var filtered: [AdminProviderItem] {
        vm.providers.filter { p in
            let matchesStatus = statusFilter == "all" || p.status == statusFilter
            let matchesQuery = query.isEmpty || p.name.localizedCaseInsensitiveContains(query) ||
                (p.email?.localizedCaseInsensitiveContains(query) == true)
            return matchesStatus && matchesQuery
        }
    }

    var body: some View {
        ZStack {
            Color.fnBg.ignoresSafeArea()
            VStack(spacing: 0) {
                searchBar
                statusFilterBar
                Rectangle().fill(Color.fnBorder.opacity(0.5)).frame(height: 0.5)
                providersContent
            }
        }
        .navigationTitle("Proveedores")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fnBg, for: .navigationBar)
        .onAppear { vm.load() }
        .refreshable { vm.load() }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(.fnSlate).font(.system(size: 14))
            TextField("Buscar proveedor…", text: $query)
                .font(.system(size: 14)).foregroundColor(.fnWhite)
        }
        .padding(12)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fnBorder, lineWidth: 1))
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(statusOptions, id: \.0) { key, label in
                    Button { statusFilter = key } label: {
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(statusFilter == key ? .white : .fnSlate)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(statusFilter == key ? Color.fnPurple : Color.fnSurface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var providersContent: some View {
        if vm.loading && vm.providers.isEmpty {
            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in SkeletonView(cornerRadius: 12).frame(height: 72) }
            }.padding(.horizontal, 16).padding(.top, 12)
        } else if filtered.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "briefcase.slash").font(.system(size: 40)).foregroundColor(.fnAsh)
                Text("Sin proveedores").font(.system(size: 15, weight: .semibold)).foregroundColor(.fnSlate)
            }
            Spacer()
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { p in providerRow(p) }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
    }

    private func providerRow(_ p: AdminProviderItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.fnPurple.opacity(0.12)).frame(width: 42, height: 42)
                Image(systemName: "briefcase.fill").font(.system(size: 16, weight: .semibold)).foregroundColor(.fnPurple)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(p.name).font(.system(size: 14, weight: .semibold)).foregroundColor(.fnWhite)
                HStack(spacing: 6) {
                    if let email = p.email {
                        Text(email).font(.system(size: 11)).foregroundColor(.fnSlate).lineLimit(1)
                    }
                    if let count = p.activity_count, count > 0 {
                        Text("· \(count) act.").font(.system(size: 11)).foregroundColor(.fnAsh)
                    }
                }
            }
            Spacer()
            statusBadge(p.status ?? "active")
            Menu {
                if p.status == "suspended" {
                    Button("Reactivar") { vm.setStatus(providerId: p.id, status: "active") }
                } else {
                    Button("Suspender", role: .destructive) { vm.setStatus(providerId: p.id, status: "suspended") }
                }
                if p.status == "pending" {
                    Button("Aprobar") { vm.setStatus(providerId: p.id, status: "active") }
                }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 18)).foregroundColor(.fnSlate)
            }
        }
        .padding(12)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 13))
    }

    private func statusBadge(_ status: String) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case "active":    return ("Activo", .fnGreen)
            case "suspended": return ("Suspendido", .fnCrimson)
            case "pending":   return ("Pendiente", .fnYellow)
            default:          return (status, .fnSlate)
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .bold)).foregroundColor(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

final class AdminProvidersViewModel: ObservableObject {
    @Published var providers: [AdminProviderItem] = []
    @Published var loading = false
    private var bag = Set<AnyCancellable>()

    struct ProvidersResponse: Decodable { let items: [AdminProviderItem] }

    func load() {
        loading = true
        APIClient.shared.requestPublisher("admin/providers", authorized: true)
            .sink { [weak self] _ in self?.loading = false }
            receiveValue: { [weak self] (resp: ProvidersResponse) in
                self?.providers = resp.items; self?.loading = false
            }
            .store(in: &bag)
    }

    func setStatus(providerId: Int, status: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: ["status": status]) else { return }
        APIClient.shared.requestPublisher("admin/providers/\(providerId)", method: "PATCH", body: data, authorized: true)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] (_: AdminProviderItem) in
                self?.load()
            })
            .store(in: &bag)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Admin Activities Tab (approve/reject draft activities)
// ─────────────────────────────────────────────────────────────────────────────

struct AdminActivitiesTab: View {
    @StateObject private var vm = AdminActivitiesViewModel()

    var body: some View {
        Group {
            if vm.loading && vm.activities.isEmpty {
                ProgressView("Cargando actividades…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.activities.isEmpty {
                VStack(spacing: 16) {
                    Spacer(minLength: 60)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52)).foregroundColor(.fnGreen)
                    Text("Sin actividades pendientes")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Todas las actividades enviadas han sido revisadas.")
                        .font(.system(size: 14)).foregroundColor(.fnSlate)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.activities) { activity in
                            activityCard(activity)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
            }
        }
        .background(Color.fnBg)
        .navigationTitle("Actividades")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { vm.load() }
        .refreshable { vm.load() }
    }

    private func activityCard(_ a: Activity) -> some View {
        let info = ActivityTypeInfo.from(kind: a.kind ?? "")
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(info.color.opacity(0.15)).frame(width: 42, height: 42)
                    Image(systemName: info.icon).font(.system(size: 16, weight: .semibold)).foregroundColor(info.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(a.title).font(.system(size: 15, weight: .bold)).foregroundColor(.fnWhite)
                    if let provider = a.provider_name, !provider.isEmpty {
                        Text("Por: \(provider)").font(.system(size: 12)).foregroundColor(.fnSlate)
                    }
                }
                Spacer()
                if let price = a.price, price > 0 {
                    Text("$\(Int(price))").font(.system(size: 14, weight: .bold)).foregroundColor(.fnGreen)
                }
            }

            if let desc = a.description, !desc.isEmpty {
                Text(desc).font(.system(size: 13)).foregroundColor(.fnSlate).lineLimit(2)
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation { vm.reject(activityId: a.id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Rechazar")
                    }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.fnSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.fnSecondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.fnSecondary.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    withAnimation { vm.approve(activityId: a.id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Aprobar")
                    }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(FNGradient.success, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(16)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.fnBorder.opacity(0.3), lineWidth: 0.5))
    }
}

final class AdminActivitiesViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var loading = false
    private var bag = Set<AnyCancellable>()

    func load() {
        loading = true
        APIClient.shared.requestPublisher("admin/activities", authorized: true)
            .sink { [weak self] _ in self?.loading = false }
            receiveValue: { [weak self] (resp: ListResponse<Activity>) in
                self?.activities = resp.items; self?.loading = false
            }
            .store(in: &bag)
    }

    func approve(activityId: Int) {
        APIClient.shared.requestPublisher("admin/activities/\(activityId)/approve", method: "POST", authorized: true)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] (_: Activity) in
                self?.activities.removeAll { $0.id == activityId }
            })
            .store(in: &bag)
    }

    func reject(activityId: Int) {
        APIClient.shared.requestPublisher("admin/activities/\(activityId)/reject", method: "POST", authorized: true)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] (_: Activity) in
                self?.activities.removeAll { $0.id == activityId }
            })
            .store(in: &bag)
    }
}
