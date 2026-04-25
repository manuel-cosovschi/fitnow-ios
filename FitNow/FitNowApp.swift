import SwiftUI
import UserNotifications

@main
struct FitNowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth      = AuthViewModel()
    @State private var biometric       = BiometricService()
    @State private var deepLinkHandler = DeepLinkHandler.shared

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environment(biometric)
                .onAppear {
                    LocationService.shared.start()
                    registerForPushNotifications()
                }
                .onOpenURL { url in
                    handleURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypes.browsingWeb) { activity in
                    if let url = activity.webpageURL { handleURL(url) }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                biometric.handleBackground()
            case .active:
                biometric.handleForeground()
            default:
                break
            }
        }
    }

    // MARK: - APNs registration

    private func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Deep link dispatch

    private func handleURL(_ url: URL) {
        guard let link = DeepLink.from(url: url) else { return }
        switch link {
        case .verifyEmail(let token):
            Task { await DeepLinkHandler.shared.verifyEmail(token: token) }
        case .magicLink(let token):
            Task { await DeepLinkHandler.shared.handleMagicLink(token: token, auth: auth) }
        default:
            DeepLinkHandler.shared.handle(url: url)
        }
    }
}

// Required for onContinueUserActivity
private enum NSUserActivityTypes {
    static let browsingWeb = "NSUserActivityTypeBrowsingWeb"
}

// MARK: - AppDelegate for APNs callbacks

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationsService.shared.registerDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Ignore — APNs unavailable on simulator
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let urlStr = info["deep_link"] as? String, let url = URL(string: urlStr) {
            DeepLinkHandler.shared.handle(url: url)
        }
        completionHandler()
    }
}
