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

// ─── Rules Response ──────────────────────────────────────────────────────────

fileprivate struct ActivityRulesOnly: Decodable {
    let rules: String?
    private enum CodingKeys: String, CodingKey { case rules }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .rules) { rules = s }
        else if let any = try? c.decode(JSONAny.self, forKey: .rules) { rules = any.jsonString }
        else { rules = nil }
    }
}
fileprivate struct ActivityRulesResponse: Decodable { let activity: ActivityRulesOnly }

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - TrainerBookingsView
// ─────────────────────────────────────────────────────────────────────────────

struct TrainerBookingsView: View {
    let activityId: Int
    let title: String
    var previousTitle: String? = nil
    var supportsRunning: Bool = false

    @State private var sessions: [ActivitySession] = []
    @State private var myItems: [EnrollmentItem] = []
    @State private var perWeekLimit: Int = 0
    @State private var message: String?
    @State private var loading = true
    @State private var bag = Set<AnyCancellable>()
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Stats header
                statsHeader
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5).delay(0.05), value: appeared)

                // Running access
                if supportsRunning {
                    runningCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.10), value: appeared)
                }

                // Message
                if let msg = message {
                    messageCard(msg)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                // Sessions
                sessionsSection
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5).delay(0.15), value: appeared)
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(previousTitle != nil)
        .toolbar {
            if supportsRunning {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { RunPlannerView() } label: {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.fnCyan)
                    }
                }
            }
        }
        .onAppear {
            reloadAll()
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
    }

    // MARK: Stats Header

    private var statsHeader: some View {
        HStack(spacing: 12) {
            StatCard(
                value: "\(sessions.count)",
                label: "Clases disponibles",
                icon: "calendar.badge.clock",
                color: .fnPrimary
            )
            StatCard(
                value: "\(bookedThisWeek())",
                label: "Reservadas esta semana",
                icon: "checkmark.circle.fill",
                color: .fnGreen
            )
            if perWeekLimit > 0 {
                StatCard(
                    value: "\(perWeekLimit)",
                    label: "Límite semanal",
                    icon: "gauge.with.dots.needle.67percent",
                    color: .fnYellow
                )
            }
        }
    }

    // MARK: Running Card

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
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.fnCyan.opacity(0.2), lineWidth: 1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: Message Card

    private func messageCard(_ msg: String) -> some View {
        let isSuccess = msg.starts(with: "¡")
        return HStack(spacing: 10) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isSuccess ? .fnGreen : .fnSecondary)
            Text(msg)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSuccess ? .fnGreen : .fnSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill((isSuccess ? Color.fnGreen : Color.fnSecondary).opacity(0.10)))
    }

    // MARK: Sessions Section

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Próximas clases")

            if loading {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in SkeletonView(cornerRadius: 16).frame(height: 80) }
                }
            } else if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("Sin clases disponibles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            } else {
                ForEach(sessions) { s in
                    sessionCard(s)
                }
            }
        }
    }

    private func sessionCard(_ s: ActivitySession) -> some View {
        let booked = isBooked(s)
        let atLimit = perWeekLimit > 0 && bookedThisWeek() >= perWeekLimit && !booked

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(booked ? FNGradient.success : FNGradient.primary)
                    .frame(width: 44, height: 44)
                Image(systemName: booked ? "checkmark.circle.fill" : "clock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .fnShadowColored(booked ? .fnGreen : .fnPrimary, radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(pretty(s.start_at))
                    .font(.system(size: 14, weight: .bold))
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

            if booked {
                FitNowOutlineButton(title: "Cancelar", color: .fnSecondary, height: 38) {
                    cancel(s)
                }
                .frame(width: 100)
            } else {
                FitNowButton(title: "Reservar", gradient: FNGradient.primary,
                             isDisabled: atLimit, height: 38) {
                    book(s)
                }
                .frame(width: 100)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(booked ? Color.fnGreen.opacity(0.2) : Color(.separator).opacity(0.4), lineWidth: 1)
                )
        )
        .fnShadow(radius: 6, y: 2)
    }

    // MARK: - Data

    private func reloadAll() {
        loading = true
        APIClient.shared.request("activities/\(activityId)/sessions", authorized: false)
            .sink { _ in self.loading = false }
            receiveValue: { (resp: ListResponse<ActivitySession>) in self.sessions = resp.items; self.loading = false }
            .store(in: &bag)

        APIClient.shared.request("activities/\(activityId)", authorized: false)
            .sink { _ in }
            receiveValue: { (resp: ActivityRulesResponse) in
                if let rulesStr = resp.activity.rules,
                   let data = rulesStr.data(using: .utf8),
                   let any = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let sessions = any["sessions"] as? [String: Any],
                   let limit = sessions["per_week_limit"] as? Int {
                    self.perWeekLimit = limit
                } else { self.perWeekLimit = 0 }
            }
            .store(in: &bag)

        APIClient.shared.request("enrollments/mine", authorized: true,
                                 query: [URLQueryItem(name: "when", value: "all")])
            .sink { _ in }
            receiveValue: { (resp: ListResponse<EnrollmentItem>) in self.myItems = resp.items }
            .store(in: &bag)
    }

    private func isBooked(_ s: ActivitySession) -> Bool { myItems.contains { $0.session_id == s.id } }

    private func bookedThisWeek() -> Int {
        let cal = Calendar(identifier: .iso8601); let now = Date()
        let wNow = cal.component(.weekOfYear, from: now)
        let yNow = cal.component(.yearForWeekOfYear, from: now)
        func weekOf(_ iso: String?) -> (Int, Int)? {
            guard let iso = iso else { return nil }
            if let d = isoFrac.date(from: iso) ?? isoBasic.date(from: iso) ?? mysqlDF.date(from: iso) {
                return (cal.component(.weekOfYear, from: d), cal.component(.yearForWeekOfYear, from: d))
            }
            return nil
        }
        return myItems.filter { $0.activity_id == activityId }
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
                        if code == 409 && body.contains("Membership required") { self.message = "Primero tenés que inscribirte al entrenador."; return }
                        if code == 409 && body.contains("Weekly limit") { self.message = "Alcanzaste el límite semanal de reservas."; return }
                        if code == 409 && body.contains("Already enrolled") { self.message = "Ya reservaste esa clase."; return }
                        self.message = "HTTP \(code): \(body)"
                    } else { self.message = e.localizedDescription }
                }
            } receiveValue: { (_: SimpleOK) in
                withAnimation { self.message = "¡Reserva realizada!" }
                reloadAll()
            }
            .store(in: &bag)
    }

    private func cancel(_ s: ActivitySession) {
        message = nil
        APIClient.shared.request("sessions/\(s.id)/book", method: "DELETE", authorized: true)
            .sink { completion in
                if case .failure(let e) = completion { self.message = e.localizedDescription }
            } receiveValue: { (_: SimpleOK) in
                withAnimation { self.message = "Reserva cancelada." }
                reloadAll()
            }
            .store(in: &bag)
    }
}
