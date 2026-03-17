import SwiftUI
import Combine

// MARK: - ViewModel

final class ProviderDashboardViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var recentEnrollments: [EnrollmentItem] = []
    @Published var loading = false
    @Published var error: String?

    private var bag = Set<AnyCancellable>()

    func load() {
        loading = true
        error = nil

        // Load provider's activities
        APIClient.shared.request("activities?provider=me&limit=20")
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion {
                    self?.error = e.localizedDescription
                }
            } receiveValue: { [weak self] (resp: ListResponse<Activity>) in
                self?.activities = resp.items
            }
            .store(in: &bag)

        // Load recent enrollments for provider's activities
        APIClient.shared.request("enrollments?as_provider=true&limit=10")
            .sink { _ in } receiveValue: { [weak self] (resp: ListResponse<EnrollmentItem>) in
                self?.recentEnrollments = resp.items
            }
            .store(in: &bag)
    }
}

// MARK: - Main View

struct ProviderDashboardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var vm = ProviderDashboardViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Inicio proveedor
            NavigationStack {
                ProviderHomeTab(vm: vm)
            }
            .tabItem {
                Label("Inicio", systemImage: selectedTab == 0 ? "house.fill" : "house")
            }
            .tag(0)

            // Mis actividades
            NavigationStack {
                ProviderActivitiesTab(vm: vm)
            }
            .tabItem {
                Label("Mis actividades", systemImage: selectedTab == 1 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
            }
            .tag(1)

            // Inscripciones recibidas
            NavigationStack {
                ProviderEnrollmentsTab(vm: vm)
            }
            .tabItem {
                Label("Inscripciones", systemImage: selectedTab == 2 ? "person.2.fill" : "person.2")
            }
            .tag(2)

            // Mis ofertas
            NavigationStack {
                ProviderMyOffersView()
            }
            .tabItem {
                Label("Ofertas", systemImage: selectedTab == 3 ? "tag.fill" : "tag")
            }
            .tag(3)

            // Perfil
            ProfileView()
                .tabItem {
                    Label("Perfil", systemImage: selectedTab == 4 ? "person.circle.fill" : "person.circle")
                }
                .tag(4)
        }
        .tint(.fnPurple)
        .onAppear { vm.load() }
    }
}

// MARK: - Provider Home Tab

private struct ProviderHomeTab: View {
    @EnvironmentObject private var auth: AuthViewModel
    @ObservedObject var vm: ProviderDashboardViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                providerHeader

                // Stats row
                statsRow

                // Quick actions
                quickActionsSection

                // Recent enrollments
                if !vm.recentEnrollments.isEmpty {
                    recentEnrollmentsSection
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Panel")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { vm.load() }
    }

    private var providerHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(FNGradient.club)
                    .frame(width: 56, height: 56)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Bienvenido,")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(auth.user?.name ?? "Proveedor")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Panel de proveedor")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.fnPurple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.fnPurple.opacity(0.12), in: Capsule())
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                value: "\(vm.activities.count)",
                label: "Actividades",
                icon: "list.bullet.rectangle",
                color: .fnPurple
            )
            statCard(
                value: "\(vm.recentEnrollments.count)",
                label: "Inscripciones",
                icon: "person.2.fill",
                color: .fnCyan
            )
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }
            HStack {
                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acciones rápidas")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                NavigationLink {
                    ProviderMyOffersView()
                } label: {
                    actionRow(icon: "tag.fill", color: .fnYellow, title: "Publicar oferta especial", subtitle: "Llegá a más usuarios con descuentos")
                }
                Divider().padding(.leading, 56)
                NavigationLink {
                    ProviderActivitiesTab(vm: vm)
                } label: {
                    actionRow(icon: "plus.circle.fill", color: .fnGreen, title: "Ver mis actividades", subtitle: "\(vm.activities.count) actividades publicadas")
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func actionRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var recentEnrollmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inscripciones recientes")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(vm.recentEnrollments.prefix(5).enumerated()), id: \.element.id) { i, enr in
                    if i > 0 { Divider().padding(.leading, 56) }
                    enrollmentRow(enr)
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func enrollmentRow(_ enr: EnrollmentItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.fnCyan.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.fnCyan)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(enr.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                if let plan = enr.plan_name {
                    Text(plan)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            statusBadge(enr.status ?? "active")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func statusBadge(_ status: String) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case "active":    return ("Activo", .fnGreen)
            case "cancelled": return ("Cancelado", .fnSecondary)
            case "pending":   return ("Pendiente", .fnYellow)
            default:          return (status.capitalized, .secondary)
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Provider Activities Tab

struct ProviderActivitiesTab: View {
    @ObservedObject var vm: ProviderDashboardViewModel

    var body: some View {
        Group {
            if vm.loading && vm.activities.isEmpty {
                ProgressView("Cargando actividades…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.activities.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 52))
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("Sin actividades publicadas")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Las actividades que publiques en la plataforma aparecerán aquí.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(vm.activities) { activity in
                    NavigationLink {
                        ActivityDetailLoader(activityId: activity.id, title: activity.title)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.title)
                                .font(.system(size: 15, weight: .semibold))
                            HStack(spacing: 8) {
                                if let kind = activity.kind {
                                    let info = ActivityTypeInfo.from(kind: kind)
                                    Label(info.label, systemImage: info.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(info.color)
                                }
                                if let price = activity.price {
                                    Text("$\(Int(price))/mes")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .refreshable { vm.load() }
            }
        }
        .navigationTitle("Mis actividades")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Provider Enrollments Tab

private struct ProviderEnrollmentsTab: View {
    @ObservedObject var vm: ProviderDashboardViewModel

    var body: some View {
        Group {
            if vm.recentEnrollments.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 52))
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("Sin inscripciones recibidas")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Cuando usuarios se inscriban a tus actividades, aparecerán aquí.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(vm.recentEnrollments) { enr in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(enr.title)
                            .font(.system(size: 15, weight: .semibold))
                        HStack(spacing: 8) {
                            if let plan = enr.plan_name {
                                Text(plan)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.fnCyan)
                            }
                            Spacer()
                            statusLabel(enr.status ?? "active")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .refreshable { vm.load() }
            }
        }
        .navigationTitle("Inscripciones recibidas")
        .navigationBarTitleDisplayMode(.large)
    }

    private func statusLabel(_ status: String) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case "active":    return ("Activo", .fnGreen)
            case "cancelled": return ("Cancelado", .fnSecondary)
            case "pending":   return ("Pendiente", .fnYellow)
            default:          return (status.capitalized, .secondary)
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}
