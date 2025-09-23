import SwiftUI
import Combine

// ---------- FORMATTERS ----------
fileprivate let isoFrac: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
fileprivate let isoBasic: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()
fileprivate let mysqlDF: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()
fileprivate let outDF: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "es_AR")
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
}()
fileprivate func pretty(_ s: String?) -> String {
    guard let s = s else { return "—" }
    if let d = isoFrac.date(from: s) ?? isoBasic.date(from: s) ?? mysqlDF.date(from: s) {
        return outDF.string(from: d)
    }
    return s
}

// Fallback de deportes típicos por si el proveedor aún no tiene cargados
fileprivate let typicalClubSports = ["Fútbol", "Tenis", "Natación", "Básquet", "Hockey"]

// Helpers para request de deportes
fileprivate struct SportName: Identifiable, Decodable { let id: Int; let name: String }
fileprivate struct SportsResponse: Decodable { let items: [SportName] }
fileprivate func uniquePrefix(_ arr: [String], max: Int) -> [String] {
    var seen = Set<String>(); var out: [String] = []
    for s in arr where !s.isEmpty {
        if !seen.contains(s) {
            seen.insert(s); out.append(s)
            if out.count == max { break }
        }
    }
    return out
}

// ---- Decodificador local del detalle con provider (lo devuelve tu backend)
fileprivate struct ProviderLite: Decodable {
    let name: String?
    let kind: String?
    let address: String?
    let city: String?
}
fileprivate struct ActivityAndProviderResponse: Decodable {
    let activity: Activity
    let provider: ProviderLite?
}

final class EnrollHelper: ObservableObject { var bag = Set<AnyCancellable>() }

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss   // para el back custom

    let activity: Activity
    /// Si querés forzar el rótulo del botón back (p.ej. “Actividades”),
    /// pasalo acá. Si es `nil`, dejamos el back nativo y NO mostramos toolbar propia.
    var previousTitle: String? = nil

    // (membresía)
    @State private var seatsLeft: Int?
    @State private var startISO: String?
    @State private var endISO: String?
    @State private var enrolled = false
    @State private var enrollmentId: Int?

    // (trainer) — solo informativo aquí
    @State private var sessions: [ActivitySession] = []

    // (club) — solo informativo aquí
    @State private var clubSports: [String] = []

    // Provider info (nombre/dirección/ciudad)
    @State private var providerName: String?
    @State private var providerAddress: String?
    @State private var providerCity: String?

    // general
    @State private var enrolling = false
    @State private var message: String?
    @StateObject private var helper = EnrollHelper()

    init(activity: Activity, previousTitle: String? = nil) {
        self.activity = activity
        self.previousTitle = previousTitle
        _seatsLeft = State(initialValue: activity.seats_left)
        _startISO  = State(initialValue: activity.date_start)
        _endISO    = State(initialValue: activity.date_end)
        // si venía de la lista con provider_name, úsalo como valor inicial
        _providerName = State(initialValue: activity.provider_name)
    }

    private var kind: String { (activity.kind ?? "") }
    private var isTrainer: Bool { kind == "trainer" }
    private var isClub:    Bool { kind == "club" }
    private var showSeatsLeft: Bool { kind == "club_sport" } // solo deportes del club usan cupos
    /// Habilita la herramienta de running para membresías de entrenador / gym / club
    private var supportsRunning: Bool { ["trainer", "gym", "club"].contains(kind) }

    // Línea compacta de metadatos
    private var metaLine: String {
        var parts: [String] = []
        if let k = activity.kind {
            switch k {
            case "trainer": parts.append("Personal Trainer")
            case "club": parts.append("Club")
            case "gym": parts.append("Gym")
            case "club_sport": parts.append("Deporte")
            default: break
            }
        }
        if let m = activity.modality, !m.isEmpty { parts.append(m.capitalized) }
        if let d = activity.difficulty, !d.isEmpty { parts.append("Dificultad: \(d.capitalized)") }
        return parts.joined(separator: " · ")
    }

    private var promos: [String] {
        switch kind {
        case "trainer":
            return ["Clase de prueba gratis", "Pack 4 clases −10%", "Cancelación sin costo hasta 24 h"]
        case "gym":
            return ["Plan trimestral −15%", "Bonificación de matrícula", "Traé un amigo y ganá 1 semana"]
        case "club":
            return ["Primer mes −20%", "2 invitaciones sin cargo", "Acceso a todas las sedes"]
        case "club_sport":
            return ["Descuento por equipo", "Torneos internos mensuales", "Inscripción anual bonificada"]
        default:
            return ["Promo bienvenida −10%"]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // Título
                Text(activity.title)
                    .font(.title).bold()

                // Meta liviano debajo del título
                if !metaLine.isEmpty {
                    Text(metaLine)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Descripción
                if let desc = activity.description, !desc.isEmpty {
                    Text(desc)
                }

                // Ubicación / Precio
                HStack {
                    Label(activity.location ?? "—", systemImage: "mappin.and.ellipse")
                    Spacer()
                    if let p = activity.price {
                        Text(String(format: "$%.0f", p))
                            .font(.headline)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                // Provider card (entrenador/club/gim)
                if providerName != nil || providerAddress != nil || providerCity != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isTrainer ? "Entrenador" : (isClub ? "Club" : (kind == "gym" ? "Gimnasio" : "Proveedor")))
                            .font(.headline)
                        if let name = providerName, !name.isEmpty {
                            HStack { Image(systemName: "person.crop.circle"); Text(name) }
                        }
                        if let addr = providerAddress, !addr.isEmpty {
                            HStack { Image(systemName: "house"); Text(addr) }
                        }
                        if let city = providerCity, !city.isEmpty {
                            HStack { Image(systemName: "building.2"); Text(city) }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Mensajes (éxito / error)
                if let msg = message {
                    Text(msg)
                        .foregroundColor(msg.starts(with: "¡") ? .green : .red)
                }

                // ---- TRAINER: sesiones SOLO como info
                if isTrainer {
                    Text("Una vez inscripto, podés reservar tus clases desde Mis inscripciones.")
                        .font(.footnote).foregroundColor(.secondary)

                    Section {
                        if sessions.isEmpty {
                            Text("No hay clases publicadas por ahora.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(sessions) { s in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pretty(s.start_at)).bold()
                                    Text(pretty(s.end_at))
                                        .font(.caption2).foregroundColor(.secondary)
                                    if let lvl = s.level, !lvl.isEmpty {
                                        Text("Nivel: \(lvl)")
                                            .font(.caption2).foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    } header: {
                        Text("Próximas clases").font(.headline).padding(.top, 4)
                    }
                }

                // ---- DATOS DE MEMBRESÍA (aplica para gym/club/trainer)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inicio: \(pretty(startISO))")
                    Text("Fin: \(pretty(endISO))")
                }
                .font(.caption).foregroundColor(.secondary)

                if showSeatsLeft, let left = seatsLeft {
                    Text("Cupos disponibles: \(left)")
                        .font(.subheadline)
                }

                // ---- HERRAMIENTAS (Rutas de running) — solo si está inscripto
                if supportsRunning && enrolled {
                    Section(header: Text("Herramientas")) {
                        NavigationLink {
                            RunPlannerView()
                        } label: {
                            Label("Rutas de running", systemImage: "figure.run.circle")
                        }
                    }
                }

                // ---- CLUB: info adicional de deportes (solo visual)
                if isClub && !clubSports.isEmpty {
                    Section {
                        ForEach(clubSports, id: \.self) { name in
                            HStack(spacing: 8) {
                                Image(systemName: "sportscourt")
                                Text(name)
                                Spacer()
                            }
                            .font(.subheadline)
                            .padding(.vertical, 4)
                        }
                        Text("Para inscribirte a un deporte, primero hacete socio. Luego, desde Mis inscripciones, elegís el deporte y te inscribís.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    } header: {
                        Text("Deportes del club")
                            .font(.headline)
                            .padding(.top, 6)
                    }
                }

                // ---- Promos (informativas)
                Section {
                    ForEach(promos, id: \.self) { p in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "tag")
                            Text(p)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Promociones")
                        .font(.headline)
                        .padding(.top, 4)
                }

                // ---- Botones de inscripción/cancelación a la actividad (membresía)
                if enrolled {
                    Button("Cancelar inscripción") { cancelEnrollment() }
                        .buttonStyle(.bordered).tint(.red)
                        .disabled(enrolling || enrollmentId == nil)
                    Text(isTrainer ? "Ya estás inscripto a este entrenador."
                                   : "Ya estás inscripto en esta actividad.")
                        .font(.footnote).foregroundColor(.red)
                } else {
                    Button(enrolling ? "Procesando..." : "Inscribirme") { createEnrollment() }
                        .buttonStyle(.borderedProminent).disabled(enrolling)
                }
            }
            .padding()
            .onAppear {
                fetchActivity()       // ahora trae también provider {name,address,city}
                checkEnrollment()     // usa when=all
                if isTrainer { fetchSessions() }
                if isClub     { fetchClubSports() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // Solo mostramos back personalizado si nos pasaron previousTitle
        .modifier(CustomBackToolbar(previousTitle: previousTitle, dismiss: dismiss))
        // Botón rápido al planner (si corresponde)
        .toolbar {
            if supportsRunning && enrolled {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        RunPlannerView()
                    } label: {
                        Image(systemName: "figure.run.circle")
                    }
                    .accessibilityLabel("Rutas de running")
                }
            }
        }
    }

    // MARK: - Membresía
    private func createEnrollment() {
        enrolling = true; message = nil
        let payload = try! JSONEncoder().encode(["activity_id": activity.id])

        APIClient.shared.request("enrollments", method: "POST", body: payload, authorized: true)
            .sink { completion in
                if case .failure(let e) = completion {
                    if case APIError.http(let code, let body) = e {
                        if code == 409 && body.contains("Already enrolled") {
                            message = "Ya estás inscripto en esta actividad."
                            enrolled = true
                        } else if code == 409 && body.contains("No seats left") {
                            message = "No quedan cupos disponibles."
                        } else {
                            message = "HTTP \(code): \(body)"
                        }
                    } else {
                        message = e.localizedDescription
                    }
                    enrolling = false
                }
            } receiveValue: { (_: SimpleOK) in
                message = "¡Inscripción exitosa!"
                fetchActivity()
                checkEnrollment()
            }
            .store(in: &helper.bag)
    }

    private func cancelEnrollment() {
        guard let eid = enrollmentId else { return }
        enrolling = true; message = nil

        APIClient.shared.request("enrollments/\(eid)", method: "DELETE", authorized: true)
            .sink { completion in
                if case .failure(let e) = completion {
                    message = (e as NSError).localizedDescription
                    enrolling = false
                }
            } receiveValue: { (_: SimpleOK) in
                message = "Inscripción cancelada."
                enrolled = false
                enrollmentId = nil
                fetchActivity()
            }
            .store(in: &helper.bag)
    }

    // MARK: - Trainer: info de sesiones
    private func fetchSessions() {
        APIClient.shared.request("activities/\(activity.id)/sessions", authorized: false)
            .sink { completion in
                if case .failure(let e) = completion { self.message = e.localizedDescription }
            } receiveValue: { (resp: ListResponse<ActivitySession>) in
                self.sessions = resp.items
            }
            .store(in: &helper.bag)
    }

    // MARK: - Club: deportes informativos
    private func fetchClubSports() {
        // Si no tenemos provider_id, mostramos el fallback
        guard let pid = activity.provider_id else {
            clubSports = typicalClubSports
            return
        }
        APIClient.shared.request("providers/\(pid)/sports", authorized: false)
            .sink { completion in
                if case .failure(_) = completion, self.clubSports.isEmpty {
                    self.clubSports = typicalClubSports
                }
            } receiveValue: { (resp: SportsResponse) in
                let names = resp.items.map { $0.name }
                self.clubSports = names.isEmpty
                    ? typicalClubSports
                    : uniquePrefix(names + typicalClubSports, max: 5)
            }
            .store(in: &helper.bag)
    }

    // MARK: - Datos básicos (ahora con provider)
    private func fetchActivity() {
        APIClient.shared.request("activities/\(activity.id)", authorized: false)
            .sink { _ in enrolling = false } receiveValue: { (resp: ActivityAndProviderResponse) in
                // activity
                seatsLeft = resp.activity.seats_left
                startISO  = resp.activity.date_start
                endISO    = resp.activity.date_end
                // provider
                providerName    = resp.provider?.name ?? providerName
                providerAddress = resp.provider?.address
                providerCity    = resp.provider?.city
            }
            .store(in: &helper.bag)
    }

    private func checkEnrollment() {
        APIClient.shared.request("enrollments/mine",
                                 authorized: true,
                                 query: [URLQueryItem(name: "when", value: "all")])
            .sink { _ in } receiveValue: { (resp: ListResponse<EnrollmentItem>) in
                if let match = resp.items.first(where: { $0.activity_id == activity.id && $0.session_id == nil }) {
                    enrolled = true
                    enrollmentId = match.id
                } else {
                    enrolled = false
                    enrollmentId = nil
                }
            }
            .store(in: &helper.bag)
    }
}

// MARK: - Toolbar helper
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
        } else {
            content
        }
    }
}




















