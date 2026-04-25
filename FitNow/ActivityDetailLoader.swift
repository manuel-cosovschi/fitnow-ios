import SwiftUI
import Combine

// Modelo “full” del /activities/:id con decoder tolerante para `rules`
fileprivate struct ActivityFull: Decodable {
    let id: Int
    let title: String
    let description: String?
    let modality: String?
    let difficulty: String?
    let location: String?
    let price: Double?
    let date_start: String?
    let date_end: String?
    let capacity: Int?
    let seats_left: Int?
    let kind: String?            // "trainer" | "gym" | "club"
    let provider_id: Int?
    let rules: String?           // <- guardamos como JSON string si viene objeto

    enum CodingKeys: String, CodingKey {
        case id, title, description, modality, difficulty, location, price
        case date_start, date_end, capacity, seats_left
        case kind, provider_id, rules
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(Int.self, forKey: .id)
        title       = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        modality    = try c.decodeIfPresent(String.self, forKey: .modality)
        difficulty  = try c.decodeIfPresent(String.self, forKey: .difficulty)
        location    = try c.decodeIfPresent(String.self, forKey: .location)

        if let p = try? c.decode(Double.self, forKey: .price) {
            price = p
        } else if let s = try? c.decode(String.self, forKey: .price),
                  let p = Double(s.replacingOccurrences(of: ",", with: ".")) {
            price = p
        } else { price = nil }

        date_start  = try c.decodeIfPresent(String.self, forKey: .date_start)
        date_end    = try c.decodeIfPresent(String.self, forKey: .date_end)
        capacity    = try c.decodeIfPresent(Int.self, forKey: .capacity)
        seats_left  = try c.decodeIfPresent(Int.self, forKey: .seats_left)
        kind        = try c.decodeIfPresent(String.self, forKey: .kind)
        provider_id = try c.decodeIfPresent(Int.self, forKey: .provider_id)

        if let r = try? c.decode(String.self, forKey: .rules) {
            rules = r
        } else if let any = try? c.decode(AnyDecodable.self, forKey: .rules) {
            rules = any.jsonString
        } else {
            rules = nil
        }
    }
}

// Helper para serializar “cualquier cosa” a JSON string
fileprivate struct AnyDecodable: Decodable {
    let value: Any
    var jsonString: String? {
        if JSONSerialization.isValidJSONObject(value) {
            return (try? JSONSerialization.data(withJSONObject: value))
                .flatMap { String(data: $0, encoding: .utf8) }
        } else {
            return (try? JSONSerialization.data(withJSONObject: [value]))
                .flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = NSNull() }
        else if let b = try? c.decode(Bool.self) { value = b }
        else if let i = try? c.decode(Int.self) { value = i }
        else if let d = try? c.decode(Double.self) { value = d }
        else if let s = try? c.decode(String.self) { value = s }
        else if let arr = try? c.decode([AnyDecodable].self) { value = arr.map { $0.value } }
        else if let dict = try? c.decode([String: AnyDecodable].self) { value = dict.mapValues { $0.value } }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON") }
    }
}

fileprivate struct ActivityFullResponse: Decodable { let activity: ActivityFull }

struct ActivityDetailLoader: View {
    let activityId: Int
    let title: String

    @State private var loading = true
    @State private var error: String?
    @State private var full: ActivityFull?
    @State private var bag = Set<AnyCancellable>()

    var body: some View {
        Group {
            if loading {
                ProgressView("Cargando…")
            } else if let e = error {
                VStack(spacing: 12) {
                    Text(e).foregroundColor(.red)
                    Button("Reintentar") { fetch() }
                }
            } else if let f = full {
                // Desde Actividades SIEMPRE vamos al detail (membresía).
                // El detail se encarga de mostrar sesiones solo como info para trainers.
                ActivityDetailView(
                    activity: toActivity(f),
                    previousTitle: "Actividades"   // fuerza flecha “Actividades”
                )
            }
        }
        .navigationTitle(title)
        .onAppear { if loading { fetch() } }
    }

    private func fetch() {
        loading = true; error = nil
        APIClient.shared.requestPublisher("activities/\(activityId)", authorized: false)
            .sink { completion in
                self.loading = false
                if case .failure(let e) = completion { self.error = e.localizedDescription }
            } receiveValue: { (resp: ActivityFullResponse) in
                self.full = resp.activity
            }
            .store(in: &bag)
    }

    // Adaptador al `Activity` de tu app (incluye `kind` y `rules`)
    private func toActivity(_ f: ActivityFull) -> Activity {
        struct A: Encodable {
            let id: Int, title: String
            let description: String?, modality: String?, difficulty: String?
            let location: String?, price: Double?
            let date_start: String?, date_end: String?
            let capacity: Int?, seats_left: Int?
            let kind: String?, provider_id: Int?, provider_name: String? = nil
            let rules: String?
        }
        let tmp = A(
            id: f.id, title: f.title,
            description: f.description, modality: f.modality, difficulty: f.difficulty,
            location: f.location, price: f.price,
            date_start: f.date_start, date_end: f.date_end,
            capacity: f.capacity, seats_left: f.seats_left,
            kind: f.kind, provider_id: f.provider_id,
            rules: f.rules
        )
        let data = try! JSONEncoder().encode(tmp)
        return try! JSONDecoder().decode(Activity.self, from: data)
    }
}








