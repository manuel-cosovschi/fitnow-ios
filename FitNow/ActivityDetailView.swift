import SwiftUI
import Combine

// ─── Formatters ──────────────────────────────────────────────────────────────

fileprivate let isoFrac: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
}()
fileprivate let isoBasic: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
}()
fileprivate let mysqlDF: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f
}()
fileprivate let outDF: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "es_AR")
    f.dateStyle = .medium; f.timeStyle = .short; return f
}()
fileprivate func pretty(_ s: String?) -> String {
    guard let s = s else { return "—" }
    if let d = isoFrac.date(from: s) ?? isoBasic.date(from: s) ?? mysqlDF.date(from: s) { return outDF.string(from: d) }
    return s
}

fileprivate let typicalClubSports = ["Fútbol", "Tenis", "Natación", "Básquet", "Hockey"]
fileprivate struct SportName: Identifiable, Decodable { let id: Int; let name: String }
fileprivate struct SportsResponse: Decodable { let items: [SportName] }
fileprivate func uniquePrefix(_ arr: [String], max: Int) -> [String] {
    var seen = Set<String>(); var out: [String] = []
    for s in arr where !s.isEmpty { if !seen.contains(s) { seen.insert(s); out.append(s); if out.count == max { break } } }
    return out
}

fileprivate struct ProviderLite: Decodable {
    let name: String?; let kind: String?; let address: String?; let city: String?
}
fileprivate struct ActivityAndProviderResponse: Decodable {
    let activity: Activity; let provider: ProviderLite?
}

final class EnrollHelper: ObservableObject { var bag = Set<AnyCancellable>() }

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ActivityDetailView
// ─────────────────────────────────────────────────────────────────────────────

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let activity: Activity
    var previousTitle: String? = nil

    @State private var seatsLeft: Int?
    @State private var startISO: String?
    @State private var endISO: String?
    @State private var enrolled = false
    @State private var enrollmentId: Int?
    @State private var sessions: [ActivitySession] = []
    @State private var clubSports: [String] = []
    @State private var providerName: String?
    @State private var providerAddress: String?
    @State private var providerCity: String?
    @State private var enrolling = false
    @State private var message: String?
    @StateObject private var helper = EnrollHelper()
    @State private var appeared = false

    init(activity: Activity, previousTitle: String? = nil) {
        self.activity = activity
        self.previousTitle = previousTitle
        _seatsLeft    = State(initialValue: activity.seats_left)
        _startISO     = State(initialValue: activity.date_start)
        _endISO       = State(initialValue: activity.date_end)
        _providerName = State(initialValue: activity.provider_name)
    }

    private var kind: String { activity.kind ?? "" }
    private var isTrainer: Bool { kind == "trainer" }
    private var isClub: Bool    { kind == "club" }
    private var showSeatsLeft: Bool { kind == "club_sport" }
    private var supportsRunning: Bool { ["trainer", "gym", "club"].contains(kind) }

    private var typeInfo: ActivityTypeInfo { ActivityTypeInfo.from(kind: kind) }

    private var promos: [String] {
        switch kind {
        case "trainer":    return ["Clase de prueba gratis", "Pack 4 clases −10%", "Cancelación sin costo hasta 24 h"]
        case "gym":        return ["Plan trimestral −15%", "Bonificación de matrícula", "Traé un amigo y ganá 1 semana"]
        case "club":       return ["Primer mes −20%", "2 invitaciones sin cargo", "Acceso a todas las sedes"]
        case "club_sport": return ["Descuento por equipo", "Torneos internos mensuales", "Inscripción anual bonificada"]
        default:           return ["Promo bienvenida −10%"]
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    infoBody
                        .padding(.bottom, enrolled ? 90 : 100)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Floating bottom CTA
            bottomCTA
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(CustomBackToolbar(previousTitle: previousTitle, dismiss: dismiss))
        .toolbar {
            if supportsRunning && enrolled {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { RunPlannerView() } label: {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.fnCyan)
                    }
                    .accessibilityLabel("Rutas de running")
                }
            }
        }
        .onAppear {
            fetchActivity()
            checkEnrollment()
            if isTrainer { fetchSessions() }
            if isClub     { fetchClubSports() }
            withAnimation(.spring(response: 0.6).delay(0.05)) { appeared = true }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            typeInfo.gradient
                .frame(maxWidth: .infinity)
                .frame(height: 280)

            // Decorative shapes
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 180)
                .offset(x: 180, y: -40)
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 100)
                .offset(x: 240, y: 20)

            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Type icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 60, height: 60)
                    Image(systemName: typeInfo.icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }

                // Title
                Text(activity.title)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(3)

                // Badges row
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: typeInfo.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(typeInfo.label)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.22)))

                    if let diff = activity.difficulty, !diff.isEmpty {
                        Text(diffLabel(diff))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.22)))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .padding(.top, 80)
        }
    }

    private func diffLabel(_ d: String) -> String {
        switch d.lowercased() {
        case "baja": return "Fácil"
        case "media": return "Media"
        case "alta": return "Difícil"
        default: return d.capitalized
        }
    }

    // MARK: - Info Body

    private var infoBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Location + price row
            locationPriceRow

            // Description
            if let desc = activity.description, !desc.isEmpty {
                descriptionCard(desc)
            }

            // Provider card
            if providerName != nil || providerAddress != nil || providerCity != nil {
                providerCard
            }

            // Message
            if let msg = message {
                messageCard(msg)
            }

            // Trainer sessions info
            if isTrainer {
                trainerSection
            }

            // Dates
            datesCard

            // Seats (club_sport)
            if showSeatsLeft, let left = seatsLeft {
                seatsCard(left)
            }

            // Running access (enrolled)
            if supportsRunning && enrolled {
                runningCard
            }

            // Club sports
            if isClub && !clubSports.isEmpty {
                clubSportsCard
            }

            // Promos
            promosCard

            // Cancel enrollment button
            if enrolled {
                cancelButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: - Subviews

    private var locationPriceRow: some View {
        HStack(spacing: 0) {
            if let loc = activity.location, !loc.isEmpty {
                Label(loc, systemImage: "mappin.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
                    .lineLimit(1)
            }
            Spacer()
            if let p = activity.price, p > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "$%.0f", p))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(typeInfo.color)
                    Text("por mes")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.secondaryLabel))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func descriptionCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Descripción", systemImage: "text.alignleft")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(.secondaryLabel))
                .textCase(.uppercase)
                .tracking(0.5)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Color(.label))
                .lineSpacing(4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                isTrainer ? "Entrenador" : (isClub ? "Club" : (kind == "gym" ? "Gimnasio" : "Proveedor")),
                systemImage: typeInfo.icon
            )
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(typeInfo.color)
            .textCase(.uppercase)
            .tracking(0.5)

            VStack(alignment: .leading, spacing: 6) {
                if let name = providerName, !name.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(typeInfo.color)
                        Text(name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(.label))
                    }
                }
                if let addr = providerAddress, !addr.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(Color(.tertiaryLabel))
                        Text(addr)
                            .font(.system(size: 14))
                            .foregroundColor(Color(.secondaryLabel))
                    }
                }
                if let city = providerCity, !city.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(Color(.tertiaryLabel))
                        Text(city)
                            .font(.system(size: 14))
                            .foregroundColor(Color(.secondaryLabel))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(typeInfo.color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func messageCard(_ msg: String) -> some View {
        let isSuccess = msg.starts(with: "¡")
        return HStack(spacing: 10) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(isSuccess ? .fnGreen : .fnSecondary)
            Text(msg)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSuccess ? .fnGreen : .fnSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill((isSuccess ? Color.fnGreen : Color.fnSecondary).opacity(0.10))
        )
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var trainerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Próximas clases")

            if sessions.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("No hay clases publicadas por ahora.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.secondaryLabel))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
            } else {
                VStack(spacing: 8) {
                    ForEach(sessions) { s in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.fnPrimary.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.fnPrimary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pretty(s.start_at))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(.label))
                                Text(pretty(s.end_at))
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(.secondaryLabel))
                                if let lvl = s.level, !lvl.isEmpty {
                                    Text("Nivel: \(lvl)")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(.tertiaryLabel))
                                }
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }
                }
            }

            Text("Una vez inscripto, podés reservar tus clases desde Mis inscripciones.")
                .font(.system(size: 12))
                .foregroundColor(Color(.tertiaryLabel))
        }
    }

    private var datesCard: some View {
        HStack(spacing: 0) {
            dateItem(label: "Inicio", value: pretty(startISO), icon: "calendar", color: .fnGreen)
            Divider()
                .frame(height: 40)
                .padding(.horizontal, 12)
            dateItem(label: "Fin", value: pretty(endISO), icon: "calendar.badge.checkmark", color: .fnSecondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func dateItem(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(.secondaryLabel))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.label))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func seatsCard(_ count: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.fnYellow.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.fnYellow)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Cupos disponibles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(.secondaryLabel))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text("\(count) lugares")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(count > 3 ? .fnGreen : .fnYellow)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.fnYellow.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var runningCard: some View {
        NavigationLink { RunPlannerView() } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FNGradient.run)
                        .frame(width: 48, height: 48)
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                .fnShadowColored(.fnCyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rutas de running")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(.label))
                    Text("Generá rutas personalizadas cerca tuyo")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.secondaryLabel))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.fnCyan.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var clubSportsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Deportes del club")
            VStack(spacing: 8) {
                ForEach(clubSports, id: \.self) { name in
                    HStack(spacing: 10) {
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.fnGreen)
                        Text(name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(.label))
                        Spacer()
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                }
            }
            Text("Para inscribirte a un deporte, primero hacete socio. Luego, desde Mis inscripciones, elegís el deporte y te inscribís.")
                .font(.system(size: 12))
                .foregroundColor(Color(.tertiaryLabel))
        }
    }

    private var promosCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Promociones")
            VStack(spacing: 8) {
                ForEach(promos, id: \.self) { promo in
                    HStack(spacing: 10) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.fnYellow)
                        Text(promo)
                            .font(.system(size: 14))
                            .foregroundColor(Color(.label))
                        Spacer()
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                }
            }
        }
    }

    private var cancelButton: some View {
        VStack(spacing: 6) {
            FitNowOutlineButton(
                title: "Cancelar inscripción",
                icon: "xmark.circle",
                color: .fnSecondary
            ) {
                cancelEnrollment()
            }
            .disabled(enrolling || enrollmentId == nil)
            .opacity(enrolling || enrollmentId == nil ? 0.5 : 1)

            Text(isTrainer ? "Ya estás inscripto a este entrenador."
                           : "Ya estás inscripto en esta actividad.")
                .font(.system(size: 12))
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 0) {
                if !enrolled {
                    FitNowButton(
                        title: "Inscribirme",
                        icon: "plus.circle.fill",
                        gradient: typeInfo.gradient,
                        isLoading: enrolling,
                        isDisabled: enrolling
                    ) {
                        createEnrollment()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.fnGreen)
                        Text("Inscripto")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.fnGreen)
                        Spacer()
                        if supportsRunning {
                            NavigationLink { RunPlannerView() } label: {
                                Label("Correr", systemImage: "figure.run")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.fnCyan)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(Color.fnCyan.opacity(0.12)))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
            .background(Color(.systemBackground))
        }
    }

    // MARK: - API Calls

    private func createEnrollment() {
        enrolling = true; message = nil
        let payload = try! JSONEncoder().encode(["activity_id": activity.id])
        APIClient.shared.request("enrollments", method: "POST", body: payload, authorized: true)
            .sink { completion in
                if case .failure(let e) = completion {
                    if case APIError.http(let code, let body) = e {
                        if code == 409 && (body.contains("ALREADY_ENROLLED") || body.contains("Already enrolled") || body.contains("Ya estás inscripto")) {
                            message = nil; enrolled = true
                        } else if code == 409 && (body.contains("No seats left") || body.contains("NO_SEATS")) {
                            message = "No quedan cupos disponibles."
                        } else { message = "HTTP \(code): \(body)" }
                    } else { message = e.localizedDescription }
                    enrolling = false
                }
            } receiveValue: { (_: SimpleOK) in
                message = "¡Inscripción exitosa!"
                fetchActivity(); checkEnrollment()
            }
            .store(in: &helper.bag)
    }

    private func cancelEnrollment() {
        guard let eid = enrollmentId else { return }
        enrolling = true; message = nil
        APIClient.shared.request("enrollments/\(eid)", method: "DELETE", authorized: true)
            .sink { completion in
                if case .failure(let e) = completion { message = (e as NSError).localizedDescription; enrolling = false }
            } receiveValue: { (_: SimpleOK) in
                message = "Inscripción cancelada."; enrolled = false; enrollmentId = nil; fetchActivity()
            }
            .store(in: &helper.bag)
    }

    private func fetchSessions() {
        APIClient.shared.request("activities/\(activity.id)/sessions", authorized: false)
            .sink { completion in if case .failure(let e) = completion { self.message = e.localizedDescription } }
            receiveValue: { (resp: ListResponse<ActivitySession>) in self.sessions = resp.items }
            .store(in: &helper.bag)
    }

    private func fetchClubSports() {
        guard let pid = activity.provider_id else { clubSports = typicalClubSports; return }
        APIClient.shared.request("providers/\(pid)/sports", authorized: false)
            .sink { completion in if case .failure(_) = completion, self.clubSports.isEmpty { self.clubSports = typicalClubSports } }
            receiveValue: { (resp: SportsResponse) in
                let names = resp.items.map { $0.name }
                self.clubSports = names.isEmpty ? typicalClubSports : uniquePrefix(names + typicalClubSports, max: 5)
            }
            .store(in: &helper.bag)
    }

    private func fetchActivity() {
        APIClient.shared.request("activities/\(activity.id)", authorized: false)
            .sink { _ in enrolling = false }
            receiveValue: { (resp: ActivityAndProviderResponse) in
                seatsLeft = resp.activity.seats_left
                startISO  = resp.activity.date_start
                endISO    = resp.activity.date_end
                providerName    = resp.provider?.name ?? providerName
                providerAddress = resp.provider?.address
                providerCity    = resp.provider?.city
            }
            .store(in: &helper.bag)
    }

    private func checkEnrollment() {
        APIClient.shared.request("enrollments/mine", authorized: true,
                                 query: [URLQueryItem(name: "when", value: "all")])
            .sink { _ in }
            receiveValue: { (resp: ListResponse<EnrollmentItem>) in
                if let match = resp.items.first(where: { $0.activity_id == activity.id && $0.session_id == nil }) {
                    enrolled = true; enrollmentId = match.id
                } else { enrolled = false; enrollmentId = nil }
            }
            .store(in: &helper.bag)
    }
}

// MARK: - Custom Back Toolbar

fileprivate struct CustomBackToolbar: ViewModifier {
    let previousTitle: String?
    let dismiss: DismissAction
    func body(content: Content) -> some View {
        if let prev = previousTitle {
            content
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { dismiss() } label: {
                            Label(prev, systemImage: "chevron.left").labelStyle(.titleAndIcon)
                        }
                    }
                }
        } else { content }
    }
}
