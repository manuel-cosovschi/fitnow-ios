import SwiftUI
import Combine

// Fallback: deportes típicos para completar hasta 5
fileprivate let typicalClubSports = ["Fútbol", "Tenis", "Natación", "Básquet", "Hockey"]

fileprivate struct Sport: Identifiable, Decodable { let id: Int; let name: String }
fileprivate struct SportsResponse: Decodable { let items: [Sport] }

fileprivate func uniquePrefix(_ arr: [String], max: Int) -> [String] {
    var seen = Set<String>(); var out: [String] = []
    for s in arr where !s.trimmingCharacters(in: .whitespaces).isEmpty {
        if !seen.contains(s) {
            seen.insert(s); out.append(s)
            if out.count == max { break }
        }
    }
    return out
}

// Item para la lista inferior (actividad real o “placeholder” por deporte)
fileprivate struct ClubItem: Identifiable {
    let id: String
    let sportName: String
    let title: String
    let location: String?
    let activityId: Int? // nil = aún no disponible (placeholder)
}

struct ClubSportsView: View {
    @Environment(\.dismiss) private var dismiss
    let providerId: Int
    let clubTitle: String

    @State private var sportsFetched: [String] = []
    @State private var allSports: [String] = []         // hasta 5 (fetch + fallback)
    @State private var activities: [Activity] = []      // club_sport del club
    @State private var myItems: [EnrollmentItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var bag = Set<AnyCancellable>()

    // Construye 1 fila por deporte (actividad real si existe; si no, placeholder)
    private var clubItems: [ClubItem] {
        let sports = allSports.isEmpty ? typicalClubSports : allSports
        return sports.map { sport in
            // Busca la primera actividad que matchee el deporte
            if let a = activities.first(where: {
                ($0.sport_name ?? "").localizedCaseInsensitiveContains(sport)
            }) {
                return ClubItem(
                    id: "a-\(a.id)",
                    sportName: sport,
                    title: a.title,
                    location: a.location,
                    activityId: a.id
                )
            } else {
                // Placeholder (sin actividad aún)
                return ClubItem(
                    id: "p-\(sport)",
                    sportName: sport,
                    title: sport,           // mostramos el nombre del deporte
                    location: nil,
                    activityId: nil
                )
            }
        }
    }

    var body: some View {
        List {
            if let e = error {
                Section { Text(e).foregroundColor(.red) }
            }

            // Arriba: SIEMPRE hasta 5 deportes (fetch + fallback)
            if !allSports.isEmpty {
                Section(header: Text("Deportes disponibles")) {
                    ForEach(allSports, id: \.self) { name in
                        Text(name).font(.subheadline)
                    }
                }
            }

            // Abajo: 1 card por cada deporte (real o placeholder)
            Section(header: Text("Actividades del club")) {
                ForEach(clubItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).bold()
                            Text(item.sportName).font(.caption).foregroundColor(.secondary)
                            if let loc = item.location {
                                Text(loc).font(.caption2).foregroundColor(.secondary)
                            }
                            if item.activityId == nil {
                                Text("Próximamente").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if let aid = item.activityId {
                            if isEnrolled(aid) {
                                Button("Cancelar") { cancel(activityId: aid) }
                                    .buttonStyle(.bordered).tint(.red)
                            } else {
                                Button("Inscribirme") { enroll(activityId: aid) }
                                    .buttonStyle(.borderedProminent)
                            }
                        } else {
                            Button("Inscribirme") {}
                                .buttonStyle(.borderedProminent)
                                .disabled(true)
                                .opacity(0.4)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle(clubTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Label("Actividades", systemImage: "chevron.left").labelStyle(.titleAndIcon)
                }
            }
        }
        .onAppear { reloadAll() }
    }

    private func reloadAll() {
        loading = true; error = nil

        // 1) Deportes del club
        APIClient.shared.request("providers/\(providerId)/sports", authorized: false)
            .sink { completion in
                // Si falla o viene vacío, usamos fallback
                if case .failure = completion, self.allSports.isEmpty {
                    self.allSports = typicalClubSports
                }
            } receiveValue: { (resp: SportsResponse) in
                let names = resp.items.map { $0.name }
                self.sportsFetched = names
                self.allSports = uniquePrefix(names + typicalClubSports, max: 5)
            }
            .store(in: &bag)

        // 2) Actividades club_sport del club
        let q: [URLQueryItem] = [
            .init(name: "provider_id", value: String(providerId)),
            .init(name: "kind", value: "club_sport"),
            .init(name: "include_sports", value: "1")
        ]
        APIClient.shared.request("activities", authorized: false, query: q)
            .sink { completion in
                if case .failure(let e) = completion { self.error = e.localizedDescription }
            } receiveValue: { (resp: Paged<Activity>) in
                // Si hay duplicadas por deporte, nos quedamos con la primera
                var seen = Set<String>()
                self.activities = resp.items.filter { a in
                    let key = (a.sport_name ?? a.title).lowercased()
                    if seen.contains(key) { return false }
                    seen.insert(key); return true
                }
            }
            .store(in: &bag)

        // 3) Mis inscripciones
        APIClient.shared.request("enrollments/mine", authorized: true,
                                 query: [URLQueryItem(name: "when", value: "all")])
            .sink { _ in } receiveValue: { (resp: ListResponse<EnrollmentItem>) in
                self.myItems = resp.items
                self.loading = false
            }
            .store(in: &bag)
    }

    private func isEnrolled(_ activityId: Int) -> Bool {
        myItems.contains { $0.activity_id == activityId && $0.session_id == nil }
    }

    private func enroll(activityId: Int) {
        APIClient.shared.request("enrollments", method: "POST",
                                 body: try? JSONEncoder().encode(["activity_id": activityId]),
                                 authorized: true)
            .sink { completion in
                if case .failure(let e) = completion { self.error = e.localizedDescription }
            } receiveValue: { (_: SimpleOK) in
                reloadAll()
            }
            .store(in: &bag)
    }

    private func cancel(activityId: Int) {
        guard let eid = myItems.first(where: { $0.activity_id == activityId && $0.session_id == nil })?.id else { return }
        APIClient.shared.request("enrollments/\(eid)", method: "DELETE", authorized: true)
            .sink { completion in
                if case .failure(let e) = completion { self.error = e.localizedDescription }
            } receiveValue: { (_: SimpleOK) in
                reloadAll()
            }
            .store(in: &bag)
    }
}




