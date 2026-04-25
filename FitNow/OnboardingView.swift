import SwiftUI
import CoreLocation
import UserNotifications

// MARK: - OnboardingView

struct OnboardingView: View {
    @EnvironmentObject private var auth: AuthViewModel
    var onComplete: () -> Void

    @State private var step = 0
    @State private var appeared = false

    // Step 1 — Permisos
    @State private var locationGranted     = false
    @State private var notifGranted        = false

    // Step 2 — Objetivos
    @State private var selectedGoals:  Set<FitnessGoal> = []

    // Step 3 — Nivel
    @State private var selectedLevel: FitnessLevel = .beginner

    // Step 4 — FitNow+
    @State private var startTrial = false

    private let totalSteps = 4

    var body: some View {
        ZStack {
            Color.fnBg.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                TabView(selection: $step) {
                    permissionsStep.tag(0)
                    goalsStep.tag(1)
                    levelStep.tag(2)
                    plusStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.82), value: step)

                navigationBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { appeared = true }
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.fnBlue : Color.fnBorder)
                    .frame(height: 3)
                    .animation(.spring(response: 0.4), value: step)
            }
        }
    }

    // MARK: - Navigation bar

    private var navigationBar: some View {
        HStack {
            if step > 0 {
                Button { withAnimation { step -= 1 } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.fnSlate)
                        .padding(12)
                        .background(Color.fnElevated, in: Circle())
                }
            } else {
                Spacer()
            }

            Spacer()

            if step < totalSteps - 1 {
                Button { advanceStep() } label: {
                    HStack(spacing: 6) {
                        Text("Continuar")
                            .font(.system(size: 16, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.fnBlue, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Button { finish() } label: {
                    HStack(spacing: 6) {
                        Text(startTrial ? "Iniciar prueba gratis" : "Empezar")
                            .font(.system(size: 16, weight: .bold))
                        Image(systemName: startTrial ? "star.fill" : "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(startTrial ? FNGradient.provider : FNGradient.primary,
                                in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    // MARK: - Step 1: Permisos

    private var permissionsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                stepHeader(
                    emoji: "🔓",
                    title: "Configurá FitNow",
                    subtitle: "Necesitamos algunos permisos para darte la mejor experiencia"
                )

                VStack(spacing: 12) {
                    permissionRow(
                        icon: "location.fill",
                        color: .fnBlue,
                        title: "Ubicación",
                        description: "Para mostrarte actividades cercanas y rastrear tus rutas",
                        isGranted: locationGranted
                    ) {
                        requestLocation()
                    }

                    permissionRow(
                        icon: "bell.fill",
                        color: .fnAmber,
                        title: "Notificaciones",
                        description: "Recordatorios de clases, confirmaciones de pago y mensajes",
                        isGranted: notifGranted
                    ) {
                        requestNotifications()
                    }

                    permissionRow(
                        icon: "heart.fill",
                        color: .fnCrimson,
                        title: "HealthKit",
                        description: "Registrar tus entrenamientos en Apple Health (opcional)",
                        isGranted: false,
                        isOptional: true
                    ) {
                        // HealthKit requested in RunNavigator when first run starts
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
    }

    // MARK: - Step 2: Objetivos

    private var goalsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                stepHeader(
                    emoji: "🎯",
                    title: "¿Cuáles son tus objetivos?",
                    subtitle: "Seleccioná todos los que apliquen — te sugeriremos actividades a medida"
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        goalCard(goal)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
    }

    private func goalCard(_ goal: FitnessGoal) -> some View {
        let selected = selectedGoals.contains(goal)
        return Button {
            withAnimation(.spring(response: 0.3)) {
                if selected { selectedGoals.remove(goal) }
                else        { selectedGoals.insert(goal) }
            }
        } label: {
            VStack(spacing: 10) {
                Text(goal.emoji)
                    .font(.system(size: 32))
                Text(goal.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(selected ? .fnWhite : .fnSlate)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected ? Color.fnBlue.opacity(0.18) : Color.fnElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selected ? Color.fnBlue : Color.fnBorder,
                                    lineWidth: selected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Step 3: Nivel

    private var levelStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                stepHeader(
                    emoji: "⚡️",
                    title: "¿Cuál es tu nivel?",
                    subtitle: "Usamos esto para recomendarte actividades con la dificultad correcta"
                )

                VStack(spacing: 10) {
                    ForEach(FitnessLevel.allCases, id: \.self) { level in
                        levelRow(level)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
    }

    private func levelRow(_ level: FitnessLevel) -> some View {
        let selected = selectedLevel == level
        return Button { withAnimation(.spring(response: 0.3)) { selectedLevel = level } } label: {
            HStack(spacing: 16) {
                Text(level.emoji)
                    .font(.system(size: 28))
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(level.label)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(selected ? .fnWhite : .fnSlate)
                    Text(level.description)
                        .font(.system(size: 13))
                        .foregroundColor(.fnSlate)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.fnBlue)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected ? Color.fnBlue.opacity(0.12) : Color.fnElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selected ? Color.fnBlue : Color.fnBorder,
                                    lineWidth: selected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Step 4: FitNow+

    private var plusStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                stepHeader(
                    emoji: "⭐️",
                    title: "Probá FitNow+ gratis",
                    subtitle: "7 días sin compromiso, cancelás cuando quieras"
                )

                plusBenefitsCard

                VStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.3)) { startTrial = true }
                    } label: {
                        HStack {
                            Spacer()
                            Text(startTrial ? "✓ Prueba activada" : "Activar prueba gratis — 7 días")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(startTrial ? Color.fnGreen : FNGradient.provider,
                                    in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .animation(.spring(response: 0.4), value: startTrial)

                    Text("Después, $4.99/mes. Sin cargo hasta el día 8.")
                        .font(.system(size: 12))
                        .foregroundColor(.fnAsh)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
    }

    private var plusBenefitsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach([
                ("star.fill", Color.fnAmber, "Sin publicidad", "Experiencia limpia y sin interrupciones"),
                ("chart.line.uptrend.xyaxis", Color.fnBlue, "Analytics avanzado", "Splits, pace, HRV y datos de entrenamiento"),
                ("brain.head.profile", Color.fnPurple, "Coach IA sin límites", "Planes personalizados con contexto biométrico"),
                ("percent", Color.fnGreen, "Descuentos exclusivos", "Hasta 20% off en actividades seleccionadas"),
            ], id: \.2) { icon, color, title, desc in
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(color.opacity(0.14)).frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(.fnWhite)
                        Text(desc).font(.system(size: 12)).foregroundColor(.fnSlate)
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                if title != "Descuentos exclusivos" {
                    Divider().background(Color.fnBorder).padding(.leading, 66)
                }
            }
        }
        .background(Color.fnElevated, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.fnBorder, lineWidth: 1))
    }

    // MARK: - Shared helpers

    @ViewBuilder
    private func stepHeader(emoji: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(emoji).font(.system(size: 44))
            Text(title)
                .font(.custom("DM Serif Display", size: 28))
                .foregroundColor(.fnWhite)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundColor(.fnSlate)
        }
    }

    @ViewBuilder
    private func permissionRow(icon: String, color: Color, title: String, description: String,
                               isGranted: Bool, isOptional: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: isGranted ? {} : action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.fnWhite)
                        if isOptional {
                            Text("opcional")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.fnSlate)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.fnBorder, in: Capsule())
                        }
                    }
                    Text(description).font(.system(size: 13)).foregroundColor(.fnSlate)
                }
                Spacer()
                Image(systemName: isGranted ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: isGranted ? 20 : 14))
                    .foregroundColor(isGranted ? .fnGreen : .fnAsh)
            }
            .padding(16)
            .background(Color.fnElevated, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isGranted ? Color.fnGreen.opacity(0.4) : Color.fnBorder, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isGranted || isOptional)
    }

    // MARK: - Actions

    private func advanceStep() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { step += 1 }
    }

    private func finish() {
        saveOnboardingData()
        onComplete()
    }

    private func saveOnboardingData() {
        UserDefaults.standard.set(true, forKey: "fn_onboarding_done")
        UserDefaults.standard.set(selectedLevel.rawValue, forKey: "fn_fitness_level")
        UserDefaults.standard.set(
            Array(selectedGoals.map { $0.rawValue }),
            forKey: "fn_fitness_goals"
        )
        if startTrial {
            // POST /payments/trial/start handled by backend on next API call
            UserDefaults.standard.set(true, forKey: "fn_trial_requested")
        }
    }

    private func requestLocation() {
        let mgr = CLLocationManager()
        mgr.requestWhenInUseAuthorization()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            locationGranted = mgr.authorizationStatus == .authorizedWhenInUse ||
                              mgr.authorizationStatus == .authorizedAlways
        }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async { notifGranted = granted }
        }
    }
}

// MARK: - Fitness models

enum FitnessGoal: String, CaseIterable {
    case strength   = "strength"
    case running    = "running"
    case flexibility = "flexibility"
    case weightLoss  = "weight_loss"
    case endurance   = "endurance"
    case sports      = "sports"
    case wellness    = "wellness"
    case social      = "social"

    var emoji: String {
        switch self {
        case .strength:    return "💪"
        case .running:     return "🏃"
        case .flexibility: return "🧘"
        case .weightLoss:  return "🔥"
        case .endurance:   return "🚴"
        case .sports:      return "⚽️"
        case .wellness:    return "🌿"
        case .social:      return "👥"
        }
    }

    var label: String {
        switch self {
        case .strength:    return "Fuerza"
        case .running:     return "Running"
        case .flexibility: return "Flexibilidad"
        case .weightLoss:  return "Bajar de peso"
        case .endurance:   return "Resistencia"
        case .sports:      return "Deportes"
        case .wellness:    return "Bienestar"
        case .social:      return "Socializar"
        }
    }
}

enum FitnessLevel: String, CaseIterable {
    case beginner     = "beginner"
    case intermediate = "intermediate"
    case advanced     = "advanced"
    case elite        = "elite"

    var emoji: String {
        switch self {
        case .beginner:     return "🌱"
        case .intermediate: return "💪"
        case .advanced:     return "🔥"
        case .elite:        return "⚡️"
        }
    }

    var label: String {
        switch self {
        case .beginner:     return "Principiante"
        case .intermediate: return "Intermedio"
        case .advanced:     return "Avanzado"
        case .elite:        return "Elite"
        }
    }

    var description: String {
        switch self {
        case .beginner:     return "Empezando a hacer actividad física"
        case .intermediate: return "Entreno regularmente, 2-4 días por semana"
        case .advanced:     return "Entreno intensamente, 4-6 días por semana"
        case .elite:        return "Atleta de alto rendimiento o competitivo"
        }
    }
}
