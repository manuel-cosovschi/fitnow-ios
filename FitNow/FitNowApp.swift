import SwiftUI

@main
struct FitNowApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                // Iniciamos la ubicación al abrir la app (pide permiso si falta)
                .onAppear { LocationService.shared.start() }
        }
    }
}


