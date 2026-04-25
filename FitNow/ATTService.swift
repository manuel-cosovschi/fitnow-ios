import AppTrackingTransparency
import AdSupport

// MARK: - ATTService

final class ATTService {
    static let shared = ATTService()
    private init() {}

    /// Request tracking authorization. Call after the first screen appears
    /// (Apple requires at least one UI cycle before showing the prompt).
    @discardableResult
    func requestTracking() async -> ATTrackingManager.AuthorizationStatus {
        await ATTrackingManager.requestTrackingAuthorization()
    }

    var isAuthorized: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    var idfa: String? {
        guard isAuthorized else { return nil }
        let id = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        return id == "00000000-0000-0000-0000-000000000000" ? nil : id
    }
}
