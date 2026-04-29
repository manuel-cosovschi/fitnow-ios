import SwiftUI
import Combine

// MARK: - Gym Hub ViewModel

final class GymHubViewModel: ObservableObject {
    @Published var sessions: [GymSession] = []
    @Published var activeSession: GymSession?
    @Published var loading = false
    @Published var error: String?

    private var bag = Set<AnyCancellable>()

    func fetch() {
        loading = true; error = nil
        APIClient.shared.request("gym/sessions/mine", authorized: true)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: GymSessionsList) in
                self?.sessions = resp.items
                self?.activeSession = resp.items.first(where: { $0.status == "active" })
            }
            .store(in: &bag)
    }
}

// MARK: - Gym Hub View

struct GymHubView: View {
    @StateObject private var vm = GymHubViewModel()
    @State private var appeared = false
    @State private var showNewSession = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                gymCTA
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if let active = vm.activeSession {
                    activeSessionBanner(active)
                        .padding(.horizontal, 16)
                }

                if !vm.sessions.isEmpty {
                    gymStatsSummary
                        .padding(.horizontal, 16)
                }

                historySection
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color.fnBg)
        .navigationTitle("Gimnasio")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showNewSession) {
            NavigationStack { StartGymSessionView(onComplete: { vm.fetch() }) }
        }
        .onAppear {
            vm.fetch()
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
    }

    // MARK: - CTA

    private var gymCTA: some View {
        Button { showNewSession = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.20)).frame(width: 56, height: 56)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Iniciar sesión de gym")
                        .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    Text("La IA crea tu rutina personalizada")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24)).foregroundColor(.white.opacity(0.7))
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 22).fill(FNGradient.gym))
            .fnShadowColored(.fnCyan)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func activeSessionBanner(_ session: GymSession) -> some View {
        NavigationLink(destination: GymActiveSessionView(sessionId: session.id)) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(FNGradient.success).frame(width: 46, height: 46)
                    Image(systemName: "play.fill").font(.system(size: 20)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sesión activa").font(.system(size: 15, weight: .bold))
                    Text(session.goal ?? "Entrenamiento en curso")
                        .font(.system(size: 13)).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18).fill(Color.fnSurface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.fnGreen.opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Stats Summary

    private var gymStatsSummary: some View {
        let completed = vm.sessions.filter { $0.status == "completed" }
        let totalSets = completed.compactMap { $0.total_sets }.reduce(0, +)
        let totalVolume = completed.compactMap { $0.total_volume_kg }.reduce(0, +)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Tu progreso").font(.system(size: 20, weight: .bold, design: .rounded))
            HStack(spacing: 12) {
                StatCard(value: "\(completed.count)", label: "Sesiones", icon: "dumbbell.fill", color: .fnPurple)
                StatCard(value: "\(totalSets)", label: "Sets", icon: "bolt.fill", color: .fnCyan)
                StatCard(value: String(format: "%.0f kg", totalVolume), label: "Volumen", icon: "scalemass.fill", color: .fnYellow)
            }
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sesiones recientes").font(.system(size: 20, weight: .bold, design: .rounded))

            if vm.loading && vm.sessions.isEmpty {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in SkeletonView(cornerRadius: 16).frame(height: 80) }
                }
            } else if vm.sessions.filter({ $0.status == "completed" }).isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell").font(.system(size: 36)).foregroundColor(.fnSlate.opacity(0.7))
                    Text("Sin sesiones completadas").font(.system(size: 15, weight: .semibold)).foregroundColor(.secondary)
                    Text("Iniciá tu primera sesión de gym con IA.")
                        .font(.system(size: 13)).foregroundColor(.fnSlate.opacity(0.7)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(30)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.fnSurface))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(vm.sessions.filter({ $0.status == "completed" }).prefix(20).enumerated()), id: \.element.id) { index, session in
                        gymSessionCard(session)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(.spring(response: 0.45).delay(Double(index) * 0.06), value: appeared)
                    }
                }
            }
        }
    }

    private func gymSessionCard(_ session: GymSession) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(FNGradient.gym).frame(width: 46, height: 46)
                Image(systemName: "dumbbell.fill").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
            }
            .fnShadowColored(.fnCyan, radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.goal ?? "Sesión de gym").font(.system(size: 14, weight: .bold)).lineLimit(1)
                HStack(spacing: 10) {
                    if let sets = session.total_sets {
                        Label("\(sets) sets", systemImage: "bolt.fill").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    if let vol = session.total_volume_kg {
                        Label(String(format: "%.0f kg", vol), systemImage: "scalemass.fill").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    if let dur = session.duration_s {
                        Label("\(dur / 60) min", systemImage: "clock.fill").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(Color.fnSurface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.fnPurple.opacity(0.12), lineWidth: 1))
        )
        .fnShadow(radius: 8, y: 3)
    }
}

// MARK: - Start Gym Session View

struct StartGymSessionView: View {
    var onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var goal = ""
    @State private var timeAvailable = 45
    @State private var equipment = ""
    @State private var muscleGroups: [String] = []
    @State private var loading = false
    @State private var error: String?
    @State private var createdSessionId: Int?

    private let allMuscles = ["pecho", "espalda", "piernas", "hombros", "brazos", "core", "glúteos", "tríceps"]
    private let timeOptions = [15, 30, 45, 60, 90, 120]

    var body: some View {
        Form {
            Section("Objetivo") {
                TextField("Ej: Hipertrofia de tren superior", text: $goal)
            }

            Section("Tiempo disponible") {
                Picker("Minutos", selection: $timeAvailable) {
                    ForEach(timeOptions, id: \.self) { t in Text("\(t) min").tag(t) }
                }
                .pickerStyle(.segmented)
            }

            Section("Equipamiento disponible") {
                TextField("Ej: Barra, mancuernas, máquinas", text: $equipment)
            }

            Section("Grupos musculares") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(allMuscles, id: \.self) { muscle in
                        Button {
                            if muscleGroups.contains(muscle) {
                                muscleGroups.removeAll { $0 == muscle }
                            } else {
                                muscleGroups.append(muscle)
                            }
                        } label: {
                            Text(muscle.capitalized)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(muscleGroups.contains(muscle) ? .white : .primary)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(
                                    Capsule().fill(muscleGroups.contains(muscle) ? Color.fnPurple : Color.fnElevated)
                                )
                        }
                    }
                }
            }

            if let error {
                Section { Text(error).foregroundColor(.fnSecondary).font(.system(size: 13)) }
            }

            Section {
                Button {
                    startSession()
                } label: {
                    if loading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        HStack { Spacer(); Text("Generar rutina con IA").font(.system(size: 16, weight: .bold)); Spacer() }
                    }
                }
                .disabled(goal.isEmpty || muscleGroups.isEmpty || loading)
            }
        }
        .navigationTitle("Nueva sesión")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
        .navigationDestination(item: $createdSessionId) { sessionId in
            GymActiveSessionView(sessionId: sessionId)
        }
    }

    private func startSession() {
        loading = true; error = nil
        let payload: [String: Any] = [
            "goal": goal,
            "time_available_min": timeAvailable,
            "equipment_available": equipment,
            "muscle_groups": muscleGroups
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }

        Task { @MainActor in
            do {
                let session: GymSession = try await APIClient.shared.request(
                    "gym/sessions", method: "POST", body: data, authorized: true)
                loading = false; onComplete(); createdSessionId = session.id
            } catch {
                loading = false; self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - Active Session View

struct GymActiveSessionView: View {
    let sessionId: Int

    @State private var session: GymSession?
    @State private var sets: [GymSet] = []
    @State private var loading = true
    @State private var showReroute = false
    @State private var showFinishConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if loading {
                    ProgressView().padding(40)
                } else if let session {
                    sessionHeader(session)
                    if let plan = session.ai_plan {
                        planSection(plan)
                    }
                    setsSection
                    actionButtons(session)
                }
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Sesión activa")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReroute) {
            NavigationStack { RerouteSheet(sessionId: sessionId, onDone: { loadSession() }) }
        }
        .alert("Finalizar sesión", isPresented: $showFinishConfirm) {
            Button("Finalizar", role: .destructive) { finishSession() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("¿Querés terminar la sesión de gym?")
        }
        .onAppear { loadSession() }
    }

    private func sessionHeader(_ s: GymSession) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                StatCard(value: "\(s.total_sets ?? 0)", label: "Sets", icon: "bolt.fill", color: .fnPurple)
                StatCard(value: "\(s.total_reps ?? 0)", label: "Reps", icon: "repeat", color: .fnCyan)
                StatCard(value: String(format: "%.0f", s.total_volume_kg ?? 0), label: "Kg", icon: "scalemass.fill", color: .fnYellow)
            }
        }
        .padding(.horizontal, 16)
    }

    private func planSection(_ plan: AIPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let summary = plan.summary {
                Text(summary).font(.system(size: 14)).foregroundColor(.secondary).padding(.horizontal, 16)
            }
            if let warmup = plan.warmup {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill").foregroundColor(.fnYellow)
                    Text("Calentamiento: \(warmup)").font(.system(size: 13)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
            }

            if let exercises = plan.exercises {
                ForEach(exercises) { ex in
                    HStack(spacing: 12) {
                        Text("\(ex.order ?? 0)")
                            .font(.system(size: 12, weight: .heavy)).foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.fnPurple))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ex.name).font(.system(size: 14, weight: .semibold))
                            Text("\(ex.sets ?? 3)x\(ex.reps ?? 10) • \(Int(ex.suggested_weight_kg ?? 0))kg • \(ex.rest_seconds ?? 60)s descanso")
                                .font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var setsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sets completados").font(.system(size: 17, weight: .bold)).padding(.horizontal, 16)

            let completed = sets.filter { $0.completed == true }
            if completed.isEmpty {
                Text("Registrá tus sets a medida que los completes")
                    .font(.system(size: 13)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).padding(16)
            } else {
                ForEach(completed) { s in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.fnGreen)
                        Text(s.exercise_name).font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("\(s.actual_reps ?? 0)x\(String(format: "%.1f", s.actual_weight ?? 0))kg")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                        if let rpe = s.rpe {
                            Text("RPE \(rpe)").font(.system(size: 11, weight: .bold))
                                .foregroundColor(.fnYellow).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.fnYellow.opacity(0.15), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Log new set — simplified inline
            if session?.status == "active" {
                NavigationLink(destination: LogSetView(sessionId: sessionId, onDone: { loadSession() })) {
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundColor(.fnPurple)
                        Text("Registrar set").font(.system(size: 14, weight: .semibold)).foregroundColor(.fnPurple)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func actionButtons(_ s: GymSession) -> some View {
        VStack(spacing: 12) {
            if s.status == "active" {
                Button { showReroute = true } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                        Text("Modificar rutina (Reroute)")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.fnCyan)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).stroke(Color.fnCyan, lineWidth: 1.5))
                }

                Button { showFinishConfirm = true } label: {
                    Text("Finalizar sesión")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(FNGradient.success))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func loadSession() {
        loading = true
        Task { @MainActor in
            defer { loading = false }
            do {
                let s: GymSession = try await APIClient.shared.request(
                    "gym/sessions/\(sessionId)", authorized: true)
                session = s; sets = s.sets ?? []
            } catch { }
        }
    }

    private func finishSession() {
        Task { @MainActor in
            _ = try? await APIClient.shared.request(
                "gym/sessions/\(sessionId)/finish", method: "POST", authorized: true) as GymSession
            dismiss()
        }
    }
}

// MARK: - Log Set View

struct LogSetView: View {
    let sessionId: Int
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var exerciseName = ""
    @State private var setNumber = 1
    @State private var actualReps = 10
    @State private var actualWeight: Double = 20
    @State private var rpe = 7
    @State private var loading = false

    var body: some View {
        Form {
            Section("Ejercicio") {
                TextField("Nombre del ejercicio", text: $exerciseName)
            }
            Section("Detalles") {
                Stepper("Set #\(setNumber)", value: $setNumber, in: 1...50)
                Stepper("Reps: \(actualReps)", value: $actualReps, in: 0...200)
                HStack {
                    Text("Peso (kg)")
                    Spacer()
                    TextField("kg", value: $actualWeight, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                }
                Stepper("RPE: \(rpe)", value: $rpe, in: 1...10)
            }
            Section {
                Button {
                    logSet()
                } label: {
                    if loading { HStack { Spacer(); ProgressView(); Spacer() } }
                    else { HStack { Spacer(); Text("Registrar").font(.system(size: 16, weight: .bold)); Spacer() } }
                }
                .disabled(exerciseName.isEmpty || loading)
            }
        }
        .navigationTitle("Registrar set")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func logSet() {
        loading = true
        let payload: [String: Any] = [
            "exercise_name": exerciseName,
            "set_number": setNumber,
            "actual_reps": actualReps,
            "actual_weight": actualWeight,
            "rpe": rpe
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        Task { @MainActor in
            defer { loading = false }
            do {
                let _: GymSet = try await APIClient.shared.request(
                    "gym/sessions/\(sessionId)/sets", method: "POST", body: data, authorized: true)
                onDone(); dismiss()
            } catch { }
        }
    }
}

// MARK: - Reroute Sheet

struct RerouteSheet: View {
    let sessionId: Int
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var instruction = ""
    @State private var loading = false
    @State private var result: RerouteResponse?

    var body: some View {
        Form {
            Section("¿Qué querés cambiar?") {
                TextField("Ej: Me duele el hombro, el banco está ocupado...", text: $instruction, axis: .vertical)
                    .lineLimit(3...5)
            }

            if let result {
                Section("Ajustes realizados") {
                    if let r = result.reasoning { Text(r).font(.system(size: 13)).foregroundColor(.secondary) }
                    if let a = result.adjustments_made { Text(a).font(.system(size: 13, weight: .semibold)) }
                }
            }

            Section {
                Button {
                    reroute()
                } label: {
                    if loading { HStack { Spacer(); ProgressView(); Spacer() } }
                    else { HStack { Spacer(); Text("Modificar rutina").font(.system(size: 16, weight: .bold)); Spacer() } }
                }
                .disabled(instruction.isEmpty || loading)
            }
        }
        .navigationTitle("Reroute")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { onDone(); dismiss() } }
        }
    }

    private func reroute() {
        loading = true
        let payload = ["instruction": instruction]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        Task { @MainActor in
            defer { loading = false }
            do {
                result = try await APIClient.shared.request(
                    "gym/sessions/\(sessionId)/reroute", method: "POST", body: data, authorized: true)
            } catch { }
        }
    }
}
