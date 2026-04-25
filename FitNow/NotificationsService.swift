import Foundation
import UserNotifications

final class NotificationsService {
    static let shared = NotificationsService()
    private init() {}

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    // MARK: - APNs device token

    func registerDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        Task {
            struct Payload: Encodable { let token: String; let platform = "ios" }
            guard let body = try? JSONEncoder().encode(Payload(token: token)) else { return }
            let _: SimpleOK? = try? await APIClient.shared.request(
                "users/me/push-token", method: "POST", body: body, authorized: true
            )
        }
    }

    func unregisterDeviceToken() {
        Task {
            let _: SimpleOK? = try? await APIClient.shared.request(
                "users/me/push-token", method: "DELETE", authorized: true
            )
        }
    }

    // MARK: - Schedule reminders for an enrolled activity

    /// Call after a successful enrollment to schedule 24h and 1h reminders.
    func scheduleReminders(activityTitle: String, activityId: Int, dateStart: String?) {
        guard let dateStr = dateStart, let start = parseISO(dateStr) else { return }

        let oneDayBefore  = start.addingTimeInterval(-86_400)
        let oneHourBefore = start.addingTimeInterval(-3_600)
        let now = Date()

        if oneDayBefore > now {
            schedule(
                identifier: "fn-24h-\(activityId)",
                title: "Mañana: \(activityTitle)",
                body: "No olvides prepararte para tu actividad de mañana.",
                date: oneDayBefore
            )
        }
        if oneHourBefore > now {
            schedule(
                identifier: "fn-1h-\(activityId)",
                title: activityTitle,
                body: "Tu actividad empieza en 1 hora. ¡Prepárate!",
                date: oneHourBefore
            )
        }
    }

    /// Cancel reminders for a cancelled enrollment.
    func cancelReminders(activityId: Int) {
        let ids = ["fn-24h-\(activityId)", "fn-1h-\(activityId)"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Private helpers

    private func schedule(identifier: String, title: String, body: String, date: Date) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body  = body
            content.sound = .default

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }

    private func parseISO(_ s: String) -> Date? {
        let fracF  = ISO8601DateFormatter()
        fracF.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fracF.date(from: s) { return d }

        let basicF = ISO8601DateFormatter()
        basicF.formatOptions = [.withInternetDateTime]
        if let d = basicF.date(from: s) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df.date(from: s)
    }
}
