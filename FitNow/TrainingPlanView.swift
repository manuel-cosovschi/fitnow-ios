import SwiftUI
import Combine

// MARK: - Training Plan ViewModel

final class TrainingPlanViewModel: ObservableObject {
    @Published var plans: [TrainingPlan] = []
    @Published var activePlan: TrainingPlan?
    @Published var loading = false
    @Published var generating = false
    @Published var error: String?

    private var bag = Set<AnyCancellable>()

    func loadPlans() {
        loading = true; error = nil
        APIClient.shared.request("training-plans", authorized: true)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: TrainingPlansList) in
                self?.plans = resp.items
            }
            .store(in: &bag)
    }

    func loadActive() {
        APIClient.shared.request("training-plans/active", authorized: true)
            .sink { _ in }
            receiveValue: { [weak self] (plan: TrainingPlan) in
                self?.activePlan = plan
            }
            .store(in: &bag)
    }

    func generate(goal: String, durationWeeks: Int, difficulty: String, completion: @escaping (TrainingPlan?) -> Void) {
        generating = true; error = nil
        let payload: [String: Any] = ["goal": goal, "duration_weeks": durationWeeks, "difficulty": difficulty]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }

        APIClient.shared.request("training-plans/generate", method: "POST", body: data, authorized: true)
            .sink { [weak self] comp in
                self?.generating = false
                if case .failure(let e) = comp { self?.error = e.localizedDescription; completion(nil) }
            } receiveValue: { [weak self] (plan: TrainingPlan) in
                self?.activePlan = plan
                self?.loadPlans()
                completion(plan)
            }
            .store(in: &bag)
    }

    func cancel(planId: Int) {
        APIClient.shared.request("training-plans/\(planId)/cancel", method: "PATCH", authorized: true)
            .sink { _ in }
            receiveValue: { [weak self] (_: TrainingPlan) in
                self?.activePlan = nil
                self?.loadPlans()
            }
            .store(in: &bag)
    }
}

// MARK: - Training Plan Hub View

struct TrainingPlanHubView: View {
    @StateObject private var vm = TrainingPlanViewModel()
    @State private var showGenerate = false
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                generateCTA
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if let active = vm.activePlan {
                    activePlanCard(active)
                        .padding(.horizontal, 16)
                }

                historySection
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color.fnBg)
        .navigationTitle("Planes de entrenamiento")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showGenerate) {
            NavigationStack {
                GeneratePlanView(vm: vm, onCreated: { showGenerate = false })
            }
        }
        .onAppear {
            vm.loadPlans()
            vm.loadActive()
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
    }

    // MARK: - CTA

    private var generateCTA: some View {
        Button { showGenerate = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.20)).frame(width: 56, height: 56)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generar plan con IA")
                        .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    Text("Plan semanal personalizado para tu objetivo")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 24)).foregroundColor(.white.opacity(0.7))
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 22).fill(FNGradient.trainer))
            .fnShadowColored(.fnPrimary)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Active Plan

    private func activePlanCard(_ plan: TrainingPlan) -> some View {
        NavigationLink(destination: TrainingPlanDetailView(planId: plan.id, vm: vm)) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(FNGradient.success).frame(width: 46, height: 46)
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Plan activo").font(.system(size: 12, weight: .bold))
                        .foregroundColor(.fnGreen).padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.fnGreen.opacity(0.12), in: Capsule())
                    Text(plan.title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                    Text("\(plan.duration_weeks) semanas • \(plan.goal)")
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

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mis planes").font(.system(size: 20, weight: .bold, design: .rounded))

            if vm.loading && vm.plans.isEmpty {
                VStack(spacing: 10) { ForEach(0..<3, id: \.self) { _ in SkeletonView(cornerRadius: 16).frame(height: 70) } }
            } else if vm.plans.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text").font(.system(size: 36)).foregroundColor(.fnSlate.opacity(0.7))
                    Text("Sin planes aún").font(.system(size: 15, weight: .semibold)).foregroundColor(.secondary)
                    Text("Generá tu primer plan de entrenamiento personalizado con IA.")
                        .font(.system(size: 13)).foregroundColor(.fnSlate.opacity(0.7)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(30)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.fnSurface))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(vm.plans.prefix(20).enumerated()), id: \.element.id) { index, plan in
                        NavigationLink(destination: TrainingPlanDetailView(planId: plan.id, vm: vm)) {
                            planRow(plan)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.spring(response: 0.45).delay(Double(index) * 0.06), value: appeared)
                    }
                }
            }
        }
    }

    private func planRow(_ plan: TrainingPlan) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(plan.status == "active" ? FNGradient.success : FNGradient.dark)
                    .frame(width: 46, height: 46)
                Image(systemName: "doc.text.fill").font(.system(size: 20)).foregroundColor(plan.status == "active" ? .white : .secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title).font(.system(size: 14, weight: .bold)).lineLimit(1).foregroundColor(.primary)
                Text("\(plan.duration_weeks) semanas • \(plan.difficulty?.capitalized ?? "Media")")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            Spacer()
            statusBadge(plan.status ?? "active")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.fnSurface))
        .fnShadow(radius: 6, y: 2)
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status == "active" ? "Activo" : status == "completed" ? "Completado" : "Cancelado")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(status == "active" ? .fnGreen : .secondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((status == "active" ? Color.fnGreen : Color.secondary).opacity(0.12), in: Capsule())
    }
}

// MARK: - Generate Plan View

struct GeneratePlanView: View {
    @ObservedObject var vm: TrainingPlanViewModel
    var onCreated: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var goal = ""
    @State private var durationWeeks = 4
    @State private var difficulty = "media"

    private let durationOptions = [1, 2, 4, 8, 12, 16, 24]
    private let difficultyOptions = ["baja", "media", "alta"]

    var body: some View {
        Form {
            Section("Objetivo") {
                TextField("Ej: Correr mi primer 10K, ganar masa muscular...", text: $goal, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Duración") {
                Picker("Semanas", selection: $durationWeeks) {
                    ForEach(durationOptions, id: \.self) { w in Text("\(w) sem").tag(w) }
                }
                .pickerStyle(.segmented)
            }

            Section("Dificultad") {
                Picker("Nivel", selection: $difficulty) {
                    Text("Baja").tag("baja")
                    Text("Media").tag("media")
                    Text("Alta").tag("alta")
                }
                .pickerStyle(.segmented)
            }

            if let error = vm.error {
                Section { Text(error).foregroundColor(.fnSecondary).font(.system(size: 13)) }
            }

            Section {
                Button {
                    vm.generate(goal: goal, durationWeeks: durationWeeks, difficulty: difficulty) { plan in
                        if plan != nil { onCreated() }
                    }
                } label: {
                    if vm.generating {
                        HStack(spacing: 10) {
                            Spacer()
                            ProgressView()
                            Text("Generando con IA...").font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                    } else {
                        HStack { Spacer(); Text("Generar plan").font(.system(size: 16, weight: .bold)); Spacer() }
                    }
                }
                .disabled(goal.isEmpty || vm.generating)
            }
        }
        .navigationTitle("Nuevo plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
        }
    }
}

// MARK: - Training Plan Detail View

struct TrainingPlanDetailView: View {
    let planId: Int
    @ObservedObject var vm: TrainingPlanViewModel
    @State private var plan: TrainingPlan?
    @State private var loading = true
    @State private var showCancelConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if loading {
                    ProgressView().padding(40)
                } else if let plan {
                    planHeader(plan)

                    if let data = plan.plan_data {
                        if let summary = data.summary {
                            Text(summary).font(.system(size: 14)).foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                        }

                        if let weeks = data.weeks {
                            ForEach(weeks) { week in
                                weekSection(week)
                            }
                        }

                        if let tips = data.tips, !tips.isEmpty {
                            tipsSection(tips)
                        }
                    }

                    if plan.status == "active" {
                        Button(role: .destructive) { showCancelConfirm = true } label: {
                            Text("Cancelar plan")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity).padding(14)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cancelar plan", isPresented: $showCancelConfirm) {
            Button("Cancelar plan", role: .destructive) {
                vm.cancel(planId: planId)
                dismiss()
            }
            Button("Volver", role: .cancel) {}
        } message: {
            Text("¿Estás seguro de que querés cancelar este plan?")
        }
        .onAppear { loadPlan() }
    }

    private func planHeader(_ plan: TrainingPlan) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(FNGradient.trainer).frame(width: 60, height: 60)
                Image(systemName: "doc.text.fill").font(.system(size: 26, weight: .bold)).foregroundColor(.white)
            }
            .fnShadowBrand()
            Text(plan.title).font(.custom(\"DM Serif Display\", size: 22)).multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Label("\(plan.duration_weeks) semanas", systemImage: "calendar").font(.system(size: 13)).foregroundColor(.secondary)
                Label(plan.difficulty?.capitalized ?? "Media", systemImage: "speedometer").font(.system(size: 13)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func weekSection(_ week: PlanWeek) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Semana \(week.week)")
                    .font(.system(size: 16, weight: .bold))
                if let focus = week.focus {
                    Text("— \(focus)")
                        .font(.system(size: 14)).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)

            if let days = week.days {
                ForEach(days) { day in
                    dayCard(day)
                }
            }
        }
    }

    private func dayCard(_ day: PlanDay) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(dayColor(day.type ?? "rest").opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: dayIcon(day.type ?? "rest"))
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(dayColor(day.type ?? "rest"))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Día \(day.day)").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                    Text(day.title ?? "").font(.system(size: 14, weight: .semibold))
                }
                if let desc = day.description { Text(desc).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(2) }
                HStack(spacing: 8) {
                    if let dur = day.duration_min { Label("\(dur) min", systemImage: "clock").font(.system(size: 11)).foregroundColor(.secondary) }
                    if let dist = day.distance_km { Label(String(format: "%.1f km", dist), systemImage: "map").font(.system(size: 11)).foregroundColor(.secondary) }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.fnSurface))
        .padding(.horizontal, 16)
    }

    private func tipsSection(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Consejos").font(.system(size: 16, weight: .bold)).padding(.horizontal, 16)
            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill").foregroundColor(.fnYellow).font(.system(size: 13))
                    Text(tip).font(.system(size: 13)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func dayIcon(_ type: String) -> String {
        switch type {
        case "running": return "figure.run"
        case "gym":     return "dumbbell.fill"
        case "rest":    return "moon.fill"
        default:        return "circle.fill"
        }
    }

    private func dayColor(_ type: String) -> Color {
        switch type {
        case "running": return .fnCyan
        case "gym":     return .fnPurple
        case "rest":    return .fnGreen
        default:        return .secondary
        }
    }

    private func loadPlan() {
        loading = true
        var bag = Set<AnyCancellable>()
        APIClient.shared.request("training-plans/\(planId)", authorized: true)
            .sink { _ in loading = false }
            receiveValue: { [self] (p: TrainingPlan) in plan = p; loading = false }
            .store(in: &bag)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { _ = bag }
    }
}
