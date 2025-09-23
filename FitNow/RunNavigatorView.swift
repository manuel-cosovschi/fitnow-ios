import SwiftUI
import MapKit
import CoreLocation
import AVFoundation
import Combine

struct RunUserPrefs {
    var voiceEnabled: Bool = true
    var rerouteDistanceMeters: CLLocationDistance = 50
    var followUser: Bool = true
    static let `default` = RunUserPrefs()
}

struct RunNavigatorView: View {
    let option: RunRouteOption
    let origin: CLLocationCoordinate2D
    let userPrefs: RunUserPrefs

    @State private var statusText: String = "Preparando navegación…"
    @State private var nextInstruction: String = "—"
    @State private var remainingToStep: String = "—"
    @State private var followingUser = true

    var body: some View {
        VStack(spacing: 0) {
            NavigatorMapRepresentable(
                option: option,
                origin: origin,
                userPrefs: userPrefs,
                onStatus: { txt in
                    DispatchQueue.main.async { statusText = txt }
                },
                onStep: { instr, dist in
                    DispatchQueue.main.async {
                        nextInstruction = instr
                        remainingToStep = Self.prettyDistance(dist)
                    }
                }
            )
            .overlay(alignment: .top) {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                        Text(statusText).font(.footnote)
                        Spacer()
                        Button {
                            followingUser.toggle()
                            NotificationCenter.default.post(name: .toggleFollowUser,
                                                            object: followingUser)
                        } label: {
                            Image(systemName: followingUser ? "location.north.line.fill"
                                                             : "location")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding([.top, .horizontal], 8)

                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        Text(nextInstruction).font(.subheadline).bold()
                        Spacer()
                        Text(remainingToStep).font(.footnote).foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal, 8)
                }
            }
        }
        .navigationTitle("Navegación")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { LocationService.shared.start() }
    }

    private static func prettyDistance(_ m: CLLocationDistance) -> String {
        if m < 1000 { return "\(Int(m)) m" }
        return String(format: "%.1f km", m / 1000.0)
    }
}

extension Notification.Name {
    static let toggleFollowUser = Notification.Name("RunNavigator.ToggleFollowUser")
}

fileprivate struct NavigatorMapRepresentable: UIViewRepresentable {
    let option: RunRouteOption
    let origin: CLLocationCoordinate2D
    let userPrefs: RunUserPrefs
    let onStatus: (String) -> Void
    let onStep: (String, CLLocationDistance) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(option: option,
                    origin: origin,
                    userPrefs: userPrefs,
                    onStatus: onStatus,
                    onStep: onStep)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode = .follow
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        context.coordinator.attach(to: map)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) { }
}

// MARK: - Coordinator
fileprivate final class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
    private let option: RunRouteOption
    private let origin: CLLocationCoordinate2D
    private var destination: CLLocationCoordinate2D
    private let userPrefs: RunUserPrefs
    private let onStatus: (String) -> Void
    private let onStep: (String, CLLocationDistance) -> Void

    private var map: MKMapView!
    private let loc = CLLocationManager()
    private let speaker = AVSpeechSynthesizer()

    // Ruta compuesta (por segmentos) y overlays
    private var navSteps: [MKRoute.Step] = []
    private var blueOverlays: [MKPolyline] = []
    private var suggestedPolyline: MKPolyline? // overlay gris

    private var currentStepIndex: Int = 0
    private var followUser = true
    private var bag = Set<AnyCancellable>()

    init(option: RunRouteOption,
         origin: CLLocationCoordinate2D,
         userPrefs: RunUserPrefs,
         onStatus: @escaping (String) -> Void,
         onStep: @escaping (String, CLLocationDistance) -> Void) {
        self.option = option
        self.origin = origin
        self.destination = option.geojson.coords2D.last ?? origin
        self.userPrefs = userPrefs
        self.onStatus = onStatus
        self.onStep = onStep
    }

    func attach(to map: MKMapView) {
        self.map = map

        NotificationCenter.default.publisher(for: .toggleFollowUser)
            .sink { [weak self] note in
                guard let self, let f = note.object as? Bool else { return }
                self.followUser = f
                self.map.userTrackingMode = f ? .followWithHeading : .none
            }
            .store(in: &bag)

        setupLocation()
        drawSuggestedPolyline()
        Task { await requestRouteFollowingSuggestion() }
    }

    // MARK: Location
    private func setupLocation() {
        loc.delegate = self
        loc.activityType = .fitness
        loc.pausesLocationUpdatesAutomatically = false

        switch loc.authorizationStatus {
        case .notDetermined:
            loc.requestWhenInUseAuthorization()
        default: break
        }
        loc.desiredAccuracy = kCLLocationAccuracyBest
        loc.startUpdatingLocation()
    }

    // MARK: Sugerida (gris)
    private func drawSuggestedPolyline() {
        let coords = option.geojson.coords2D
        guard !coords.isEmpty else { return }
        let pl = MKPolyline(coordinates: coords, count: coords.count)
        suggestedPolyline = pl
        map.addOverlay(pl, level: .aboveRoads)
        map.setVisibleMapRect(pl.boundingMapRect,
                              edgePadding: UIEdgeInsets(top: 90, left: 30, bottom: 160, right: 30),
                              animated: false)
    }

    // MARK: Build route by segments to follow suggested path
    private func anchors(from coords: [CLLocationCoordinate2D],
                         every meters: CLLocationDistance) -> [CLLocationCoordinate2D] {
        guard !coords.isEmpty else { return [] }
        var out: [CLLocationCoordinate2D] = [origin]
        var acc: CLLocationDistance = 0
        for i in 1..<coords.count {
            let a = coords[i-1], b = coords[i]
            let da = CLLocation(latitude: a.latitude, longitude: a.longitude)
            let db = CLLocation(latitude: b.latitude, longitude: b.longitude)
            let d = da.distance(from: db)
            acc += d
            if acc >= meters {
                out.append(b)
                acc = 0
            }
        }
        if let last = coords.last,
           let prev = out.last,
           !(prev.latitude == last.latitude && prev.longitude == last.longitude) {
            out.append(last)
        } else if let last = coords.last, out.last == nil {
            out.append(last)
        }
        return out
    }

    private func calculate(from a: CLLocationCoordinate2D,
                           to b: CLLocationCoordinate2D) async throws -> MKRoute {
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: .init(coordinate: a))
        req.destination = MKMapItem(placemark: .init(coordinate: b))
        req.transportType = .walking
        req.requestsAlternateRoutes = false
        return try await withCheckedThrowingContinuation { cont in
            MKDirections(request: req).calculate { resp, err in
                if let r = resp?.routes.first { cont.resume(returning: r) }
                else { cont.resume(throwing: err ?? NSError(domain: "nav", code: 1)) }
            }
        }
    }

    private func clearBlueOverlays() {
        for pl in blueOverlays { map.removeOverlay(pl) }
        blueOverlays.removeAll()
    }

    private func emitStatus(_ s: String) { onStatus(s) }

    private func requestDirectRoute(from src: CLLocationCoordinate2D? = nil) {
        Task {
            do {
                let r = try await calculate(from: src ?? origin, to: destination)
                self.applySegments([r])
                self.emitStatus("Ruta lista. ¡A correr!")
                self.announceIfNeeded(r.steps.first?.instructions.isEmpty == false ? r.steps.first!.instructions : "Comienzo")
                self.updateInstruction(for: nil)
            } catch {
                self.emitStatus("No se pudo calcular la ruta")
            }
        }
    }

    private func applySegments(_ segments: [MKRoute]) {
        clearBlueOverlays()
        navSteps = segments.flatMap { $0.steps }
        currentStepIndex = 0
        for r in segments {
            blueOverlays.append(r.polyline)
            map.addOverlay(r.polyline, level: .aboveLabels)
        }
    }

    private func requestRouteFollowingSuggestion(from src: CLLocationCoordinate2D? = nil) async {
        emitStatus("Calculando ruta…")
        let coords = option.geojson.coords2D
        guard !coords.isEmpty else { emitStatus("Ruta inválida"); return }

        // 400–600 m da buen equilibrio en running
        let points = anchors(from: coords, every: 500)
        guard points.count >= 2 else { requestDirectRoute(from: src); return }

        var segments: [MKRoute] = []
        let start = src ?? origin
        var last = start

        do {
            for p in points {
                let r = try await calculate(from: last, to: p)
                segments.append(r)
                last = p
            }
            applySegments(segments)
            emitStatus("Ruta lista. ¡A correr!")
            announceIfNeeded(navSteps.first?.instructions.isEmpty == false ? navSteps.first!.instructions : "Comienzo")
            updateInstruction(for: nil)
        } catch {
            requestDirectRoute(from: start) // fallback
        }
    }

    // MARK: MKMapViewDelegate
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let pl = overlay as? MKPolyline {
            if let sug = suggestedPolyline, pl === sug {
                let r = MKPolylineRenderer(polyline: pl)
                r.strokeColor = .systemGray
                r.lineDashPattern = [6, 4]
                r.lineWidth = 3
                return r
            }
            let r = MKPolylineRenderer(polyline: pl)
            r.strokeColor = .systemBlue
            r.lineWidth = 6
            r.lineJoin = .round
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    // MARK: CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }

        // refrescá hazards según movimiento/tiempo
        HazardService.shared.refreshIfNeeded(around: loc.coordinate)

        if followUser { map.setCenter(loc.coordinate, animated: true) }

        // instrucciones
        updateInstruction(for: loc)

        // desvío (contra ruta compuesta)
        if isOffCompositeRoute(current: loc, threshold: userPrefs.rerouteDistanceMeters) {
            emitStatus("Desvío detectado. Recalculando…")
            Task { await requestRouteFollowingSuggestion(from: loc.coordinate) }
        }

        // hazard cercano
        if let dist = HazardService.shared.nearestHazardDistance(from: loc.coordinate, within: 80),
           dist <= 80 {
            emitStatus("Advertencia: zona riesgosa a \(Int(dist)) m")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        emitStatus("Error de GPS: \(error.localizedDescription)")
    }

    // MARK: Instrucciones sobre la ruta compuesta
    private func updateInstruction(for current: CLLocation?) {
        guard !navSteps.isEmpty else { return }

        let index = nearestStepIndex(to: current?.coordinate)
        if index != currentStepIndex {
            currentStepIndex = index
            let instr = navSteps[index].instructions.isEmpty ? "Seguí recto" : navSteps[index].instructions
            announceIfNeeded(instr)
        }

        let step = navSteps[currentStepIndex]
        let remaining = remainingDistance(on: step, from: current?.coordinate) ?? step.distance
        onStep(step.instructions.isEmpty ? "Seguí recto" : step.instructions, remaining)
    }

    private func nearestStepIndex(to coord: CLLocationCoordinate2D?) -> Int {
        guard let c = coord else { return currentStepIndex }
        var best = currentStepIndex
        var bestDist = CLLocationDistance.greatestFiniteMagnitude
        for (i, s) in navSteps.enumerated() {
            guard let pl = s.polylineIfAvailable else { continue }
            let d = distance(from: c, to: pl)
            if d < bestDist { bestDist = d; best = i }
        }
        return max(best, currentStepIndex)
    }

    private func remainingDistance(on step: MKRoute.Step,
                                   from coord: CLLocationCoordinate2D?) -> CLLocationDistance? {
        guard let pl = step.polylineIfAvailable else { return step.distance }
        guard let c = coord else { return step.distance }
        let dPoint = distance(from: c, to: pl)
        return max(step.distance - dPoint, 0)
    }

    private func distance(from coord: CLLocationCoordinate2D,
                          to polyline: MKPolyline) -> CLLocationDistance {
        let point = MKMapPoint(coord)
        var minDist = CLLocationDistance.greatestFiniteMagnitude
        let pts = polyline.points()
        let count = polyline.pointCount
        guard count > 1 else { return minDist }
        for i in 0..<(count-1) {
            let a = pts[i]
            let b = pts[i+1]
            let d = distancePointToSegment(point, a, b)
            if d < minDist { minDist = d }
        }
        return minDist
    }

    private func distancePointToSegment(_ p: MKMapPoint,
                                        _ a: MKMapPoint,
                                        _ b: MKMapPoint) -> CLLocationDistance {
        let apx = p.x - a.x, apy = p.y - a.y
        let abx = b.x - a.x, aby = b.y - a.y
        let ab2 = abx*abx + aby*aby
        let t = max(0.0, min(1.0, (apx*abx + apy*aby) / (ab2 == 0 ? 1 : ab2)))
        let proj = MKMapPoint(x: a.x + abx * t, y: a.y + aby * t)
        return proj.distance(to: p)
    }

    private func isOffCompositeRoute(current: CLLocation,
                                     threshold: CLLocationDistance) -> Bool {
        var best = CLLocationDistance.greatestFiniteMagnitude
        for pl in blueOverlays {
            let d = distance(from: current.coordinate, to: pl)
            if d < best { best = d }
        }
        return best > threshold
    }

    private func announceIfNeeded(_ text: String) {
        guard userPrefs.voiceEnabled else { return }
        if speaker.isSpeaking { speaker.stopSpeaking(at: .immediate) }
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: "es-AR")
            ?? AVSpeechSynthesisVoice(language: "es-ES")
        utt.rate = AVSpeechUtteranceDefaultSpeechRate
        speaker.speak(utt)
    }
}

fileprivate extension MKRoute.Step {
    var polylineIfAvailable: MKPolyline? {
        value(forKey: "polyline") as? MKPolyline
    }
}

