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

// Zona de riesgo que tenés cerca en este momento de la corrida. Alimenta los
// indicadores que se pegan al borde del mapa: uno por zona, con la distancia
// que baja mientras te acercás y sube cuando la dejás atrás.
// `bearing` es el rumbo hacia la zona relativo a hacia dónde mira la cámara
// (0 = adelante, 90 = a tu derecha), y es lo que decide contra qué borde va.
struct NearbyHazard: Equatable, Identifiable {
    let id: Int
    let type: String
    let distance: Int
    let severity: Int
    let bearing: Double
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RunNavigatorView
// ─────────────────────────────────────────────────────────────────────────────

struct RunNavigatorView: View {
    let option: RunRouteOption
    let origin: CLLocationCoordinate2D
    let userPrefs: RunUserPrefs

    @Environment(\.dismiss) private var dismiss

    @StateObject private var tracker = RunSessionTracker()
    @State private var statusText: String  = "Preparando navegación…"
    @State private var nextInstruction: String = "—"
    @State private var remainingToStep: String = "—"
    @State private var followingUser = true
    @State private var showFinishAlert = false
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var sessionEnded = false
    @State private var showAnalysis = false
    @State private var showReportSheet = false
    // Zonas de riesgo cercanas en vivo: alimentan los indicadores de borde.
    // Vacío = ninguna zona a la vista.
    @State private var nearbyHazards: [NearbyHazard] = []
    // Latido de los indicadores para que "respiren" mientras te acercás.
    @State private var hazardPulse = false

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
                },
                onHazards: { list in
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                            nearbyHazards = list
                        }
                    }
                }
            )
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                topHUD
            }
            // Popup dinámico de zona de riesgo: salta animado bajo el HUD cuando
            // entrás en los 80 m, muestra el tipo y la distancia en vivo, y se va
            // solo al dejar la zona atrás. Es la red de seguridad por si la ruta
            // no la esquivó o el reporte llegó ya en plena corrida.
            .overlay(alignment: .top) {
                if let hz = popupHazard {
                    hazardPopup(hz)
                        .padding(.horizontal, 12)
                        .padding(.top, 172)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(3)
                }
            }
            // Indicadores pegados al borde del mapa: uno por zona a la vista, del
            // lado hacia donde está y con la distancia contando en vivo. Avisan
            // de lo que viene mucho antes de que el popup llegue a saltar.
            .overlay {
                hazardEdgeOverlay
                    .allowsHitTesting(false)
                    .zIndex(2)
            }

            // Botón de reporte rápido de zona (estilo Waze), sobre el dashboard
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showReportSheet = true
                } label: {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(Color.fnSecondary)
                                .shadow(color: Color.fnSecondary.opacity(0.5), radius: 10, x: 0, y: 4)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.trailing, 16)
                .padding(.bottom, 240)
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
            if !sessionEnded { tracker.abandon() }
        }
        .alert("¿Finalizar carrera?", isPresented: $showFinishAlert) {
            Button("Finalizar", role: .destructive) {
                sessionEnded = true
                tracker.finish()
                showAnalysis = true
            }
            Button("Continuar", role: .cancel) { }
        } message: {
            Text("Se guardará tu sesión con los datos recorridos.")
        }
        .sheet(isPresented: $showAnalysis, onDismiss: { dismiss() }) {
            RunAnalysisSheet(tracker: tracker) { showAnalysis = false }
        }
        .sheet(isPresented: $showReportSheet) {
            HazardReportSheet()
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

    // MARK: - Popup dinámico de zona de riesgo

    /// La zona que dispara el popup: la más cercana dentro de los 80 m, igual
    /// que antes. Sale de la misma lista que alimenta los indicadores de borde,
    /// que llega ordenada de más cerca a más lejos.
    private var popupHazard: NearbyHazard? {
        guard let first = nearbyHazards.first, first.distance <= 80 else { return nil }
        return first
    }

    private func hazardPopup(_ hz: NearbyHazard) -> some View {
        let color = Self.hazardSeverityColor(hz.severity)
        // El popup redondea a decenas: a esta distancia el número exacto salta
        // con el ruido del GPS y marea. El contador fino va en el indicador.
        let rounded = Int((Double(hz.distance) / 10).rounded()) * 10
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.22))
                    .frame(width: 46, height: 46)
                    .scaleEffect(hazardPulse ? 1.15 : 0.92)
                Image(systemName: Coordinator.hazardGlyph(hz.type))
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Coordinator.hazardTitle(hz.type))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("Reducí el ritmo y prestá atención")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.fnSlate)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(rounded)")
                    .font(.custom("JetBrains Mono", size: 22).weight(.heavy))
                    .foregroundColor(color)
                    .contentTransition(.numericText())
                Text("metros")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.fnSlate)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.55), lineWidth: 1.5)
        )
        .shadow(color: color.opacity(0.35), radius: 12, y: 4)
    }

    // MARK: - Indicadores de zona de riesgo en el borde del mapa

    private var hazardEdgeOverlay: some View {
        GeometryReader { geo in
            ZStack {
                // La zona que ya está en el popup no repite indicador: sería la
                // misma información dos veces, y el popup manda a esa distancia.
                ForEach(Self.placeOnEdges(nearbyHazards.filter { $0.id != popupHazard?.id },
                                          in: geo.size,
                                          topInset: popupHazard == nil ? 178 : 250),
                        id: \.hazard.id) { placed in
                    hazardChip(placed.hazard)
                        .position(placed.point)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            hazardPulse = false
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                hazardPulse = true
            }
        }
    }

    /// Un indicador: la flecha apunta hacia la zona, el número es la distancia
    /// en vivo. Cuanto más cerca estás, más marcado el latido.
    private func hazardChip(_ hz: NearbyHazard) -> some View {
        let color = Self.hazardSeverityColor(hz.severity)
        // Solo late cuando la tenés encima; de lejos queda quieto para no marear.
        let pulsing = hz.distance <= 120
        return VStack(spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(color)
                    .rotationEffect(.degrees(hz.bearing))
                Image(systemName: Coordinator.hazardGlyph(hz.type))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(color)
                Text("\(hz.distance)")
                    .font(.custom("JetBrains Mono", size: 17).weight(.heavy))
                    .foregroundColor(color)
                    .contentTransition(.numericText())
                Text("m")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.fnSlate)
            }
            Text(Coordinator.hazardTitle(hz.type))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: Self.hazardChipSize.width)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(color.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: color.opacity(0.35), radius: 10, y: 3)
        .scaleEffect(pulsing && hazardPulse ? 1.06 : 1.0)
    }

    private static let hazardChipSize = CGSize(width: 132, height: 46)

    /// Pega cada zona contra el borde del mapa según su rumbo, dentro de la
    /// franja que no tapan el HUD ni el tablero. Si dos caen una encima de la
    /// otra, la segunda se corre unos grados para que las dos se lean.
    static func placeOnEdges(_ hazards: [NearbyHazard],
                             in size: CGSize,
                             topInset: CGFloat) -> [(hazard: NearbyHazard, point: CGPoint)] {
        var placed: [(hazard: NearbyHazard, point: CGPoint)] = []
        for hz in hazards {
            var point = edgePosition(for: hz.bearing, in: size, topInset: topInset)
            var attempt = 0
            while attempt < 3,
                  placed.contains(where: { hypot($0.point.x - point.x, $0.point.y - point.y) < hazardChipSize.width * 0.85 }) {
                attempt += 1
                point = edgePosition(for: hz.bearing + Double(attempt) * 26, in: size, topInset: topInset)
            }
            placed.append((hz, point))
        }
        return placed
    }

    /// Proyecta un rumbo relativo (0 = adelante) sobre el borde de la franja
    /// visible: adelante arriba, atrás abajo, y los costados a los costados.
    static func edgePosition(for bearing: Double, in size: CGSize, topInset: CGFloat) -> CGPoint {
        let halfChipW = hazardChipSize.width / 2 + 8
        let halfChipH = hazardChipSize.height / 2 + 4
        let minX = halfChipW
        let maxX = max(size.width - halfChipW, minX)
        let minY = topInset + halfChipH                         // debajo del HUD (y del popup si está)
        let maxY = max(size.height - 246 - halfChipH, minY)     // encima del tablero
        let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
        let halfW = (maxX - minX) / 2, halfH = (maxY - minY) / 2
        guard halfW > 1, halfH > 1 else { return CGPoint(x: cx, y: cy) }
        let rad = bearing * .pi / 180
        let dx = CGFloat(sin(rad)), dy = CGFloat(-cos(rad))
        let tx = abs(dx) < 0.001 ? CGFloat.greatestFiniteMagnitude : halfW / abs(dx)
        let ty = abs(dy) < 0.001 ? CGFloat.greatestFiniteMagnitude : halfH / abs(dy)
        let t = min(tx, ty)
        return CGPoint(x: cx + dx * t, y: cy + dy * t)
    }

    private static func hazardSeverityColor(_ severity: Int) -> Color {
        severity >= 2 ? .fnSecondary : .fnYellow
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
                    sessionEnded = true
                    timer?.invalidate()
                    tracker.abandon()
                    dismiss()
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
        // Recién mostramos ritmo cuando hay una distancia real (>50 m); antes,
        // con poca distancia, el ritmo (tiempo/distancia) da números disparatados.
        guard tracker.totalDistanceM > 50, elapsed > 0 else { return "—" }
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
    var onHazards: (([NearbyHazard]) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(option: option, origin: origin, userPrefs: userPrefs,
                    onStatus: onStatus, onStep: onStep, onLocation: onLocation, onHazards: onHazards)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        // No usamos userTrackingMode: manejamos la cámara a mano para lograr la
        // vista de navegación inclinada (pitch) y rotada hacia el rumbo. Con
        // .follow/.followWithHeading MapKit fuerza la cámara plana y pisaría el pitch.
        map.userTrackingMode = .none
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
    private let onHazards: (([NearbyHazard]) -> Void)?

    private var map: MKMapView!
    private let loc = CLLocationManager()
    private let speaker = AVSpeechSynthesizer()

    private var navSteps: [MKRoute.Step] = []
    private var blueOverlays: [MKPolyline] = []
    private var suggestedPolyline: MKPolyline?
    // Zonas de riesgo dibujadas en el mapa: círculo rojo (radio de influencia)
    // + pin rojo por cada reporte cercano. Se refrescan al moverse.
    private var hazardCircles: [MKCircle] = []
    private var hazardPins: [MKPointAnnotation] = []

    private var currentStepIndex: Int = 0
    private var followUser = true
    // Último rumbo válido: si el GPS deja de dar course (parado), mantenemos la
    // orientación de la cámara en vez de girarla al azar por el ruido.
    private var lastHeading: CLLocationDirection = 0
    private var bag = Set<AnyCancellable>()
    // Freno del recálculo de ruta: sin esto, parado "fuera de ruta" se
    // recalculaba en CADA lectura de GPS y Apple bloqueaba Directions
    // (máx. 50 pedidos/minuto).
    private var isCalculatingRoute = false
    private var lastRerouteAt = Date.distantPast
    // Última advertencia de zona emitida: evita repetir el mismo aviso en cada
    // lectura y que el número "salte" por el ruido del GPS estando quieto.
    private var lastHazardStatus: String?

    init(option: RunRouteOption, origin: CLLocationCoordinate2D, userPrefs: RunUserPrefs,
         onStatus: @escaping (String) -> Void, onStep: @escaping (String, CLLocationDistance) -> Void,
         onLocation: ((CLLocation) -> Void)? = nil, onHazards: (([NearbyHazard]) -> Void)? = nil) {
        self.option = option
        self.origin = origin
        self.destination = option.geojson.coords2D.last ?? origin
        self.userPrefs = userPrefs
        self.onStatus = onStatus
        self.onStep = onStep
        self.onLocation = onLocation
        self.onHazards = onHazards
    }

    func attach(to map: MKMapView) {
        self.map = map
        NotificationCenter.default.publisher(for: .toggleFollowUser)
            .sink { [weak self] note in
                guard let self, let f = note.object as? Bool else { return }
                self.followUser = f
                // Al reactivar el seguimiento, saltamos de una a la cámara de
                // navegación sobre la última posición conocida.
                if f, let ul = self.map.userLocation.location {
                    self.updateCamera(to: ul)
                }
            }
            .store(in: &bag)
        setupLocation()
        drawSuggestedPolyline()
        addStartFinishMarker()
        // Escucha los reportes cercanos y los pinta en el mapa (puntos rojos).
        HazardService.shared.$hazards
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hz in self?.renderHazards(hz) }
            .store(in: &bag)
        HazardService.shared.refreshIfNeeded(around: origin)
        Task { await requestRouteFollowingSuggestion() }
    }

    // Dibuja las zonas de riesgo: un círculo rojo translúcido con el radio de
    // influencia y un pin rojo en el centro de cada reporte. Se rehace cada vez
    // que llegan reportes nuevos (al moverse hacia una zona no cargada aún).
    private func renderHazards(_ hazards: [HazardArea]) {
        guard map != nil else { return }
        map.removeOverlays(hazardCircles)
        map.removeAnnotations(hazardPins)
        hazardCircles.removeAll(); hazardPins.removeAll()
        for h in hazards {
            let circle = MKCircle(center: h.center, radius: 75)
            hazardCircles.append(circle)
            map.addOverlay(circle, level: .aboveRoads)
            let pin = HazardAnnotation(kind: h.type)
            pin.coordinate = h.center
            pin.title = Self.hazardTitle(h.type)
            if let n = h.note, !n.isEmpty { pin.subtitle = n }
            hazardPins.append(pin)
            map.addAnnotation(pin)
        }
    }

    static func hazardTitle(_ type: String) -> String {
        switch type {
        case "inseguridad": return "Zona insegura"
        case "iluminacion": return "Mala iluminación"
        case "vereda_rota": return "Vereda rota"
        case "obra":        return "Obra o corte"
        default:            return "Zona reportada"
        }
    }

    // Cámara de navegación: en vez de mirar el mapa desde arriba (plano), lo
    // inclinamos (pitch 60°) y lo rotamos hacia el rumbo de la corrida, así el
    // recorrido queda "hacia adelante" y da la sensación de ir manejando la ruta.
    // El rumbo sale del course del GPS; si no hay (parado), se mantiene el último.
    private func updateCamera(to loc: CLLocation) {
        guard map != nil else { return }
        if loc.course >= 0, loc.speed >= 0.5 {
            lastHeading = loc.course
        }
        let cam = MKMapCamera(lookingAtCenter: loc.coordinate,
                              fromDistance: 480, pitch: 60, heading: lastHeading)
        map.setCamera(cam, animated: true)
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

    // Marca dónde empieza y termina el circuito (todas las rutas son loops:
    // salís y llegás al mismo punto), así se entiende el recorrido de un vistazo.
    private func addStartFinishMarker() {
        let pin = MKPointAnnotation()
        pin.coordinate = origin
        pin.title = "Salida y meta"
        map.addAnnotation(pin)
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

    // Largo total de la geometría (suma de los tramos entre puntos).
    private func routeLength(of coords: [CLLocationCoordinate2D]) -> CLLocationDistance {
        guard coords.count >= 2 else { return 0 }
        var total: CLLocationDistance = 0
        for i in 1..<coords.count {
            total += CLLocation(latitude: coords[i-1].latitude, longitude: coords[i-1].longitude)
                .distance(from: CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude))
        }
        return total
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
                announceIfNeeded(r.steps.first?.instructions.isEmpty == false ? Self.localizedInstruction(r.steps.first!.instructions) : "Comienzo")
                updateInstruction(for: nil)
            } catch { fallBackToSuggestedRoute() }
        }
    }

    /// Last-resort route: draw the backend's road-based geometry directly as the
    /// active route. Apple's MKDirections throttles after a handful of requests,
    /// so on a long loop it can fail entirely — but the suggestion is already
    /// snapped to roads by the backend (OSRM), so it's perfectly runnable without
    /// turn-by-turn. Beats the dead-end "no se pudo calcular la ruta".
    private func fallBackToSuggestedRoute() {
        let coords = option.geojson.coords2D
        guard coords.count >= 2 else { emitStatus("Ruta inválida"); return }
        clearBlueOverlays()
        navSteps = []
        currentStepIndex = 0
        let pl = MKPolyline(coordinates: coords, count: coords.count)
        blueOverlays.append(pl)
        map.addOverlay(pl, level: .aboveLabels)
        emitStatus("Ruta lista. ¡A correr!")
        updateInstruction(for: nil)
    }

    private func applySegments(_ segments: [MKRoute]) {
        clearBlueOverlays()
        navSteps = segments.flatMap { $0.steps }; currentStepIndex = 0
        for r in segments { blueOverlays.append(r.polyline); map.addOverlay(r.polyline, level: .aboveLabels) }
    }

    private func requestRouteFollowingSuggestion(from src: CLLocationCoordinate2D? = nil) async {
        guard !isCalculatingRoute else { return }
        isCalculatingRoute = true
        defer { isCalculatingRoute = false }
        emitStatus("Calculando ruta…")
        let coords = option.geojson.coords2D
        guard !coords.isEmpty else { emitStatus("Ruta inválida"); return }
        // Sample proportionally to the route length (~6 anchors always): with a
        // fixed 2.5 km spacing a 5 km loop got only 2 unique anchors and Apple
        // collapsed the circle into a short out-and-back. Floor of 700 m keeps
        // the request count under MKDirections' throttle on short routes too.
        let totalM = routeLength(of: coords)
        let points = anchors(from: coords, every: max(700, totalM / 6))
        guard points.count >= 2 else { requestDirectRoute(from: src); return }
        var segments: [MKRoute] = []; let start = src ?? origin; var last = start
        do {
            for p in points { let r = try await calculate(from: last, to: p); segments.append(r); last = p }
            applySegments(segments); emitStatus("Ruta lista. ¡A correr!")
            announceIfNeeded(navSteps.first?.instructions.isEmpty == false ? Self.localizedInstruction(navSteps.first!.instructions) : "Comienzo")
            updateInstruction(for: nil)
        } catch { fallBackToSuggestedRoute() }
    }

    private func emitStatus(_ s: String) { onStatus(s) }

    // MARK: MKMapViewDelegate
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        // Zona de riesgo: círculo rojo translúcido con su radio de influencia.
        if let circle = overlay as? MKCircle {
            let r = MKCircleRenderer(circle: circle)
            r.fillColor   = UIColor(Color.fnSecondary).withAlphaComponent(0.18)
            r.strokeColor = UIColor(Color.fnSecondary).withAlphaComponent(0.65)
            r.lineWidth   = 1.5
            return r
        }
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

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Ubicación propia: flecha de navegación (no el punto azul). Como la
        // cámara rota hacia el rumbo, la flecha apunta siempre "hacia adelante"
        // en pantalla, igual que en un GPS de auto.
        if annotation is MKUserLocation {
            let id = "userArrow"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.image = Self.navigationArrowImage()
            view.canShowCallout = false
            view.displayPriority = .required
            return view
        }
        // Reporte de riesgo: pin rojo con ícono de alerta.
        if let hz = annotation as? HazardAnnotation {
            let id = "hazard"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: hz, reuseIdentifier: id)
            view.annotation = hz
            view.markerTintColor = UIColor(Color.fnSecondary)
            view.glyphImage = UIImage(systemName: Self.hazardGlyph(hz.kind))
            view.canShowCallout = true
            view.displayPriority = .required
            return view
        }
        // Pin de "Salida y meta" como banderita verde.
        guard annotation is MKPointAnnotation else { return nil }
        let id = "startFinish"
        let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
        view.annotation = annotation
        view.markerTintColor = UIColor(Color.fnGreen)
        view.glyphImage = UIImage(systemName: "flag.checkered")
        view.canShowCallout = true
        return view
    }

    static func hazardGlyph(_ type: String) -> String {
        switch type {
        case "iluminacion": return "lightbulb.slash.fill"
        case "vereda_rota": return "road.lanes"
        case "obra":        return "cone.fill"
        default:            return "exclamationmark.triangle.fill"
        }
    }

    // Flecha de navegación (puck) que reemplaza al punto azul: círculo cian con
    // borde blanco y una punta de flecha apuntando hacia arriba (el sentido de
    // avance, porque la cámara ya rota hacia el rumbo). Se dibuja por código para
    // no depender de un asset.
    static func navigationArrowImage() -> UIImage {
        let size = CGSize(width: 36, height: 36)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let outer = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            // sombra suave
            c.setShadow(offset: CGSize(width: 0, height: 1), blur: 3,
                        color: UIColor.black.withAlphaComponent(0.35).cgColor)
            c.setFillColor(UIColor.white.cgColor)
            c.fillEllipse(in: outer)
            c.setShadow(offset: .zero, blur: 0, color: nil)
            // disco cian interior
            c.setFillColor(UIColor(Color.fnCyan).cgColor)
            c.fillEllipse(in: outer.insetBy(dx: 3, dy: 3))
            // punta de flecha blanca hacia arriba
            let cx = size.width / 2
            let p = UIBezierPath()
            p.move(to: CGPoint(x: cx, y: 9))
            p.addLine(to: CGPoint(x: cx + 7.5, y: 25))
            p.addLine(to: CGPoint(x: cx, y: 20.5))
            p.addLine(to: CGPoint(x: cx - 7.5, y: 25))
            p.close()
            UIColor.white.setFill()
            p.fill()
        }
    }

    // MARK: CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        onLocation?(loc)
        HazardService.shared.refreshIfNeeded(around: loc.coordinate)
        if followUser { updateCamera(to: loc) }
        updateInstruction(for: loc)
        // Recalcular SOLO si: no hay otro cálculo en curso, pasaron 30 s del
        // último, y te estás moviendo de verdad (el GPS parado hace "saltar"
        // la posición y dispararía recálculos en loop).
        if isOffCompositeRoute(current: loc, threshold: userPrefs.rerouteDistanceMeters),
           !isCalculatingRoute,
           Date().timeIntervalSince(lastRerouteAt) > 30,
           loc.speed >= 1 {
            lastRerouteAt = Date()
            emitStatus("Desvío detectado. Recalculando…")
            Task { await requestRouteFollowingSuggestion(from: loc.coordinate) }
        }
        // Aviso de zona riesgosa: solo con una lectura confiable (con GPS
        // impreciso la distancia "salta" y marcaría cualquier cosa), redondeado
        // a 10 m y sin repetir el mismo aviso en cada actualización.
        updateHazardWarning(around: loc)
    }

    private func updateHazardWarning(around loc: CLLocation) {
        guard loc.horizontalAccuracy > 0, loc.horizontalAccuracy <= 30 else { return }
        // Radio de los indicadores de borde. Es mucho más ancho que el del aviso
        // hablado a propósito: querés ver la zona venir desde lejos y que el
        // contador baje metro a metro, no enterarte a 80 m.
        let nearby = HazardService.shared.nearbyHazards(to: loc.coordinate, within: 300)
        onHazards?(nearby.map { item in
            NearbyHazard(id: item.hazard.id,
                         type: item.hazard.type,
                         // Sin redondear a decenas: así el número corre 101, 100, 99…
                         distance: Int(item.distance.rounded()),
                         severity: item.hazard.severity ?? 2,
                         bearing: Self.relativeBearing(from: loc.coordinate,
                                                       to: item.hazard.center,
                                                       cameraHeading: map?.camera.heading ?? lastHeading))
        })
        // El aviso hablado y el texto de estado siguen usando el umbral corto:
        // avisar por voz a 300 m sería ruido constante.
        let status: String?
        if let closest = nearby.first, closest.distance <= 80 {
            let rounded = Int((closest.distance / 10).rounded()) * 10
            status = "Advertencia: zona riesgosa a \(rounded) m"
        } else {
            status = nil
        }
        guard status != lastHazardStatus else { return }
        lastHazardStatus = status
        if let s = status { emitStatus(s) }
        else { emitStatus("Ruta despejada. ¡A correr!") }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        emitStatus("Error de GPS: \(error.localizedDescription)")
    }

    private func updateInstruction(for current: CLLocation?) {
        guard !navSteps.isEmpty else { return }
        let index = nearestStepIndex(to: current?.coordinate)
        if index != currentStepIndex {
            currentStepIndex = index
            let raw = navSteps[index].instructions
            let instr = raw.isEmpty ? "Seguí recto" : Self.localizedInstruction(raw)
            announceIfNeeded(instr)
        }
        let step = navSteps[currentStepIndex]
        let remaining = remainingDistance(on: step, from: current?.coordinate) ?? step.distance
        onStep(step.instructions.isEmpty ? "Seguí recto" : Self.localizedInstruction(step.instructions), remaining)
    }

    /// Red de seguridad del idioma. Con `CFBundleLocalizations` en es-419 MapKit
    /// devuelve las indicaciones en castellano, pero si el dispositivo fuerza
    /// otro idioma igual llegan en inglés. Acá se traducen las formas que usa
    /// MapKit; si el texto ya viene en castellano no se toca nada.
    static func localizedInstruction(_ text: String) -> String {
        guard text.range(of: #"\b(turn|onto|Head|Continue|Proceed|Keep|Cross|Arrive|exit|road)\b"#,
                         options: [.regularExpression, .caseInsensitive]) != nil else { return text }
        var out = text
        let table: [(String, String)] = [
            ("At the end of the road, ", "Al final de la calle, "),
            ("Cross the street and ", "Cruzá la calle y "),
            ("Make a U-turn", "Hacé un giro en U"),
            ("Slight left", "Doblá levemente a la izquierda"),
            ("Slight right", "Doblá levemente a la derecha"),
            ("Sharp left", "Doblá cerrado a la izquierda"),
            ("Sharp right", "Doblá cerrado a la derecha"),
            ("Turn left", "Doblá a la izquierda"),
            ("Turn right", "Doblá a la derecha"),
            ("turn left", "doblá a la izquierda"),
            ("turn right", "doblá a la derecha"),
            ("Keep left", "Mantenete a la izquierda"),
            ("Keep right", "Mantenete a la derecha"),
            ("Continue", "Seguí"),
            ("Proceed to", "Seguí hasta"),
            ("Arrive at", "Llegás a"),
            ("Head north", "Andá hacia el norte"),
            ("Head south", "Andá hacia el sur"),
            ("Head east", "Andá hacia el este"),
            ("Head west", "Andá hacia el oeste"),
            (" onto ", " por "),
            (" on ", " por "),
            (" toward ", " hacia "),
            ("Your destination", "Tu destino"),
            ("is on the left", "queda a la izquierda"),
            ("is on the right", "queda a la derecha"),
        ]
        for (en, es) in table { out = out.replacingOccurrences(of: en, with: es) }
        return out
    }

    /// Rumbo hacia la zona medido desde hacia dónde mira la cámara, en grados
    /// 0..360 (0 = justo adelante, 90 = a la derecha). Con la cámara en modo
    /// seguimiento el mapa rota con vos, así que este ángulo es el que hay que
    /// usar para pegar el indicador contra el borde correcto de la pantalla.
    static func relativeBearing(from: CLLocationCoordinate2D,
                                to: CLLocationCoordinate2D,
                                cameraHeading: CLLocationDirection) -> Double {
        let lat1 = from.latitude * .pi / 180, lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let absolute = atan2(y, x) * 180 / .pi
        let rel = (absolute - cameraHeading).truncatingRemainder(dividingBy: 360)
        return rel < 0 ? rel + 360 : rel
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Post-run AI analysis sheet
// ─────────────────────────────────────────────────────────────────────────────

struct RunAnalysisSheet: View {
    @ObservedObject var tracker: RunSessionTracker
    let onDone: () -> Void

    var body: some View {
        NavigationView {
            Group {
                if let a = tracker.analysis {
                    content(a)
                } else if tracker.analyzing {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Analizando tu corrida…").foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run").font(.system(size: 44)).foregroundColor(.secondary)
                        Text("¡Corrida guardada!").font(.headline)
                        Text("No pudimos generar el análisis esta vez.")
                            .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Análisis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { onDone() }
                }
            }
        }
    }

    private func content(_ a: RunAnalysis) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(a.headline).font(.title3.bold())
                        if a.isDemo {
                            Text("DEMO").font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange).clipShape(Capsule())
                        }
                    }
                    Text(a.summary).font(.subheadline).foregroundColor(.secondary)
                }

                if let m = a.metrics {
                    HStack(spacing: 12) {
                        metric("Distancia", m.distance_km.map { "\($0) km" } ?? "—")
                        metric("Tiempo", m.duration_min.map { "\(Int($0)) min" } ?? "—")
                        metric("Ritmo", m.pace_label ?? "—")
                    }
                }

                section("Ritmo", [a.pace_assessment])
                section("Fortalezas", a.strengths, symbol: "checkmark.circle.fill", tint: .green)
                section("A mejorar", a.improvements, symbol: "arrow.up.circle.fill", tint: .blue)
                section("Recomendación", [a.recommendation])

                VStack(alignment: .leading, spacing: 4) {
                    Text("Próxima corrida").font(.headline)
                    Text("\(Int(a.next_run.distance_km)) km · \(a.next_run.focus)")
                        .font(.subheadline).foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func section(_ title: String, _ items: [String], symbol: String? = nil, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    if let symbol = symbol {
                        Image(systemName: symbol).foregroundColor(tint).font(.subheadline)
                    }
                    Text(item).font(.subheadline)
                }
            }
        }
    }
}

// Anotación de una zona de riesgo en el mapa (pin rojo). Guarda el tipo para
// elegir el ícono y distinguirla del pin verde de salida y meta.
final class HazardAnnotation: MKPointAnnotation {
    let kind: String
    init(kind: String) { self.kind = kind; super.init() }
}
