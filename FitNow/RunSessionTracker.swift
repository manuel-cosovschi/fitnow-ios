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
        if let prev = lastLocation {
            totalDistanceM += location.distance(from: prev)
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
        guard let sid = sessionId else { return }
        let distanceM = totalDistanceM
        let started   = startedAt
        let end        = Date()
        sessionId = nil
        analysis = nil
        analyzing = true

        // Pull the average heart rate for the run window from HealthKit (e.g. an
        // Apple Watch worn during the run), then finalise the session with it so
        // the coach analysis factors in the real effort. Falls back to no HR.
        Task { @MainActor in
            var avgHR: Double? = nil
            if let s = started {
                avgHR = await HealthKitService.shared.averageHeartRate(from: s, to: end)
            }
            self.postFinish(sid: sid, distanceM: distanceM, started: started, end: end, avgHR: avgHR)
        }
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
