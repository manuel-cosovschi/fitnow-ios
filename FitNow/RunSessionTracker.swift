// RunSessionTracker.swift
// Tracks an active running session: starts a server-side session, flushes
// GPS telemetry in batches, and finalises/abandons on request.
import Foundation
import CoreLocation
import Combine

// Decodable wrapper for the session object returned by POST /run/sessions
private struct RunSessionCreated: Decodable { let id: Int }

// Decodable wrapper for POST /run/sessions/:id/points → { saved: N }
private struct TelemetrySaved: Decodable { let saved: Int }

@MainActor
final class RunSessionTracker: ObservableObject {

    // MARK: - Published state
    @Published private(set) var sessionId: Int?
    @Published private(set) var totalDistanceM: CLLocationDistance = 0
    /// Post-run AI analysis, fetched after the run is finalised.
    @Published private(set) var analysis: RunAnalysis?
    @Published private(set) var analyzing = false

    // MARK: - Private state
    private var pendingPoints: [[String: Any]] = []
    private var bag = Set<AnyCancellable>()
    private var startedAt: Date?
    private var lastLocation: CLLocation?
    // Guardados de start(): permiten recrear la sesión al finalizar si el POST
    // inicial falló (p. ej. la base estaba caída), así el análisis igual funciona.
    private var startRouteId: Int?
    private var startOriginLat: Double = 0
    private var startOriginLng: Double = 0

    /// Flush when this many points have accumulated
    private let flushThreshold = 10

    // MARK: - API

    /// Call once when navigation begins. `routeId` is nil when a generated
    /// route has no DB id (e.g. client-side AI routes).
    func start(routeId: Int?, originLat: Double, originLng: Double) {
        guard sessionId == nil else { return }
        startedAt = Date()
        totalDistanceM = 0
        lastLocation = nil
        startRouteId   = routeId
        startOriginLat = originLat
        startOriginLng = originLng

        var body: [String: Any] = [
            "origin_lat": originLat,
            "origin_lng": originLng,
        ]
        if let rid = routeId { body["route_id"] = rid }

        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }

        APIClient.shared.requestPublisher("run/sessions",
                                 method: "POST",
                                 body: data,
                                 authorized: true)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] (resp: RunSessionCreated) in
                    self?.sessionId = resp.id
                }
            )
            .store(in: &bag)
    }

    /// Call on every GPS update from the location manager.
    func addPoint(_ location: CLLocation) {
        // Filtro anti-ruido de GPS: parado en un escritorio el GPS "salta" unos
        // metros entre lecturas, y sin filtrar eso se sumaría como distancia real.
        // 1) Descartamos lecturas imprecisas.
        guard location.horizontalAccuracy > 0, location.horizontalAccuracy <= 25 else { return }

        // 2) El chip del GPS reporta la velocidad real (por efecto Doppler):
        //    parado da ~0, así que exigimos velocidad de caminata o más.
        //    (< 0 significa "desconocida": en ese caso no bloqueamos por esto.)
        guard location.speed < 0 || location.speed >= 0.7 else { return }

        if let prev = lastLocation {
            let step = location.distance(from: prev)
            let dt   = location.timestamp.timeIntervalSince(prev.timestamp)
            guard dt > 0 else { return }
            // 3) El paso tiene que ser coherente: ni ruido chico (< 8 m), ni un
            //    "teletransporte" imposible, ni un drift lento acumulado.
            let speed = step / dt
            guard step >= 8, speed >= 0.7, speed <= 12 else { return }
            totalDistanceM += step
        }
        lastLocation = location

        var point: [String: Any] = [
            "ts_ms": Int(location.timestamp.timeIntervalSince1970 * 1000),
            "lat":   location.coordinate.latitude,
            "lng":   location.coordinate.longitude,
        ]
        if location.altitude != 0      { point["elevation_m"] = location.altitude }
        if location.speed > 0          { point["speed_mps"]   = location.speed    }
        if location.horizontalAccuracy > 0 { point["accuracy_m"] = location.horizontalAccuracy }

        pendingPoints.append(point)
        if pendingPoints.count >= flushThreshold { flush() }
    }

    /// Push accumulated points to the server. Safe to call with 0 points.
    func flush() {
        guard let sid = sessionId, !pendingPoints.isEmpty else { return }
        let batch = pendingPoints
        pendingPoints = []

        guard let data = try? JSONSerialization.data(withJSONObject: ["points": batch]) else { return }

        APIClient.shared.requestPublisher("run/sessions/\(sid)/points",
                                 method: "POST",
                                 body: data,
                                 authorized: true)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { (_: TelemetrySaved) in }
            )
            .store(in: &bag)
    }

    /// Call when the user completes the run.
    func finish() {
        flush()
        let distanceM = totalDistanceM
        let started   = startedAt
        let end        = Date()
        analysis = nil
        analyzing = true

        Task { @MainActor in
            // Si la sesión no se creó en el backend (falló el POST inicial), la
            // creamos ahora, así igual podemos finalizar y pedir el análisis.
            guard let sid = await self.ensureSession() else { self.analyzing = false; return }
            self.sessionId = nil

            // Pulso promedio de la ventana de la corrida desde HealthKit (Apple
            // Watch), para que el análisis del coach use el esfuerzo real.
            var avgHR: Double? = nil
            if let s = started {
                avgHR = await HealthKitService.shared.averageHeartRate(from: s, to: end)
            }
            self.postFinish(sid: sid, distanceM: distanceM, started: started, end: end, avgHR: avgHR)
        }
    }

    /// Devuelve la sesión activa o intenta crearla ahora si el POST inicial falló.
    private func ensureSession() async -> Int? {
        if let sid = sessionId { return sid }
        var body: [String: Any] = ["origin_lat": startOriginLat, "origin_lng": startOriginLng]
        if let rid = startRouteId { body["route_id"] = rid }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        let created: RunSessionCreated? = try? await APIClient.shared.request(
            "run/sessions", method: "POST", body: data, authorized: true)
        if let id = created?.id { sessionId = id; return id }
        return nil
    }

    private func postFinish(sid: Int, distanceM: CLLocationDistance, started: Date?, end: Date, avgHR: Double?) {
        var body: [String: Any] = ["distance_m": Int(distanceM)]
        if let s = started { body["duration_s"] = Int(end.timeIntervalSince(s)) }
        if let hr = avgHR, hr > 0 { body["avg_hr_bpm"] = Int(hr.rounded()) }

        guard let data = try? JSONSerialization.data(withJSONObject: body) else { analyzing = false; return }

        APIClient.shared.requestPublisher("run/sessions/\(sid)/finish",
                                 method: "POST",
                                 body: data,
                                 authorized: true)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion { self?.analyzing = false }
                },
                receiveValue: { [weak self] (_: SimpleOK) in
                    self?.fetchAnalysis(sessionId: sid)
                }
            )
            .store(in: &bag)

        // Save the workout to HealthKit
        if let s = started {
            Task {
                await HealthKitService.shared.saveRun(
                    distanceMeters: distanceM,
                    durationSeconds: end.timeIntervalSince(s),
                    startDate: s,
                    endDate: end
                )
            }
        }
    }

    /// After the run is finalised, ask the backend for the grounded AI analysis.
    private func fetchAnalysis(sessionId sid: Int) {
        guard let data = try? JSONSerialization.data(withJSONObject: ["session_id": sid]) else {
            analyzing = false
            return
        }
        APIClient.shared.requestPublisher("ai/run-analysis",
                                 method: "POST",
                                 body: data,
                                 authorized: true)
            .sink(
                receiveCompletion: { [weak self] _ in self?.analyzing = false },
                receiveValue: { [weak self] (a: RunAnalysis) in
                    self?.analysis = a
                    self?.analyzing = false
                }
            )
            .store(in: &bag)
    }

    /// Call when the user exits navigation without completing the run.
    func abandon() {
        pendingPoints = []
        guard let sid = sessionId else { return }
        sessionId = nil

        APIClient.shared.requestPublisher("run/sessions/\(sid)/abandon",
                                 method: "POST",
                                 authorized: true)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { (_: SimpleOK) in }
            )
            .store(in: &bag)
    }
}
