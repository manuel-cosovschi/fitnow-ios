import SwiftUI
import Combine

// MARK: - ViewModel

final class ProviderDashboardViewModel: ObservableObject {
    let providerId: Int?
    @Published var activities: [Activity] = []
    @Published var loading = false
    @Published var error: String?

    private var bag = Set<AnyCancellable>()

    init(providerId: Int?) {
        self.providerId = providerId
    }

    func load() {
        loading = true; error = nil
        let url = providerId.map { "activities?provider_id=\($0)&limit=50" } ?? "activities?limit=50"
        APIClient.shared.request(url)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: ListResponse<Activity>) in
                self?.loading = false
                self?.activities = resp.items
            }
            .store(in: &bag)
    }

    func createActivity(_ payload: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        APIClient.shared.request("activities", method: "POST", body: data)
            .sink { result in
                if case .failure = result { completion(false) }
            } receiveValue: { [weak self] (a: Activity) in
                self?.activities.insert(a, at: 0)
                completion(true)
            }
            .store(in: &bag)
    }
}

// MARK: - Main View

struct ProviderDashboardView: View {
    let providerId: Int?
    @StateObject private var vm: ProviderDashboardViewModel
    @State private var selectedTab = 0

    init(providerId: Int?) {
        self.providerId = providerId
        _vm = StateObject(wrappedValue: ProviderDashboardViewModel(providerId: providerId))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ProviderHomeTab(vm: vm)
            }
            .tabItem { Label("Inicio", systemImage: selectedTab == 0 ? "house.fill" : "house") }
            .tag(0)

            NavigationStack {
                ProviderActivitiesTab(vm: vm)
            }
            .tabItem { Label("Mis actividades", systemImage: selectedTab == 1 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle") }
            .tag(1)

            NavigationStack {
                ProviderMyOffersView()
            }
            .tabItem { Label("Ofertas", systemImage: selectedTab == 2 ? "tag.fill" : "tag") }
            .tag(2)

            ProfileView()
                .tabItem { Label("Perfil", systemImage: selectedTab == 3 ? "person.circle.fill" : "person.circle") }
                .tag(3)
        }
        .tint(.fnPurple)
        .onAppear { vm.load() }
    }
}

// MARK: - Home Tab

private struct ProviderHomeTab: View {
    @EnvironmentObject private var auth: AuthViewModel
    @ObservedObject var vm: ProviderDashboardViewModel

    private var activeCount: Int {
        vm.activities.filter { $0.status == "active" }.count
    }
    private var totalCapacity: Int {
        vm.activities.compactMap { $0.capacity }.reduce(0, +)
    }
    private var totalSeatsLeft: Int {
        vm.activities.compactMap { $0.seats_left }.reduce(0, +)
    }
    private var occupancyPercent: Int {
        guard totalCapacity > 0 else { return 0 }
        return Int(Double(totalCapacity - totalSeatsLeft) / Double(totalCapacity) * 100)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerCard
                statsGrid
                if !vm.activities.isEmpty {
                    activitySummarySection
                }
                quickActionsSection
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(Color.fnBg)
        .navigationTitle("Panel")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { vm.load() }
    }

    private var headerCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(FNGradient.club)
                .frame(height: 120)
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 180, height: 180)
                        .offset(x: 100, y: -20),
                    alignment: .topTrailing
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("Bienvenido,")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Text(auth.user?.name ?? "Proveedor")
                    .font(.custom("DM Serif Display", size: 22))
                    .foregroundColor(.white)
                Text("Panel de proveedor · \(vm.activities.count) actividades")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(18)
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCard(value: "\(vm.activities.count)", label: "Total", icon: "list.bullet.rectangle", color: .fnPurple)
            statCard(value: "\(activeCount)", label: "Activas", icon: "checkmark.circle.fill", color: .fnGreen)
            statCard(value: "\(occupancyPercent)%", label: "Ocupación", icon: "person.2.fill", color: .fnCyan)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.custom("DM Serif Display", size: 24))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var activitySummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actividades recientes")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(vm.activities.prefix(4).enumerated()), id: \.element.id) { i, a in
                    if i > 0 { Divider().padding(.leading, 56) }
                    activityRow(a)
                }
            }
            .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func activityRow(_ a: Activity) -> some View {
        let info = ActivityTypeInfo.from(kind: a.kind ?? "")
        let statusColor: Color = (a.status == "active") ? .fnGreen : (a.status == "cancelled") ? .fnSecondary : .fnYellow
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(info.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: info.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(info.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(a.title).font(.system(size: 14, weight: .medium))
                HStack(spacing: 6) {
                    if let price = a.price {
                        Text("$\(Int(price))").font(.system(size: 12)).foregroundColor(.fnGreen)
                    }
                    if let sl = a.seats_left, let cap = a.capacity, cap > 0 {
                        Text("·").foregroundColor(.secondary)
                        Text("\(sl)/\(cap) lugares")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Circle().fill(statusColor).frame(width: 8, height: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Acciones rápidas")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                NavigationLink { ProviderActivitiesTab(vm: vm) } label: {
                    quickCardLabel(icon: "plus.circle.fill", color: .fnGreen, title: "Nueva actividad")
                }
                .buttonStyle(PlainButtonStyle())

                NavigationLink { ProviderMyOffersView() } label: {
                    quickCardLabel(icon: "tag.fill", color: .fnYellow, title: "Nueva oferta")
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func quickCardLabel(icon: String, color: Color, title: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Activities Tab

struct ProviderActivitiesTab: View {
    @ObservedObject var vm: ProviderDashboardViewModel
    @State private var showCreate = false

    var body: some View {
        activitiesContent
            .navigationTitle("Mis actividades")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.fnPurple)
                    }
                }
            }
            .sheet(isPresented: $showCreate, onDismiss: { vm.load() }) {
                CreateActivitySheet(vm: vm)
            }
    }

    @ViewBuilder
    private var activitiesContent: some View {
        if vm.loading && vm.activities.isEmpty {
            ProgressView("Cargando…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.activities.isEmpty {
            emptyState
        } else {
            List(vm.activities) { a in
                NavigationLink {
                    ActivityHubView(activity: a)
                } label: {
                    activityRow(a)
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { vm.load() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle")
                .font(.system(size: 56))
                .foregroundColor(.fnPurple.opacity(0.5))
            Text("Sin actividades publicadas")
                .font(.system(size: 17, weight: .semibold))
            Text("Publicá tu primera actividad para que los usuarios puedan inscribirse.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button { showCreate = true } label: {
                Label("Crear primera actividad", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .background(Color.fnPurple, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func activityRow(_ a: Activity) -> some View {
        let info = ActivityTypeInfo.from(kind: a.kind ?? "")
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(info.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: info.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(info.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(a.title).font(.system(size: 15, weight: .semibold))
                HStack(spacing: 6) {
                    if let price = a.price {
                        Text("$\(Int(price))/mes")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    if let diff = a.difficulty {
                        Text("·").foregroundColor(.fnSlate.opacity(0.7))
                        Text(diff.capitalized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            statusBadge(a.status ?? "active")
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(_ s: String) -> some View {
        let label: String
        let color: Color
        switch s {
        case "active":    label = "Activa";    color = .fnGreen
        case "cancelled": label = "Cancelada"; color = .fnSecondary
        case "draft":     label = "Borrador";  color = .fnYellow
        default:          label = s;           color = .secondary
        }
        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Create Activity Sheet

private struct CreateActivitySheet: View {
    @ObservedObject var vm: ProviderDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var descriptionText = ""
    @State private var location = ""
    @State private var price = ""
    @State private var capacity = ""
    @State private var kind = "membership"
    @State private var modality = "gimnasio"
    @State private var difficulty = "media"
    @State private var enableRunning = false
    @State private var enableFiles = false
    @State private var saving = false
    @State private var errorMsg: String?

    private let kinds      = [("membership","Membresía"), ("class","Clase"), ("event","Evento"), ("course","Curso")]
    private let modalities = [("gimnasio","Gimnasio"), ("clase","Clase"), ("outdoor","Outdoor"), ("torneo","Torneo")]
    private let difficulties = [("baja","Fácil"), ("media","Media"), ("alta","Difícil")]

    var body: some View {
        NavigationStack {
            Form {
                Section("Información básica") {
                    TextField("Título de la actividad *", text: $title)
                    TextField("Descripción (opcional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Ubicación (opcional)", text: $location)
                }
                Section("Tipo y formato") {
                    Picker("Tipo", selection: $kind) {
                        ForEach(kinds, id: \.0) { Text($1).tag($0) }
                    }
                    Picker("Modalidad", selection: $modality) {
                        ForEach(modalities, id: \.0) { Text($1).tag($0) }
                    }
                    Picker("Dificultad", selection: $difficulty) {
                        ForEach(difficulties, id: \.0) { Text($1).tag($0) }
                    }
                }
                Section("Precio y capacidad") {
                    HStack {
                        Text("$")
                        TextField("Precio mensual", text: $price).keyboardType(.decimalPad)
                    }
                    HStack {
                        Image(systemName: "person.2.fill").foregroundColor(.secondary)
                        TextField("Capacidad máxima (opcional)", text: $capacity).keyboardType(.numberPad)
                    }
                }
                Section {
                    Toggle(isOn: $enableRunning) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Seguimiento de rutas").font(.system(size: 15))
                                Text("Los alumnos pueden registrar sus recorridos").font(.system(size: 12)).foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "location.north.line.fill").foregroundColor(.fnCyan)
                        }
                    }
                    .tint(.fnCyan)
                    Toggle(isOn: $enableFiles) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rutinas y archivos").font(.system(size: 15))
                                Text("Podés subir rutinas, planes y documentos para tus alumnos").font(.system(size: 12)).foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.fill").foregroundColor(.fnPurple)
                        }
                    }
                    .tint(.fnPurple)
                } header: {
                    Text("Funcionalidades adicionales")
                }
                if let err = errorMsg {
                    Section {
                        Text(err).font(.system(size: 13)).foregroundColor(.fnSecondary)
                    }
                }
            }
            .navigationTitle("Nueva actividad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { saveActivity() } label: {
                        if saving { ProgressView().tint(.fnPurple) }
                        else { Text("Publicar").bold().foregroundColor(.fnPurple) }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
        }
    }

    private func saveActivity() {
        saving = true; errorMsg = nil
        var payload: [String: Any] = [
            "title": title.trimmingCharacters(in: .whitespaces),
            "kind": kind, "modality": modality, "difficulty": difficulty
        ]
        if !descriptionText.isEmpty { payload["description"] = descriptionText }
        if !location.isEmpty        { payload["location"] = location }
        if let p = Double(price.replacingOccurrences(of: ",", with: ".")) { payload["price"] = p }
        if let c = Int(capacity) { payload["capacity"] = c }
        if enableRunning { payload["enable_running"] = true }
        if enableFiles   { payload["enable_files"] = true }

        vm.createActivity(payload) { success in
            saving = false
            if success { dismiss() }
            else { errorMsg = "No se pudo crear la actividad. Intentá de nuevo." }
        }
    }
}
