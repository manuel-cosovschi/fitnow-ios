import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - EnrollmentFlowView
// Multi-step enrollment wizard shown as a sheet from ActivityDetailView.
// Steps vary by activity kind:
//   trainer / gym / club  → confirm → selectPlan → payment → success
//   club_sport            → confirm → payment → success
// ─────────────────────────────────────────────────────────────────────────────

struct EnrollmentFlowView: View {
    @Environment(\.dismiss) private var dismiss

    let activity: Activity
    var onEnrolled: (() -> Void)?

    @State private var step: FlowStep = .confirm
    @State private var selectedPlan: LocalPlan? = nil
    @State private var paymentChoice: PaymentChoice = .full
    @State private var paymentMethod: PaymentMethod = .card
    @State private var enrolling = false
    @State private var errorMessage: String? = nil
    @StateObject private var helper = EnrollHelper()

    // MARK: - Types

    enum FlowStep: Int {
        case confirm = 0, selectPlan = 1, payment = 2, success = 3

        var title: String {
            switch self {
            case .confirm:    return "Confirmá tu inscripción"
            case .selectPlan: return "Elegí tu plan"
            case .payment:    return "Forma de pago"
            case .success:    return "¡Listo!"
            }
        }
    }

    enum PaymentChoice { case full, deposit }
    enum PaymentMethod { case card, transfer }

    struct LocalPlan: Identifiable {
        var id: String { name }   // stable across re-renders; name is unique per plan
        let name: String
        let price: Double
        let description: String
        let isBestValue: Bool
    }

    // MARK: - Computed properties

    private var kind: String { activity.kind ?? "" }
    private var typeInfo: ActivityTypeInfo { ActivityTypeInfo.from(kind: kind) }

    private var showPlanStep: Bool { kind != "club_sport" }

    private var supportsDeposit: Bool {
        activity.enable_deposit ?? (kind == "trainer" || kind == "club_sport")
    }

    private var depositPercent: Int { activity.deposit_percent ?? 50 }

    private var noSeatsLeft: Bool {
        guard activity.has_capacity_limit ?? (kind == "club_sport") else { return false }
        return (activity.seats_left ?? 1) <= 0
    }

    private var plans: [LocalPlan] {
        let base = activity.price ?? 0
        guard base > 0 else { return [] }
        switch kind {
        case "trainer":
            return [
                LocalPlan(name: "Clase suelta",        price: base,            description: "Una clase individual",             isBestValue: false),
                LocalPlan(name: "Pack 4 clases",        price: base * 4 * 0.9,  description: "Ahorrás 10% pagando el pack",       isBestValue: false),
                LocalPlan(name: "Pack 8 clases",        price: base * 8 * 0.85, description: "Ahorrás 15% pagando el pack",       isBestValue: true),
                LocalPlan(name: "Mensual ilimitado",    price: base * 16 * 0.78,description: "Clases ilimitadas el mes completo", isBestValue: false),
            ]
        case "gym":
            return [
                LocalPlan(name: "Mensual",    price: base,             description: "Renovación mensual",   isBestValue: false),
                LocalPlan(name: "Trimestral", price: base * 3 * 0.90,  description: "Ahorrás 10%",          isBestValue: false),
                LocalPlan(name: "Semestral",  price: base * 6 * 0.85,  description: "Ahorrás 15%",          isBestValue: true),
                LocalPlan(name: "Anual",      price: base * 12 * 0.80, description: "Ahorrás 20%",          isBestValue: false),
            ]
        case "club":
            return [
                LocalPlan(name: "Socio básico",   price: base,        description: "Acceso a instalaciones y deportes básicos", isBestValue: false),
                LocalPlan(name: "Socio premium",  price: base * 1.5,  description: "Acceso total + eventos exclusivos",         isBestValue: true),
            ]
        default:
            return [LocalPlan(name: "Inscripción", price: base, description: "Inscripción a la actividad", isBestValue: false)]
        }
    }

    private var totalSteps: Int { showPlanStep ? 3 : 2 }

    private var currentStepNumber: Int {
        switch step {
        case .confirm:    return 1
        case .selectPlan: return 2
        case .payment:    return showPlanStep ? 3 : 2
        case .success:    return totalSteps
        }
    }

    private var finalPrice: Double {
        let base = selectedPlan?.price ?? activity.price ?? 0
        return paymentChoice == .deposit ? base * Double(depositPercent) / 100.0 : base
    }

    private var remainingPrice: Double {
        let base = selectedPlan?.price ?? activity.price ?? 0
        return paymentChoice == .deposit ? base - finalPrice : 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if step != .success {
                    progressHeader
                }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch step {
                        case .confirm:    confirmStep
                        case .selectPlan: selectPlanStep
                        case .payment:    paymentStep
                        case .success:    successStep
                        }
                    }
                    .padding(.bottom, 110)
                }
                if step != .success {
                    bottomAction
                }
            }
            .background(Color.fnBg)
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step != .success {
                        Button("Cancelar") { dismiss() }
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(1...totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentStepNumber ? typeInfo.color : Color.white.opacity(0.1))
                        .frame(height: 4)
                        .animation(.spring(response: 0.4), value: currentStepNumber)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            Text("Paso \(currentStepNumber) de \(totalSteps)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.fnSlate)
                .padding(.bottom, 6)
        }
    }

    // MARK: - Step 1: Confirm

    private var confirmStep: some View {
        VStack(spacing: 20) {
            // Activity summary
            ZStack(alignment: .bottom) {
                typeInfo.gradient
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                VStack(spacing: 10) {
                    Image(systemName: typeInfo.icon)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    Text(activity.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Info rows
            VStack(spacing: 8) {
                if let loc = activity.location, !loc.isEmpty {
                    infoRow(icon: "mappin.circle.fill", color: .fnSecondary, text: loc)
                }
                if let price = activity.price, price > 0 {
                    infoRow(icon: "creditcard.fill", color: .fnGreen,
                            text: showPlanStep ? "Desde $\(Int(price))" : "$\(Int(price))")
                }
                if let name = activity.provider_name, !name.isEmpty {
                    infoRow(icon: typeInfo.icon, color: typeInfo.color, text: name)
                }

                // Availability (when provider enables capacity limit)
                if activity.has_capacity_limit ?? (kind == "club_sport") {
                    let left = activity.seats_left ?? 0
                    HStack(spacing: 10) {
                        Image(systemName: left > 3 ? "person.2.fill" : "person.2.slash.fill")
                            .font(.system(size: 15))
                            .foregroundColor(left > 3 ? .fnGreen : (left > 0 ? .fnYellow : .fnSecondary))
                        Text(left == 0 ? "Sin cupos disponibles"
                             : "\(left) cupo\(left == 1 ? "" : "s") disponible\(left == 1 ? "" : "s")")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(left > 3 ? .fnGreen : (left > 0 ? .fnYellow : .fnSecondary))
                        Spacer()
                        if left == 0 {
                            Text("AGOTADO")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.fnSecondary, in: Capsule())
                        } else if left <= 3 {
                            Text("ÚLTIMOS LUGARES")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.fnYellow, in: Capsule())
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill((left > 3 ? Color.fnGreen : (left > 0 ? Color.fnYellow : Color.fnSecondary)).opacity(0.10))
                    )
                }
            }
            .padding(.horizontal, 20)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.fnSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }

    private func infoRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(12)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Step 2: Select Plan

    private var selectPlanStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(kind == "trainer" ? "¿Cómo querés entrenar?"
                     : kind == "club"  ? "Elegí tu membresía"
                     : "Elegí tu plan")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Podés cambiar tu plan en cualquier momento.")
                    .font(.system(size: 13))
                    .foregroundColor(.fnSlate)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(spacing: 10) {
                ForEach(plans) { plan in
                    planCard(plan)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func planCard(_ plan: LocalPlan) -> some View {
        let isSelected = selectedPlan?.id == plan.id
        return Button {
            withAnimation(.spring(response: 0.3)) { selectedPlan = plan }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? typeInfo.color : .fnSlate.opacity(0.7), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(typeInfo.color).frame(width: 13, height: 13)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(plan.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        if plan.isBestValue {
                            Text("MÁS ELEGIDO")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.fnYellow, in: Capsule())
                        }
                    }
                    Text(plan.description)
                        .font(.system(size: 12))
                        .foregroundColor(.fnSlate)
                }
                Spacer()
                Text("$\(Int(plan.price))")
                    .font(.custom("DM Serif Display", size: 16))
                    .foregroundColor(isSelected ? typeInfo.color : .white)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? typeInfo.color.opacity(0.08) : Color.fnSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? typeInfo.color : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Step 3: Payment

    private var paymentStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("¿Cómo querés pagar?")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)
                .padding(.top, 20)

            // Plan summary
            VStack(spacing: 10) {
                if let plan = selectedPlan {
                    HStack {
                        Text("Plan seleccionado")
                            .font(.system(size: 13))
                            .foregroundColor(.fnSlate)
                        Spacer()
                        Text(plan.name)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Divider()
                }
                HStack {
                    Text("Total del plan")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("$\(Int(selectedPlan?.price ?? activity.price ?? 0))")
                        .font(.custom("DM Serif Display", size: 17))
                        .foregroundColor(typeInfo.color)
                }
            }
            .padding(16)
            .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)

            // Payment type (full vs deposit) — only if provider enables it
            if supportsDeposit {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Modalidad de pago")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.fnSlate)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.horizontal, 20)

                    paymentTypeCard(.full,
                        title: "Pago completo",
                        subtitle: "Abonás el total ahora",
                        amount: selectedPlan?.price ?? activity.price ?? 0,
                        badge: nil)
                    paymentTypeCard(.deposit,
                        title: "Seña (\(depositPercent)%)",
                        subtitle: "Abonás la seña ahora y el resto en el lugar",
                        amount: (selectedPlan?.price ?? activity.price ?? 0) * Double(depositPercent) / 100,
                        badge: "FLEXIBLE")
                }
            }

            // Payment method
            VStack(alignment: .leading, spacing: 10) {
                Text("Medio de pago")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.fnSlate)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 20)

                methodCard(.card,     icon: "creditcard.fill",         title: "Tarjeta",              subtitle: "Crédito o débito")
                methodCard(.transfer, icon: "arrow.left.arrow.right",  title: "Transferencia bancaria", subtitle: "CVU / CBU / Alias")
            }

            // Total to pay
            VStack(spacing: 8) {
                Divider()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("A pagar ahora")
                            .font(.system(size: 12))
                            .foregroundColor(.fnSlate)
                        Text("$\(Int(finalPrice))")
                            .font(.custom("DM Serif Display", size: 30))
                            .foregroundStyle(typeInfo.gradient)
                    }
                    Spacer()
                    if paymentChoice == .deposit && remainingPrice > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Resto al concurrir")
                                .font(.system(size: 11))
                                .foregroundColor(.fnSlate)
                            Text("$\(Int(remainingPrice))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.fnSlate)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.fnSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }

    private func paymentTypeCard(_ type: PaymentChoice, title: String, subtitle: String, amount: Double, badge: String?) -> some View {
        let isSelected = paymentChoice == type
        return Button {
            withAnimation(.spring(response: 0.3)) { paymentChoice = type }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? typeInfo.color : .fnSlate.opacity(0.7), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected { Circle().fill(typeInfo.color).frame(width: 13, height: 13) }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.fnGreen, in: Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.fnSlate)
                }
                Spacer()
                Text("$\(Int(amount))")
                    .font(.custom("DM Serif Display", size: 15))
                    .foregroundColor(isSelected ? typeInfo.color : .white)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? typeInfo.color.opacity(0.08) : Color.fnSurface)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? typeInfo.color : Color.clear, lineWidth: 1.5))
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 20)
    }

    private func methodCard(_ method: PaymentMethod, icon: String, title: String, subtitle: String) -> some View {
        let isSelected = paymentMethod == method
        return Button {
            withAnimation(.spring(response: 0.3)) { paymentMethod = method }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? typeInfo.color : .fnSlate.opacity(0.7), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected { Circle().fill(typeInfo.color).frame(width: 13, height: 13) }
                }
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? typeInfo.color : .fnSlate)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.fnSlate)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? typeInfo.color.opacity(0.08) : Color.fnSurface)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? typeInfo.color : Color.clear, lineWidth: 1.5))
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 20)
    }

    // MARK: - Step 4: Success

    private var successStep: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 50)

            ZStack {
                Circle()
                    .fill(FNGradient.success)
                    .frame(width: 110, height: 110)
                    .fnShadowColored(.fnGreen)
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(step == .success ? 1 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.65), value: step)

            VStack(spacing: 12) {
                Text("¡Inscripción confirmada!")
                    .font(.custom("DM Serif Display", size: 30))
                    .multilineTextAlignment(.center)

                if let plan = selectedPlan {
                    HStack(spacing: 6) {
                        Image(systemName: typeInfo.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(typeInfo.color)
                        Text(plan.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(typeInfo.color)
                    }
                }

                Text("Te avisaremos antes de cada clase o actividad.")
                    .font(.system(size: 14))
                    .foregroundColor(.fnSlate)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if paymentChoice == .deposit {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.fnYellow)
                        Text("Recordá abonar el resto ($\(Int(remainingPrice))) en el lugar")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.fnYellow)
                    }
                    .padding(12)
                    .background(Color.fnYellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 30)
                }
            }

            FitNowButton(title: "Ver mis inscripciones", icon: "list.bullet.rectangle.portrait.fill") {
                dismiss()
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Bottom Action

    private var bottomAction: some View {
        VStack(spacing: 0) {
            Divider()
            Group {
                switch step {
                case .confirm:
                    FitNowButton(
                        title: noSeatsLeft ? "Sin cupos disponibles" : "Continuar",
                        icon: noSeatsLeft ? "xmark.circle" : "arrow.right.circle.fill",
                        gradient: noSeatsLeft ? FNGradient.dark : typeInfo.gradient,
                        isDisabled: noSeatsLeft
                    ) {
                        withAnimation { advanceFromConfirm() }
                    }

                case .selectPlan:
                    FitNowButton(
                        title: selectedPlan == nil ? "Seleccioná un plan" : "Continuar con \(selectedPlan!.name)",
                        icon: "arrow.right.circle.fill",
                        gradient: typeInfo.gradient,
                        isDisabled: selectedPlan == nil
                    ) {
                        if selectedPlan != nil { withAnimation { step = .payment } }
                    }

                case .payment:
                    FitNowButton(
                        title: enrolling ? "Procesando…" : "Confirmar · $\(Int(finalPrice))",
                        icon: "checkmark.circle.fill",
                        gradient: typeInfo.gradient,
                        isLoading: enrolling,
                        isDisabled: enrolling
                    ) {
                        createEnrollment()
                    }

                case .success:
                    EmptyView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.fnBg)
        }
    }

    // MARK: - Navigation Logic

    private func advanceFromConfirm() {
        if showPlanStep {
            if plans.isEmpty {
                step = .payment
            } else {
                if selectedPlan == nil { selectedPlan = plans.first }
                step = .selectPlan
            }
        } else {
            step = .payment
        }
    }

    // MARK: - API

    private func createEnrollment() {
        enrolling = true
        errorMessage = nil

        var body: [String: Any] = ["activity_id": activity.id]
        if let plan = selectedPlan {
            body["plan_name"] = plan.name
            body["plan_price"] = plan.price
        }
        body["payment_type"]   = paymentChoice == .full ? "full" : "deposit"
        body["payment_method"] = paymentMethod == .card  ? "card" : "transfer"

        let data = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
        APIClient.shared.requestPublisher("enrollments", method: "POST", body: data, authorized: true)
            .sink { completion in
                if case .failure(let e) = completion {
                    if case APIError.http(let code, let bodyStr) = e {
                        if code == 409 && (bodyStr.contains("ALREADY_ENROLLED") || bodyStr.contains("Already enrolled") || bodyStr.contains("Ya estás inscripto")) {
                            withAnimation { self.step = .success }
                            self.onEnrolled?()
                        } else if code == 409 && (bodyStr.contains("No seats left") || bodyStr.contains("NO_SEATS")) {
                            self.errorMessage = "No quedan cupos disponibles."
                        } else {
                            self.errorMessage = "Error \(code): no se pudo completar la inscripción."
                        }
                    } else {
                        self.errorMessage = e.localizedDescription
                    }
                    self.enrolling = false
                }
            } receiveValue: { (_: SimpleOK) in
                self.enrolling = false
                NotificationsService.shared.scheduleReminders(
                    activityTitle: self.activity.title,
                    activityId: self.activity.id,
                    dateStart: self.activity.date_start
                )
                withAnimation { self.step = .success }
                self.onEnrolled?()
            }
            .store(in: &helper.bag)
    }
}
