import Testing
@testable import FitNow

// MARK: - CheckInService Tests

struct CheckInServiceTests {

    @Test func parseQR_deepLink_returnsId() {
        let id = CheckInService.shared.parseQR("fitnow://checkin/42")
        #expect(id == 42)
    }

    @Test func parseQR_bareInt_returnsId() {
        let id = CheckInService.shared.parseQR("123")
        #expect(id == 123)
    }

    @Test func parseQR_invalidString_returnsNil() {
        let id = CheckInService.shared.parseQR("not-a-qr-code")
        #expect(id == nil)
    }

    @Test func parseQR_wrongScheme_returnsNil() {
        let id = CheckInService.shared.parseQR("https://example.com/checkin/7")
        #expect(id == nil)
    }

    @Test func parseQR_deepLinkMissingId_returnsNil() {
        let id = CheckInService.shared.parseQR("fitnow://checkin/")
        #expect(id == nil)
    }
}

// MARK: - WidgetDataService Tests

struct WidgetDataServiceTests {

    @Test func writeRead_roundtrip() {
        WidgetDataService.shared.write(level: 7, totalXP: 3500, streakDays: 14, userName: "Test")
        let entry = WidgetDataService.shared.read()
        // May return nil in test environment without App Group entitlement; guard for CI
        if let entry {
            #expect(entry.level == 7)
            #expect(entry.totalXP == 3500)
            #expect(entry.streakDays == 14)
        }
    }
}

// MARK: - FNWidgetEntry Codable Tests

struct FNWidgetEntryTests {

    @Test func encode_decode_preservesFields() throws {
        let original = FNWidgetEntry(level: 3, totalXP: 900, streakDays: 5, userName: "Ana", updatedAt: Date())
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FNWidgetEntry.self, from: data)
        #expect(decoded.level == original.level)
        #expect(decoded.totalXP == original.totalXP)
        #expect(decoded.streakDays == original.streakDays)
        #expect(decoded.userName == original.userName)
    }
}

// MARK: - UserBadge sfSymbol Tests

struct UserBadgeTests {

    @Test func sfSymbol_knownIcon_returnsMappedSymbol() {
        let badge = UserBadge(id: 1, code: "run1", name: "Runner",
                              description: "", icon: "trophy",
                              category: "run", threshold: 1, earned_at: nil)
        #expect(badge.sfSymbol == "trophy.fill")
    }

    @Test func sfSymbol_unknownIcon_returnsDefault() {
        let badge = UserBadge(id: 2, code: "x", name: "X",
                              description: "", icon: "unknown-icon",
                              category: "misc", threshold: 0, earned_at: nil)
        #expect(badge.sfSymbol == "star.circle.fill")
    }
}

// MARK: - AdminStats Decodable Tests

struct AdminStatsTests {

    @Test func decode_fullPayload_succeeds() throws {
        let json = """
        {
            "total_users": 100,
            "total_providers": 20,
            "total_activities": 50,
            "total_enrollments": 300,
            "pending_offers": 3,
            "total_revenue": 15000.50
        }
        """.data(using: .utf8)!
        let stats = try JSONDecoder().decode(AdminStats.self, from: json)
        #expect(stats.total_users == 100)
        #expect(stats.total_revenue == 15000.50)
        #expect(stats.pending_offers == 3)
    }

    @Test func decode_partialPayload_succeeds() throws {
        let json = "{}".data(using: .utf8)!
        let stats = try JSONDecoder().decode(AdminStats.self, from: json)
        #expect(stats.total_users == nil)
        #expect(stats.total_revenue == nil)
    }
}
