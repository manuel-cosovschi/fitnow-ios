import Foundation
import WidgetKit

// MARK: - Shared widget data written to App Group UserDefaults
// The widget extension reads this via the same App Group identifier.

struct FNWidgetEntry: Codable {
    let level: Int
    let totalXP: Int
    let streakDays: Int
    let userName: String
    let updatedAt: Date
}

final class WidgetDataService {
    static let shared = WidgetDataService()

    private let appGroupID = "group.com.fitnow.app"
    private let entryKey   = "fn_widget_entry"

    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    private init() {}

    func write(level: Int, totalXP: Int, streakDays: Int, userName: String) {
        let entry = FNWidgetEntry(
            level: level,
            totalXP: totalXP,
            streakDays: streakDays,
            userName: userName,
            updatedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults?.set(data, forKey: entryKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func read() -> FNWidgetEntry? {
        guard let data = defaults?.data(forKey: entryKey) else { return nil }
        return try? JSONDecoder().decode(FNWidgetEntry.self, from: data)
    }
}
