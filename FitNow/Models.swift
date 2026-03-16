import Foundation

// MARK: - User / Auth
struct User: Codable {
    let id: Int
    let name: String
    let email: String
    let role: String?
}
struct AuthResponse: Codable {
    let user: User
    let token: String
}

// MARK: - Activity
struct Activity: Identifiable, Codable {
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

    let kind: String?
    let provider_id: Int?
    let provider_name: String?

    // NUEVO
    let sport_id: Int?
    let sport_name: String?

    let rules: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, modality, difficulty, location, price
        case date_start, date_end, capacity, seats_left
        case kind, provider_id, provider_name, rules
        case sport_id, sport_name
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        modality = try c.decodeIfPresent(String.self, forKey: .modality)
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        if let p = try? c.decode(Double.self, forKey: .price) {
            price = p
        } else if let s = try? c.decode(String.self, forKey: .price),
                  let p = Double(s.replacingOccurrences(of: ",", with: ".")) {
            price = p
        } else { price = nil }
        date_start = try c.decodeIfPresent(String.self, forKey: .date_start)
        date_end   = try c.decodeIfPresent(String.self, forKey: .date_end)
        capacity   = try c.decodeIfPresent(Int.self, forKey: .capacity)
        seats_left = try c.decodeIfPresent(Int.self, forKey: .seats_left)
        kind          = try c.decodeIfPresent(String.self, forKey: .kind)
        provider_id   = try c.decodeIfPresent(Int.self, forKey: .provider_id)
        provider_name = try c.decodeIfPresent(String.self, forKey: .provider_name)

        sport_id   = try c.decodeIfPresent(Int.self, forKey: .sport_id)
        sport_name = try c.decodeIfPresent(String.self, forKey: .sport_name)

        if let r = try? c.decode(String.self, forKey: .rules) {
            rules = r
        } else if let any = try? c.decode(JSONAny.self, forKey: .rules) {
            rules = any.jsonString
        } else { rules = nil }
    }
}


// Pequeño helper para decodificar “cualquier JSON” y volver a string
struct JSONAny: Decodable {
    let value: Any
    var jsonString: String? {
        guard JSONSerialization.isValidJSONObject(value) else {
            // para valores escalares
            return try? String(data: JSONSerialization.data(withJSONObject: [value], options: []), encoding: .utf8)
        }
        return try? String(data: JSONSerialization.data(withJSONObject: value, options: []), encoding: .utf8)
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self.value = NSNull()
        } else if let b = try? c.decode(Bool.self) {
            self.value = b
        } else if let i = try? c.decode(Int.self) {
            self.value = i
        } else if let d = try? c.decode(Double.self) {
            self.value = d
        } else if let s = try? c.decode(String.self) {
            self.value = s
        } else if let arr = try? c.decode([JSONAny].self) {
            self.value = arr.map { $0.value }
        } else if let dict = try? c.decode([String: JSONAny].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON")
        }
    }
}

// MARK: - Generic responses
struct Paged<T: Decodable>: Decodable {
    let items: [T]
    let limit: Int?
    let offset: Int?
}
struct SimpleOK: Codable { let status: String }
struct ListResponse<T: Decodable>: Decodable { let items: [T] }

// MARK: - Enrollments
struct EnrollmentItem: Identifiable, Decodable {
    let id: Int
    let activity_id: Int?
    let session_id: Int?
    let activity_kind: String?
    let provider_id: Int?
    let title: String
    let location: String?
    let date_start: String?
    let date_end: String?
    let price: Double?          // backend returns this as "price_paid"

    enum CodingKeys: String, CodingKey {
        case id, activity_id, session_id, activity_kind, provider_id
        case title, location, date_start, date_end
        case price = "price_paid"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(Int.self, forKey: .id)
        activity_id  = try c.decodeIfPresent(Int.self, forKey: .activity_id)
        session_id   = try c.decodeIfPresent(Int.self, forKey: .session_id)
        activity_kind = try c.decodeIfPresent(String.self, forKey: .activity_kind)
        provider_id  = try c.decodeIfPresent(Int.self, forKey: .provider_id)
        title        = try c.decode(String.self, forKey: .title)
        location     = try c.decodeIfPresent(String.self, forKey: .location)
        date_start   = try c.decodeIfPresent(String.self, forKey: .date_start)
        date_end     = try c.decodeIfPresent(String.self, forKey: .date_end)
        if let p = try? c.decode(Double.self, forKey: .price) {
            price = p
        } else if let s = try? c.decode(String.self, forKey: .price),
                  let p = Double(s.replacingOccurrences(of: ",", with: ".")) {
            price = p
        } else { price = nil }
    }
}


// MARK: - Activity detail wrapper
struct ActivityResponse: Decodable { let activity: Activity }

// MARK: - Sessions (trainer)
struct ActivitySession: Identifiable, Decodable {
    let id: Int
    let activity_id: Int
    let start_at: String
    let end_at: String
    let price: Double?
    let seats_left: Int
    let level: String?
}


