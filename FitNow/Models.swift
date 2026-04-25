import Foundation

// MARK: - User / Auth
struct User: Codable {
    let id: Int
    let name: String
    let email: String
    let role: String?
    let provider_id: Int?
}
struct AuthResponse: Codable {
    let user: User
    let token: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case user, token
        case refreshToken = "refresh_token"
    }
}

// Returned by login when 2FA is required
struct TwoFactorChallenge: Decodable {
    let requiresTwoFactor: Bool
    let tempToken: String

    enum CodingKeys: String, CodingKey {
        case requiresTwoFactor = "requires_two_factor"
        case tempToken = "temp_token"
    }
}

// Flexible login response: either full auth OR 2FA challenge
struct LoginFlexResponse: Decodable {
    let token: String?
    let refreshToken: String?
    let user: User?
    let requiresTwoFactor: Bool?
    let tempToken: String?

    enum CodingKeys: String, CodingKey {
        case token, user
        case refreshToken      = "refresh_token"
        case requiresTwoFactor = "requires_two_factor"
        case tempToken         = "temp_token"
    }
}

// MARK: - Provider
struct Provider: Identifiable, Codable {
    let id: Int
    let name: String
    let kind: String?
    let description: String?
    let address: String?
    let city: String?
    let phone: String?
    let website_url: String?
    let logo_url: String?
    let status: String?
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

    // Provider-configurable feature flags
    let enable_running: Bool?      // provider enables running routes for this service
    let enable_deposit: Bool?      // provider allows deposit (seña) payment
    let deposit_percent: Int?      // deposit percentage (default 50 if nil)
    let has_capacity_limit: Bool?  // provider enforces seat limit
    let status: String?            // "draft" | "active" | "cancelled"
    let lat: Double?
    let lng: Double?
    let rating: Double?            // average rating (0-5)
    let review_count: Int?
    let image_urls: [String]?
    let cancellation_policy: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, modality, difficulty, location, price
        case date_start, date_end, capacity, seats_left
        case kind, provider_id, provider_name, rules
        case sport_id, sport_name
        case enable_running, enable_deposit, deposit_percent, has_capacity_limit, status
        case lat, lng, rating, review_count
        case image_urls, cancellation_policy
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

        enable_running      = try c.decodeIfPresent(Bool.self,   forKey: .enable_running)
        enable_deposit      = try c.decodeIfPresent(Bool.self,   forKey: .enable_deposit)
        deposit_percent     = try c.decodeIfPresent(Int.self,    forKey: .deposit_percent)
        has_capacity_limit  = try c.decodeIfPresent(Bool.self,   forKey: .has_capacity_limit)
        status              = try c.decodeIfPresent(String.self, forKey: .status)
        lat                 = try c.decodeIfPresent(Double.self,   forKey: .lat)
        lng                 = try c.decodeIfPresent(Double.self,   forKey: .lng)
        rating              = try c.decodeIfPresent(Double.self,   forKey: .rating)
        review_count        = try c.decodeIfPresent(Int.self,      forKey: .review_count)
        image_urls          = try c.decodeIfPresent([String].self,  forKey: .image_urls)
        cancellation_policy = try c.decodeIfPresent(String.self,   forKey: .cancellation_policy)
    }
}

// MARK: - Review

struct ActivityReview: Identifiable, Decodable {
    let id: Int
    let user_name: String
    let rating: Int          // 1-5
    let comment: String?
    let created_at: String?
}

struct ReviewsResponse: Decodable {
    let items: [ActivityReview]
    let total: Int?
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
struct PagedPagination: Decodable {
    let total: Int
    let page: Int
    let per_page: Int
    let pages: Int
}
struct Paged<T: Decodable>: Decodable {
    let items: [T]
    let pagination: PagedPagination?
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
    let plan_name: String?      // plan chosen at enrollment (e.g. "Trimestral")
    let plan_price: Double?     // price of the chosen plan
    let status: String?         // "active", "cancelled", "pending"

    enum CodingKeys: String, CodingKey {
        case id, activity_id, session_id, activity_kind, provider_id
        case title, location, date_start, date_end
        case price = "price_paid"
        case plan_name, plan_price, status
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
        plan_name = try c.decodeIfPresent(String.self, forKey: .plan_name)
        if let p = try? c.decode(Double.self, forKey: .plan_price) {
            plan_price = p
        } else if let s = try? c.decode(String.self, forKey: .plan_price),
                  let p = Double(s.replacingOccurrences(of: ",", with: ".")) {
            plan_price = p
        } else { plan_price = nil }
        status = try c.decodeIfPresent(String.self, forKey: .status)
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

// MARK: - Special Offers
struct SpecialOffer: Identifiable, Codable {
    let id: Int
    let title: String
    let description: String?
    let discount_label: String      // e.g. "2×1", "20% OFF", "-$500"
    let activity_kind: String?      // nil = applies to all kinds
    let provider_id: Int?
    let provider_name: String?
    let status: String              // "pending", "approved", "rejected"
    let valid_until: String?
    let created_at: String?
    let icon_name: String?          // SF Symbol name
}
struct OffersListResponse: Decodable { let items: [SpecialOffer] }

// MARK: - Admin
struct AdminStats: Decodable {
    let total_users: Int?
    let total_providers: Int?
    let total_activities: Int?
    let total_enrollments: Int?
    let pending_offers: Int?
    let total_revenue: Double?
}
struct AdminProviderItem: Identifiable, Decodable {
    let id: Int
    let name: String
    let email: String?
    let kind: String?
    let status: String?
    let activity_count: Int?
    let created_at: String?
}
struct AdminUserItem: Identifiable, Decodable {
    let id: Int
    let name: String
    let email: String
    let role: String?
    let is_banned: Bool?
    let created_at: String?
}



// MARK: - M3: Payment Methods & MercadoPago

struct SavedPaymentMethod: Identifiable, Decodable {
    let id: Int
    let provider: String          // "stripe" | "mercadopago"
    let brand: String?            // "visa", "mastercard", etc.
    let last4: String?
    let expiryMonth: Int?
    let expiryYear: Int?
    let holderName: String?
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id, provider, brand, last4, holderName = "holder_name"
        case expiryMonth = "expiry_month", expiryYear = "expiry_year"
        case isDefault = "is_default"
    }
}

struct MercadoPagoPreference: Decodable {
    let preferenceId: String
    let initPoint: String        // URL to open in browser/WebView
    let enrollmentId: Int

    enum CodingKeys: String, CodingKey {
        case preferenceId = "preference_id"
        case initPoint    = "init_point"
        case enrollmentId = "enrollment_id"
    }
}

struct RefundRequest: Decodable {
    let id: Int
    let enrollmentId: Int
    let status: String           // "pending" | "approved" | "rejected"
    let amount: Double?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case id, status, amount, reason
        case enrollmentId = "enrollment_id"
    }
}
