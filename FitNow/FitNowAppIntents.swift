import AppIntents
import SwiftUI

// MARK: - App Intents (iOS 16+)
// Siri & Shortcuts integration. All intents open the app and deep-link to the
// relevant feature via @AppStorage / Notification.

// MARK: CheckStreakIntent

struct CheckStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Ver mi racha en FitNow"
    static var description = IntentDescription("Muestra tu racha de entrenamiento actual.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let entry = WidgetDataService.shared.read()
        let streak = entry?.streakDays ?? 0
        let message = streak > 0
            ? "\(streak) día\(streak == 1 ? "" : "s") de racha consecutiva. ¡Seguí así!"
            : "Todavía no tenés racha activa. ¡Entrená hoy para empezar!"
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: CheckLevelIntent

struct CheckLevelIntent: AppIntent {
    static var title: LocalizedStringResource = "Ver mi nivel en FitNow"
    static var description = IntentDescription("Muestra tu nivel y XP actual.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let entry = WidgetDataService.shared.read()
        guard let entry else {
            let msg = "Abrí FitNow para sincronizar tu perfil."
            return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
        }
        let msg = "Estás en el nivel \(entry.level) con \(entry.totalXP) XP totales."
        return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
    }
}

// MARK: StartRunIntent

struct StartRunIntent: AppIntent {
    static var title: LocalizedStringResource = "Iniciar una carrera en FitNow"
    static var description = IntentDescription("Abre FitNow en el planificador de rutas.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .fnOpenRunPlanner, object: nil)
        }
        return .result()
    }
}

// MARK: StartGymIntent

struct StartGymIntent: AppIntent {
    static var title: LocalizedStringResource = "Iniciar sesión de gym en FitNow"
    static var description = IntentDescription("Abre FitNow en el asistente de entrenamiento.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .fnOpenGym, object: nil)
        }
        return .result()
    }
}

// MARK: - Notification names for deep-link dispatch

extension Notification.Name {
    static let fnOpenRunPlanner = Notification.Name("fn.openRunPlanner")
    static let fnOpenGym        = Notification.Name("fn.openGym")
}

// MARK: - FitNow App Shortcuts (Siri Phrases)

struct FitNowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckStreakIntent(),
            phrases: [
                "¿Cuál es mi racha en \(.applicationName)?",
                "Ver mi racha en \(.applicationName)"
            ],
            shortTitle: "Mi racha",
            systemImageName: "flame.fill"
        )
        AppShortcut(
            intent: CheckLevelIntent(),
            phrases: [
                "¿Qué nivel tengo en \(.applicationName)?",
                "Ver mi nivel en \(.applicationName)"
            ],
            shortTitle: "Mi nivel",
            systemImageName: "star.fill"
        )
        AppShortcut(
            intent: StartRunIntent(),
            phrases: [
                "Quiero correr con \(.applicationName)",
                "Iniciar carrera en \(.applicationName)"
            ],
            shortTitle: "Correr",
            systemImageName: "figure.run"
        )
        AppShortcut(
            intent: StartGymIntent(),
            phrases: [
                "Ir al gym con \(.applicationName)",
                "Iniciar gym en \(.applicationName)"
            ],
            shortTitle: "Gym",
            systemImageName: "dumbbell.fill"
        )
    }
}
