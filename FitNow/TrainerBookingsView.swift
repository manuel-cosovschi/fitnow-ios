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

// ---------- RESPUESTA SOLO RULES ----------
fileprivate struct ActivityRulesOnly: Decodable {
    let rules: String?
    private enum CodingKeys: String, CodingKey { case rules }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .rules) {
            rules = s
        } else if let any = try? c.decode(JSONAny.self, forKey: .rules) {
            rules = any.jsonString
        } else {
            rules = nil
        }
    }
}
fileprivate struct ActivityRulesResponse: Decodable { let activity: ActivityRulesOnly }

struct TrainerBookingsView: View {

    let activityId: Int
    let title: String
    var previousTitle: String? = nil

    /// NUEVO: indicá si este entrenador ofrece running para habilitar el acceso
    var supportsRunning: Bool = false

    @State private var sessions: [ActivitySession] = []
    @State private var myItems: [EnrollmentItem] = []
    @State private var perWeekLimit: Int = 0
    @State private var message: String?
    @State private var bag = Set<AnyCancellable>()

    var body: some View {
        List {
            if let msg = message { Section { Text(msg).foregroundColor(.red) } }

            if perWeekLimit > 0 {
                Section {
                    Text("Límite semanal: \(perWeekLimit). Reservas esta semana: \(bookedThisWeek()).")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }

            // ---- NUEVO: herramientas del entrenador
            if supportsRunning {
                Section(header: Text("Herramientas")) {
                    NavigationLink {
                        RunPlannerView()              // << sin parámetros
                    } label: {
                        Label("Rutas de running", systemImage: "figure.run.circle")
                    }
                }
            }

            Section(header: Text("Próximas clases")) {
                ForEach(sessions) { s in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(pretty(s.start_at)).bold()
                            Text(pretty(s.end_at)).font(.caption2).foregroundColor(.secondary)
                            if let lvl = s.level, !lvl.isEmpty {
                                Text("Nivel: \(lvl)").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if isBooked(s) {
                            Button("Cancelar") { cancel(s) }
                                .buttonStyle(.bordered).tint(.red)
                        } else {
                            Button("Reservar") { book(s) }
                                .buttonStyle(.borderedProminent)
                                .disabled(perWeekLimit > 0 && bookedThisWeek() >= perWeekLimit)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle(title)
        // Si algún día lo usás con previousTitle != nil, podrías agregar un toolbar custom.
        .navigationBarBackButtonHidden(previousTitle != nil)
        .toolbar {
            if supportsRunning {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        RunPlannerView()              // << sin parámetros
                    } label: {
                        Image(systemName: "figure.run.circle")
                            .accessibilityLabel("Rutas de running")
                    }
                }
            }
        }
        .onAppear { reloadAll() }
    }

    private func reloadAll() {
        APIClient.shared.request("activities/\(activityId)/sessions", authorized: false)
            .sink { _ in } receiveValue: { (resp: ListResponse<ActivitySession>) in
                self.sessions = resp.items
            }
            .store(in: &bag)

        APIClient.shared.request("activities/\(activityId)", authorized: false)
            .sink { _ in } receiveValue: { (resp: ActivityRulesResponse) in
                if let rulesStr = resp.activity.rules,
                   let data = rulesStr.data(using: .utf8),
                   let any = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let sessions = any["sessions"] as? [String: Any],
                   let limit = sessions["per_week_limit"] as? Int {
                    self.perWeekLimit = limit
                } else {
                    self.perWeekLimit = 0
                }
            }
            .store(in: &bag)

        APIClient.shared.request("enrollments/mine",
                                 authorized: true,
                                 query: [URLQueryItem(name: "when", value: "all")])
            .sink { _ in } receiveValue: { (resp: ListResponse<EnrollmentItem>) in
                self.myItems = resp.items
            }
            .store(in: &bag)
    }

    private func isBooked(_ s: ActivitySession) -> Bool {
        myItems.contains { $0.session_id == s.id }
    }

    private func bookedThisWeek() -> Int {
        let cal = Calendar(identifier: .iso8601)
        let now = Date()
        let wNow = cal.component(.weekOfYear, from: now)
        let yNow = cal.component(.yearForWeekOfYear, from: now)

        func weekOf(_ iso: String?) -> (Int, Int)? {
            guard let iso = iso else { return nil }
            if let d = isoFrac.date(from: iso) ?? isoBasic.date(from: iso) ?? mysqlDF.date(from: iso) {
                return (cal.component(.weekOfYear, from: d),
                        cal.component(.yearForWeekOfYear, from: d))
            }
            return nil
        }

        return myItems
            .filter { $0.activity_id == activityId }
            .compactMap { weekOf($0.date_start) }
            .filter { $0.0 == wNow && $0.1 == yNow }
            .count
    }

    private func book(_ s: ActivitySession) {
        message = nil
        APIClient.shared.request("sessions/\(s.id)/book", method: "POST", authorized: true)
            .sink { completion in
                if case .failure(let e) = completion {
                    if case APIError.http(let code, let body) = e {
                        if code == 409 && body.contains("Membership required") {
                            message = "Primero tenés que inscribirte al entrenador."; return
                        }
                        if code == 409 && body.contains("Weekly limit") {
                            message = "Alcanzaste el límite semanal de reservas."; return
                        }
                        if code == 409 && body.contains("Already enrolled") {
                            message = "Ya reservaste esa clase."; return
                        }
                        message = "HTTP \(code): \(body)"
                    } else { message = e.localizedDescription }
                }
            } receiveValue: { (_: SimpleOK) in
                message = "¡Reserva realizada!"
                reloadAll()
            }
            .store(in: &bag)
    }

    private func cancel(_ s: ActivitySession) {
        message = nil
        APIClient.shared.request("sessions/\(s.id)/book", method: "DELETE", authorized: true)
            .sink { completion in
                if case .failure(let e) = completion { message = e.localizedDescription }
            } receiveValue: { (_: SimpleOK) in
                message = "Reserva cancelada."
                reloadAll()
            }
            .store(in: &bag)
    }
}










