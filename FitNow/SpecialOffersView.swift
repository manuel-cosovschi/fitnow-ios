import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SpecialOffersViewModel
// Loads approved offers for users. Also used by ProviderSubmitOfferView and
// AdminView for their respective operations.
// ─────────────────────────────────────────────────────────────────────────────

final class SpecialOffersViewModel: ObservableObject {
    @Published var offers: [SpecialOffer] = []
    @Published var loading = false
    @Published var error: String?

    private var bag = Set<AnyCancellable>()

    func loadApproved() {
        loading = true; error = nil
        let q = [URLQueryItem(name: "status", value: "approved")]
        APIClient.shared.request("offers", authorized: false, query: q)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: OffersListResponse) in
                self?.offers = resp.items
            }
            .store(in: &bag)
    }

    func loadPending() {
        loading = true; error = nil
        let q = [URLQueryItem(name: "status", value: "pending")]
        APIClient.shared.request("admin/offers", authorized: true, query: q)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: OffersListResponse) in
                self?.offers = resp.items
            }
            .store(in: &bag)
    }

    func approve(offerId: Int) {
        APIClient.shared.request("admin/offers/\(offerId)/approve", method: "POST", authorized: true)
            .sink { _ in }
            receiveValue: { [weak self] (_: SimpleOK) in
                self?.offers.removeAll { $0.id == offerId }
            }
            .store(in: &bag)
    }

    func reject(offerId: Int) {
        APIClient.shared.request("admin/offers/\(offerId)/reject", method: "POST", authorized: true)
            .sink { _ in }
            receiveValue: { [weak self] (_: SimpleOK) in
                self?.offers.removeAll { $0.id == offerId }
            }
            .store(in: &bag)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SpecialOffersView (public, for all users)
// ─────────────────────────────────────────────────────────────────────────────

struct SpecialOffersView: View {
    @StateObject private var vm = SpecialOffersViewModel()
    @State private var appeared = false

    var body: some View {
        Group {
            if vm.loading && vm.offers.isEmpty {
                loadingState
            } else if vm.offers.isEmpty {
                emptyState
            } else {
                offersList
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Ofertas especiales")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            vm.loadApproved()
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
    }

    private var offersList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(Array(vm.offers.enumerated()), id: \.element.id) { index, offer in
                    offerCard(offer)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.06), value: appeared)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func offerCard(_ offer: SpecialOffer) -> some View {
        let kindInfo = ActivityTypeInfo.from(kind: offer.activity_kind ?? "")
        return VStack(alignment: .leading, spacing: 0) {
            // Colored top banner
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.22)).frame(width: 48, height: 48)
                    Image(systemName: offer.icon_name ?? kindInfo.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    if let provider = offer.provider_name, !provider.isEmpty {
                        Text(provider)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.80))
                    }
                }
                Spacer()
                Text(offer.discount_label)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.22), in: Capsule())
            }
            .padding(18)
            .background(offer.activity_kind == nil ? FNGradient.primary : kindInfo.gradient)

            // Description + validity
            VStack(alignment: .leading, spacing: 8) {
                if let desc = offer.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 14))
                        .foregroundColor(Color(.label))
                        .lineLimit(3)
                }
                if let until = offer.valid_until {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.fnYellow)
                        Text("Válida hasta \(formattedDate(until))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.fnYellow)
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .fnShadow()
    }

    private var loadingState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonView(cornerRadius: 18).frame(height: 150)
                }
            }
            .padding(.horizontal, 16).padding(.top, 14)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "tag.slash")
                .font(.system(size: 52))
                .foregroundColor(Color(.tertiaryLabel))
            Text("Sin ofertas por ahora")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text("Las ofertas aprobadas por los proveedores aparecerán acá.")
                .font(.system(size: 14))
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
            Spacer()
        }
    }

    private func formattedDate(_ s: String) -> String {
        if let d = isoFracSO.date(from: s) ?? isoBasicSO.date(from: s) ?? mysqlSO.date(from: s) {
            return outDFSO.string(from: d)
        }
        return s
    }
}

// Date formatters (file-private)
fileprivate let isoFracSO: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
}()
fileprivate let isoBasicSO: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
}()
fileprivate let mysqlSO: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f
}()
fileprivate let outDFSO: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "es_AR")
    f.dateStyle = .medium; f.timeStyle = .none; return f
}()

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ProviderSubmitOfferView
// Allows providers to submit a new special offer for admin approval.
// ─────────────────────────────────────────────────────────────────────────────

struct ProviderSubmitOfferView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var discountLabel = ""
    @State private var activityKind = ""
    @State private var validUntil = Date().addingTimeInterval(7 * 86_400)  // default 1 week
    @State private var hasExpiry = true
    @State private var submitting = false
    @State private var submitted = false
    @State private var errorMessage: String?
    @StateObject private var helper = EnrollHelper()

    private let kindOptions: [(label: String, value: String)] = [
        ("Todos los tipos", ""),
        ("Entrenadores", "trainer"),
        ("Gimnasios",    "gym"),
        ("Clubes",       "club"),
        ("Deportes",     "club_sport"),
    ]

    var body: some View {
        NavigationStack {
            if submitted {
                successView
            } else {
                formView
            }
        }
    }

    private var formView: some View {
        Form {
            Section {
                TextField("Ej: 2×1 en clases de Yoga", text: $title)
                TextField("Descripción de la oferta", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Descuento (ej: 20% OFF, 2×1, -$500)", text: $discountLabel)
            } header: {
                Label("Detalle de la oferta", systemImage: "tag.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.fnYellow)
            } footer: {
                Text("El texto de descuento aparece destacado en el banner de la oferta.")
            }

            Section {
                Picker("Tipo de servicio", selection: $activityKind) {
                    ForEach(kindOptions, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Label("Aplicar a", systemImage: "scope")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.fnPrimary)
            }

            Section {
                Toggle("Tiene fecha de vencimiento", isOn: $hasExpiry)
                if hasExpiry {
                    DatePicker("Válida hasta", selection: $validUntil, in: Date()..., displayedComponents: .date)
                }
            } header: {
                Label("Vigencia", systemImage: "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.fnCyan)
            }

            if let err = errorMessage {
                Section {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.fnSecondary)
                }
            }

            Section {
                Button {
                    submitOffer()
                } label: {
                    if submitting {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        Text("Enviar oferta para aprobación")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)
                    }
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(canSubmit ? FNGradient.primary : LinearGradient(colors: [Color(.systemGray4)], startPoint: .leading, endPoint: .trailing))
                )
                .disabled(!canSubmit || submitting)
            } footer: {
                Text("Tu oferta será revisada por el equipo de FitNow antes de publicarse.")
            }
        }
        .navigationTitle("Nueva oferta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 60)
            ZStack {
                Circle().fill(FNGradient.success).frame(width: 100, height: 100).fnShadowColored(.fnGreen)
                Image(systemName: "checkmark").font(.system(size: 44, weight: .bold)).foregroundColor(.white)
            }
            VStack(spacing: 10) {
                Text("¡Oferta enviada!")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                Text("Tu oferta fue enviada para revisión. Te notificaremos cuando sea aprobada.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            FitNowButton(title: "Listo", icon: "checkmark.circle.fill") { dismiss() }
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !discountLabel.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submitOffer() {
        submitting = true; errorMessage = nil
        var body: [String: Any] = [
            "title": title,
            "description": description,
            "discount_label": discountLabel,
        ]
        if !activityKind.isEmpty { body["activity_kind"] = activityKind }
        if hasExpiry {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            body["valid_until"] = iso.string(from: validUntil)
        }

        let data = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
        APIClient.shared.request("offers", method: "POST", body: data, authorized: true)
            .sink { completion in
                self.submitting = false
                if case .failure(let e) = completion {
                    if case APIError.http(let code, _) = e {
                        self.errorMessage = "Error \(code). Intentá de nuevo."
                    } else {
                        self.errorMessage = e.localizedDescription
                    }
                }
            } receiveValue: { (_: SimpleOK) in
                self.submitting = false
                self.submitted = true
            }
            .store(in: &helper.bag)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ProviderMyOffersView
// Shows a provider's submitted offers and their approval status.
// ─────────────────────────────────────────────────────────────────────────────

struct ProviderMyOffersView: View {
    @StateObject private var vm = ProviderMyOffersViewModel()
    @State private var showSubmit = false

    var body: some View {
        myOffersContent
            .navigationTitle("Mis ofertas")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSubmit = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.fnPrimary)
                    }
                }
            }
            .sheet(isPresented: $showSubmit) {
                ProviderSubmitOfferView()
                    .onDisappear { vm.loadMine() }
            }
            .onAppear { vm.loadMine() }
    }

    @ViewBuilder
    private var myOffersContent: some View {
        if vm.loading && vm.offers.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.offers.isEmpty {
            providerEmptyState
        } else {
            providerOffersList
        }
    }

    private var providerOffersList: some View {
        List {
            ForEach(vm.offers) { offer in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(offer.title)
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        statusBadge(offer.status)
                    }
                    Text(offer.discount_label)
                        .font(.system(size: 13))
                        .foregroundColor(Color(.secondaryLabel))
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func statusBadge(_ status: String) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case "approved": return ("Aprobada", .fnGreen)
            case "rejected":  return ("Rechazada", .fnSecondary)
            default:          return ("Pendiente", .fnYellow)
            }
        }()
        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }

    private var providerEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "tag")
                .font(.system(size: 52))
                .foregroundColor(Color(.tertiaryLabel))
            Text("Sin ofertas publicadas")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text("Creá una oferta para atraer más clientes.")
                .font(.system(size: 14))
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
            FitNowButton(title: "Publicar oferta", icon: "plus.circle.fill") {
                showSubmit = true
            }
            .padding(.horizontal, 60)
            Spacer()
        }
        .sheet(isPresented: $showSubmit) {
            ProviderSubmitOfferView()
                .onDisappear { vm.loadMine() }
        }
    }
}

final class ProviderMyOffersViewModel: ObservableObject {
    @Published var offers: [SpecialOffer] = []
    @Published var loading = false
    private var bag = Set<AnyCancellable>()

    func loadMine() {
        loading = true
        APIClient.shared.request("offers/mine", authorized: true)
            .sink { [weak self] _ in self?.loading = false }
            receiveValue: { [weak self] (resp: OffersListResponse) in
                self?.offers = resp.items
                self?.loading = false
            }
            .store(in: &bag)
    }
}
