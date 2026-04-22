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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RunNavigatorView
// ─────────────────────────────────────────────────────────────────────────────

struct RunNavigatorView: View {
    let option: RunRouteOption
    let origin: CLLocationCoordinate2D
    let userPrefs: RunUserPrefs

    @StateObject private var tracker = RunSessionTracker()
    @State private var statusText: String  = "Preparando navegación…"
    @State private var nextInstruction: String = "—"
    @State private var remainingToStep: String = "—"
    @State private var followingUser = true
    @State private var showFinishAlert = false
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen map
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
                },
                onLocation: { loc in
                    Task { @MainActor in tracker.addPoint(loc) }
                }
            )
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                topHUD
            }

            // Bottom dashboard
            bottomDashboard
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            LocationService.shared.start()
            tracker.start(
                routeId: option.id > 0 ? option.id : nil,
                originLat: origin.latitude,
                originLng: origin.longitude
            )
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            tracker.abandon()
        }
        .alert("¿Finalizar carrera?", isPresented: $showFinishAlert) {
            Button("Finalizar", role: .destructive) { tracker.finish() }
            Button("Continuar", role: .cancel) { }
        } message: {
            Text("Se guardará tu sesión con los datos recorridos.")
        }
    }

    // MARK: - Top HUD

    private var topHUD: some View {
        VStack(spacing: 8) {
            // Status bar
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: statusIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(statusColor)
                }
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Button {
                    followingUser.toggle()
                    NotificationCenter.default.post(name: .toggleFollowUser, object: followingUser)
                } label: {
                    Image(systemName: followingUser ? "location.north.line.fill" : "location")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(followingUser ? .fnCyan : .fnSlate.opacity(0.7))
                        .padding(8)
                        .background(Circle().fill(Color.fnSurface))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 3)

            // Turn instruction
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.fnCyan.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.fnCyan)
                }
                Text(nextInstruction)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Spacer()
                Text(remainingToStep)
                    .font(.custom("JetBrains Mono", size: 14).weight(.heavy))
                    .foregroundColor(.fnCyan)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    // MARK: - Bottom Dashboard

    private var bottomDashboard: some View {
        VStack(spacing: 0) {
            // Metrics row
            HStack(spacing: 12) {
                metricCell(
                    value: distanceText,
                    unit: "km",
                    label: "Distancia",
                    color: .fnCyan
                )
                Divider().frame(height: 44)
                metricCell(
                    value: elapsedText,
                    unit: "",
                    label: "Tiempo",
                    color: .fnPrimary
                )
                Divider().frame(height: 44)
                metricCell(
                    value: paceText,
                    unit: "/km",
                    label: "Ritmo",
                    color: .fnGreen
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider().opacity(0.5)

            // Buttons
            HStack(spacing: 12) {
                // Abandon
                Button {
                    timer?.invalidate()
                    tracker.abandon()
                } label: {
                    Label("Abandonar", systemImage: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.fnSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.fnSecondary.opacity(0.10))
                        )
                }
                .buttonStyle(ScaleButtonStyle())

                // Finish
                Button {
                    showFinishAlert = true
                } label: {
                    Label("Finalizar", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(FNGradient.run)
                        )
                        .fnShadowColored(.fnCyan, radius: 10, y: 4)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
            .padding(.top, 12)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedCornerShape(radius: 28, corners: [.topLeft, .topRight]))
        .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
    }

    private func metricCell(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.custom("JetBrains Mono", size: 22).weight(.heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundColor(.fnSlate)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.fnSlate)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed Values

    private var distanceText: String {
        let km = tracker.totalDistanceM / 1000.0
        return String(format: "%.2f", km)
    }

    private var elapsedText: String {
        let mins = Int(elapsed) / 60
        let secs = Int(elapsed) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var paceText: String {
        guard tracker.totalDistanceM > 10, elapsed > 0 else { return "—" }
        let pace = elapsed / (tracker.totalDistanceM / 1000.0)
        let m = Int(pace) / 60
        let s = Int(pace) % 60
        return String(format: "%d:%02d", m, s)
    }

    private var statusColor: Color {
        if statusText.contains("Advertencia") { return .fnYellow }
        if statusText.contains("Desvío") { return .fnSecondary }
        if statusText.contains("correr") { return .fnGreen }
        return .fnCyan
    }

    private var statusIcon: String {
        if statusText.contains("Advertencia") { return "exclamationmark.triangle.fill" }
        if statusText.contains("Desvío") { return "arrow.triangle.2.circlepath" }
        if statusText.contains("correr") { return "checkmark.circle.fill" }
        return "dot.radiowaves.left.and.right"
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1
        }
    }

    private static func prettyDistance(_ m: CLLocationDistance) -> String {
        if m < 1000 { return "\(Int(m)) m" }
        return String(format: "%.1f km", m / 1000.0)
    }
}

// MARK: - Notification extension

extension Notification.Name {
    static let toggleFollowUser = Notification.Name("RunNavigator.ToggleFollowUser")
}

// MARK: - Rounded corner shape (top corners only)

private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Navigator Map Representable (logic unchanged)
// ─────────────────────────────────────────────────────────────────────────────

fileprivate struct NavigatorMapRepresentable: UIViewRepresentable {
    let option: RunRouteOption
    let origin: CLLocationCoordinate2D
    let userPrefs: RunUserPrefs
    let onStatus: (String) -> Void
    let onStep: (String, CLLocationDistance) -> Void
    var onLocation: ((CLLocation) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(option: option, origin: origin, userPrefs: userPrefs,
                    onStatus: onStatus, onStep: onStep, onLocation: onLocation)
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
    private let onLocation: ((CLLocation) -> Void)?

    private var map: MKMapView!
    private let loc = CLLocationManager()
    private let speaker = AVSpeechSynthesizer()

    private var navSteps: [MKRoute.Step] = []
    private var blueOverlays: [MKPolyline] = []
    private var suggestedPolyline: MKPolyline?

    private var currentStepIndex: Int = 0
    private var followUser = true
    private var bag = Set<AnyCancellable>()

    init(option: RunRouteOption, origin: CLLocationCoordinate2D, userPrefs: RunUserPrefs,
         onStatus: @escaping (String) -> Void, onStep: @escaping (String, CLLocationDistance) -> Void,
         onLocation: ((CLLocation) -> Void)? = nil) {
        self.option = option
        self.origin = origin
        self.destination = option.geojson.coords2D.last ?? origin
        self.userPrefs = userPrefs
        self.onStatus = onStatus
        self.onStep = onStep
        self.onLocation = onLocation
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

    private func setupLocation() {
        loc.delegate = self
        loc.activityType = .fitness
        loc.pausesLocationUpdatesAutomatically = false
        switch loc.authorizationStatus {
        case .notDetermined: loc.requestWhenInUseAuthorization()
        default: break
        }
        loc.desiredAccuracy = kCLLocationAccuracyBest
        loc.startUpdatingLocation()
    }

    private func drawSuggestedPolyline() {
        let coords = option.geojson.coords2D
        guard !coords.isEmpty else { return }
        let pl = MKPolyline(coordinates: coords, count: coords.count)
        suggestedPolyline = pl
        map.addOverlay(pl, level: .aboveRoads)
        map.setVisibleMapRect(pl.boundingMapRect,
                              edgePadding: UIEdgeInsets(top: 90, left: 30, bottom: 220, right: 30),
                              animated: false)
    }

    private func anchors(from coords: [CLLocationCoordinate2D], every meters: CLLocationDistance) -> [CLLocationCoordinate2D] {
        guard !coords.isEmpty else { return [] }
        var out: [CLLocationCoordinate2D] = [origin]; var acc: CLLocationDistance = 0
        for i in 1..<coords.count {
            let a = coords[i-1], b = coords[i]
            acc += CLLocation(latitude: a.latitude, longitude: a.longitude)
                    .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            if acc >= meters { out.append(b); acc = 0 }
        }
        if let last = coords.last, let prev = out.last,
           !(prev.latitude == last.latitude && prev.longitude == last.longitude) { out.append(last) }
        return out
    }

    private func calculate(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) async throws -> MKRoute {
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: .init(coordinate: a))
        req.destination = MKMapItem(placemark: .init(coordinate: b))
        req.transportType = .walking; req.requestsAlternateRoutes = false
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

    private func requestDirectRoute(from src: CLLocationCoordinate2D? = nil) {
        Task {
            do {
                let r = try await calculate(from: src ?? origin, to: destination)
                applySegments([r]); emitStatus("Ruta lista. ¡A correr!")
                announceIfNeeded(r.steps.first?.instructions.isEmpty == false ? r.steps.first!.instructions : "Comienzo")
                updateInstruction(for: nil)
            } catch { emitStatus("No se pudo calcular la ruta") }
        }
    }

    private func applySegments(_ segments: [MKRoute]) {
        clearBlueOverlays()
        navSteps = segments.flatMap { $0.steps }; currentStepIndex = 0
        for r in segments { blueOverlays.append(r.polyline); map.addOverlay(r.polyline, level: .aboveLabels) }
    }

    private func requestRouteFollowingSuggestion(from src: CLLocationCoordinate2D? = nil) async {
        emitStatus("Calculando ruta…")
        let coords = option.geojson.coords2D
        guard !coords.isEmpty else { emitStatus("Ruta inválida"); return }
        let points = anchors(from: coords, every: 500)
        guard points.count >= 2 else { requestDirectRoute(from: src); return }
        var segments: [MKRoute] = []; let start = src ?? origin; var last = start
        do {
            for p in points { let r = try await calculate(from: last, to: p); segments.append(r); last = p }
            applySegments(segments); emitStatus("Ruta lista. ¡A correr!")
            announceIfNeeded(navSteps.first?.instructions.isEmpty == false ? navSteps.first!.instructions : "Comienzo")
            updateInstruction(for: nil)
        } catch { requestDirectRoute(from: start) }
    }

    private func emitStatus(_ s: String) { onStatus(s) }

    // MARK: MKMapViewDelegate
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let pl = overlay as? MKPolyline {
            if let sug = suggestedPolyline, pl === sug {
                let r = MKPolylineRenderer(polyline: pl)
                r.strokeColor = UIColor(.fnSlate.opacity(0.7))
                r.lineDashPattern = [6, 4]; r.lineWidth = 3; return r
            }
            let r = MKPolylineRenderer(polyline: pl)
            r.strokeColor = UIColor(Color.fnCyan)
            r.lineWidth = 7; r.lineJoin = .round; r.lineCap = .round
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    // MARK: CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        onLocation?(loc)
        HazardService.shared.refreshIfNeeded(around: loc.coordinate)
        if followUser { map.setCenter(loc.coordinate, animated: true) }
        updateInstruction(for: loc)
        if isOffCompositeRoute(current: loc, threshold: userPrefs.rerouteDistanceMeters) {
            emitStatus("Desvío detectado. Recalculando…")
            Task { await requestRouteFollowingSuggestion(from: loc.coordinate) }
        }
        if let dist = HazardService.shared.nearestHazardDistance(from: loc.coordinate, within: 80), dist <= 80 {
            emitStatus("Advertencia: zona riesgosa a \(Int(dist)) m")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        emitStatus("Error de GPS: \(error.localizedDescription)")
    }

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
        var best = currentStepIndex; var bestDist = CLLocationDistance.greatestFiniteMagnitude
        for (i, s) in navSteps.enumerated() {
            guard let pl = s.polylineIfAvailable else { continue }
            let d = distance(from: c, to: pl)
            if d < bestDist { bestDist = d; best = i }
        }
        return max(best, currentStepIndex)
    }

    private func remainingDistance(on step: MKRoute.Step, from coord: CLLocationCoordinate2D?) -> CLLocationDistance? {
        guard let pl = step.polylineIfAvailable else { return step.distance }
        guard let c = coord else { return step.distance }
        return max(step.distance - distance(from: c, to: pl), 0)
    }

    private func distance(from coord: CLLocationCoordinate2D, to polyline: MKPolyline) -> CLLocationDistance {
        let point = MKMapPoint(coord); var minDist = CLLocationDistance.greatestFiniteMagnitude
        let pts = polyline.points(); let count = polyline.pointCount
        guard count > 1 else { return minDist }
        for i in 0..<(count-1) { let d = distancePointToSegment(point, pts[i], pts[i+1]); if d < minDist { minDist = d } }
        return minDist
    }

    private func distancePointToSegment(_ p: MKMapPoint, _ a: MKMapPoint, _ b: MKMapPoint) -> CLLocationDistance {
        let apx = p.x-a.x, apy = p.y-a.y, abx = b.x-a.x, aby = b.y-a.y
        let ab2 = abx*abx + aby*aby
        let t = max(0.0, min(1.0, (apx*abx + apy*aby) / (ab2 == 0 ? 1 : ab2)))
        return MKMapPoint(x: a.x + abx*t, y: a.y + aby*t).distance(to: p)
    }

    private func isOffCompositeRoute(current: CLLocation, threshold: CLLocationDistance) -> Bool {
        var best = CLLocationDistance.greatestFiniteMagnitude
        for pl in blueOverlays { let d = distance(from: current.coordinate, to: pl); if d < best { best = d } }
        return best > threshold
    }

    private func announceIfNeeded(_ text: String) {
        guard userPrefs.voiceEnabled else { return }
        if speaker.isSpeaking { speaker.stopSpeaking(at: .immediate) }
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: "es-AR") ?? AVSpeechSynthesisVoice(language: "es-ES")
        utt.rate = AVSpeechUtteranceDefaultSpeechRate
        speaker.speak(utt)
    }
}

fileprivate extension MKRoute.Step {
    var polylineIfAvailable: MKPolyline? {
        value(forKey: "polyline") as? MKPolyline
    }
}
