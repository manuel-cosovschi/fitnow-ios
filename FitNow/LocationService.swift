import Foundation
import CoreLocation
import Combine

final class LocationService: NSObject, ObservableObject {

    static let shared = LocationService()

    private let manager = CLLocationManager()
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var status: CLAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5  // metros: reduce ruido/consumo
        manager.activityType = .fitness
        // Permite seguir registrando la corrida con la pantalla bloqueada o la
        // app en segundo plano (el modo "location" ya está declarado en el
        // Info.plist) y evita que iOS pause el GPS creyendo que estás quieto.
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
    }

    /// Arranca la captura de ubicación. Pide permiso si aún no se decidió.
    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            // Podés notificar a la UI si querés ofrecer abrir Settings
            break
        case .authorizedWhenInUse, .authorizedAlways, .authorized:
            manager.startUpdatingLocation()
        @unknown default:
            manager.startUpdatingLocation()
        }
    }

    // Deja de seguir tu ubicación.
    func stop() { manager.stopUpdatingLocation() }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {

    /// iOS 14+: método unificado
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
        }
    }

    /// Compat iOS 13 si mantenés target bajo (Xcode aún puede llamar esto)
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        self.status = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
        }
    }

    // Recibe las actualizaciones de ubicación del GPS.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            lastLocation = loc
        }
    }

    // Recibe las actualizaciones de ubicación del GPS.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }
}





