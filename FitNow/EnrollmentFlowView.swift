import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - EnrollmentFlowView
// Multi-step enrollment wizard shown as a sheet from ActivityDetailView.
// Steps vary by activity kind:
//   trainer / gym / club  → confirm → selectPlan → coupon → stripePayment → success
//   club_sport            → confirm → coupon → stripePayment → success
// ─────────────────────────────────────────────────────────────────────────────

struct EnrollmentFlowView: View {
    @Environment(\.dismiss) private var dismiss

    let activity: Activity
    var onEnrolled: (() -> Void)?

    // Flow
    @State private var step: FlowStep = .confirm
    @State private var selectedPlan: LocalPlan? = nil
    @State private var paymentChoice: PaymentChoice = .full

    // Coupon
    @State private var couponCode = ""
    @State private var couponResult: CouponValidationResponse? = nil
    @State private var couponError: String? = nil
    @State private var validatingCoupon = false

    // Stripe payment intent
    @State private var isCreatingIntent = false
    @State private var clientSecret: String? = nil
    @State private var pendingEnrollmentId: Int? = nil
    @State private var confirmedEnrollmentId: Int? = nil
    @State private var intentError: String? = nil

    // MARK: - Types

    enum FlowStep: Int {
        case confirm, selectPlan, coupon, stripePayment, success

        var title: String {
            switch self {
            case .confirm:       return "Confirmá tu inscripción"
            case .selectPlan:    return "Elegí tu plan"
            case .coupon:        return "¿Tenés un cupón?"
            case .stripePayment: return "Pago seguro"
            case .success:       return "¡Listo!"
            }
        }
    }

    enum PaymentChoice { case full, deposit }

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

    private var totalSteps: Int { showPlanStep ? 4 : 3 }

    private var currentStepNumber: Int {
        switch step {
        case .confirm:       return 1
        case .selectPlan:    return 2
        case .coupon:        return showPlanStep ? 3 : 2
        case .stripePayment: return showPlanStep ? 4 : 3
        case .success:       return totalSteps
        }
    }

    private var basePrice: Double { selectedPlan?.price ?? activity.price ?? 0 }

    private var finalPrice: Double {
        if let couponFinal = couponResult?.finalPrice { return couponFinal }
        return paymentChoice == .deposit ? basePrice * Double(depositPercent) / 100.0 : basePrice
    }

    private var remainingPrice: Double {
        let base = couponResult?.finalPrice ?? basePrice
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
                        case .confirm:       confirmStep
                        case .selectPlan:    selectPlanStep
                        case .coupon:        couponStep
                        case .stripePayment: stripePaymentStep
                        case .success:       successStep
                        }
                    }
                    .padding(.bottom, 110)
                }
                if step != .success && step != .stripePayment {
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
            .onChange(of: step) { _, newStep in
                if newStep == .stripePayment { Task { await createIntent() } }
            }
        }
    }

    // MARK: - Step: Coupon

    private var couponStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Descuento y forma de pago")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Aplicá un cupón o continuá sin descuento.")
                    .font(.system(size: 13))
                    .foregroundColor(.fnSlate)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Coupon input
            VStack(alignment: .leading, spacing: 10) {
                Text("Código de descuento")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.fnSlate)
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack(spacing: 8) {
                    TextField("Ej: FITNOW20", text: $couponCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 15, design: .monospaced))
                        .padding(12)
                        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: couponCode) { _, _ in
                            couponResult = nil; couponError = nil
                        }

                    Button {
                        Task { await validateCoupon() }
                    } label: {
                        Group {
                            if validatingCoupon {
                                ProgressView().tint(.fnBlue)
                            } else {
                                Text("Validar")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.fnBlue)
                            }
                        }
                        .frame(width: 70, height: 44)
                        .background(Color.fnBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(couponCode.trimmingCharacters(in: .whitespaces).isEmpty || validatingCoupon)
                }

                if let result = couponResult, result.valid {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.fnGreen)
                        if let pct = result.discountPercent {
                            Text("\(pct)% de descuento aplicado")
                        } else if let amt = result.discountAmount {
                            Text("$\(Int(amt)) de descuento aplicado")
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.fnGreen)
                }

                if let err = couponError {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.fnCrimson)
                        Text(err)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.fnCrimson)
                }
            }
            .padding(.horizontal, 20)

            // Deposit toggle if supported
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
                        amount: finalPrice,
                        badge: nil)
                    paymentTypeCard(.deposit,
                        title: "Seña (\(depositPercent)%)",
                        subtitle: "Abonás la seña ahora y el resto en el lugar",
                        amount: basePrice * Double(depositPercent) / 100.0,
                        badge: "FLEXIBLE")
                }
            }

            // Price summary
            VStack(spacing: 8) {
                Divider()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("A pagar ahora")
                            .font(.system(size: 12))
                            .foregroundColor(.fnSlate)
                        Text("$\(Int(finalPrice))")
                            .font(.custom("DM Serif Display", size: 30))
                            .foregroundColor(typeInfo.color)
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
        }
    }

    // MARK: - Step: Stripe Payment

    private var stripePaymentStep: some View {
        VStack(spacing: 20) {
            // Price recap
            VStack(spacing: 10) {
                if let plan = selectedPlan {
                    HStack {
                        Text("Plan").font(.system(size: 13)).foregroundColor(.fnSlate)
                        Spacer()
                        Text(plan.name).font(.system(size: 13, weight: .semibold))
                    }
                    Divider()
                }
                if couponResult?.valid == true {
                    HStack {
                        Text("Descuento").font(.system(size: 13)).foregroundColor(.fnGreen)
                        Spacer()
                        if let pct = couponResult?.discountPercent {
                            Text("-\(pct)%").font(.system(size: 13, weight: .semibold)).foregroundColor(.fnGreen)
                        } else if let amt = couponResult?.discountAmount {
                            Text("-$\(Int(amt))").font(.system(size: 13, weight: .semibold)).foregroundColor(.fnGreen)
                        }
                    }
                    Divider()
                }
                HStack {
                    Text("Total a pagar").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("$\(Int(finalPrice))")
                        .font(.custom("DM Serif Display", size: 20))
                        .foregroundColor(typeInfo.color)
                }
            }
            .padding(16)
            .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
            .padding(.top, 20)

            if isCreatingIntent {
                VStack(spacing: 12) {
                    ProgressView().tint(.fnBlue)
                    Text("Preparando pago seguro…")
                        .font(.system(size: 14))
                        .foregroundColor(.fnSlate)
                }
                .padding(.top, 30)
            } else if let secret = clientSecret {
                StripePaymentView(
                    clientSecret: secret,
                    merchantName: activity.provider_name ?? "FitNow"
                ) { _ in
                    handlePaymentSuccess()
                } onCancel: {
                    withAnimation { step = .coupon }
                }
                .padding(.horizontal, 20)
            } else if let err = intentError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.fnCrimson)
                    Text(err)
                        .font(.system(size: 14))
                        .foregroundColor(.fnCrimson)
                        .multilineTextAlignment(.center)
                    Button("Reintentar") { Task { await createIntent() } }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.fnBlue)
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
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

    // MARK: - Step: Success

    private var successStep: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 30)

            ZStack {
                Circle()
                    .fill(Color.fnGreen)
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(step == .success ? 1 : 0.4)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: step)

            VStack(spacing: 8) {
                Text("¡Inscripción confirmada!")
                    .font(.custom("DM Serif Display", size: 28))
                    .multilineTextAlignment(.center)
                if let plan = selectedPlan {
                    HStack(spacing: 6) {
                        Image(systemName: typeInfo.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(typeInfo.color)
                        Text(plan.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(typeInfo.color)
                    }
                }
                Text("Te avisaremos antes de cada clase.")
                    .font(.system(size: 13))
                    .foregroundColor(.fnSlate)
            }

            // QR access card
            if let enrollId = confirmedEnrollmentId ?? pendingEnrollmentId {
                EnrollmentQRCard(
                    enrollmentId: enrollId,
                    activityTitle: activity.title,
                    date: activity.date_start
                )
                .padding(.horizontal, 20)
            }

            if paymentChoice == .deposit && remainingPrice > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundColor(.fnYellow)
                    Text("Recordá abonar el resto ($\(Int(remainingPrice))) en el lugar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.fnYellow)
                }
                .padding(12)
                .background(Color.fnYellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
            }

            VStack(spacing: 10) {
                if let enrollId = confirmedEnrollmentId ?? pendingEnrollmentId {
                    ShareLink(
                        item: "fitnow://checkin/\(enrollId)",
                        subject: Text("Mi inscripción en FitNow"),
                        message: Text("Usá este código para el check-in: \(enrollId)")
                    ) {
                        Label("Compartir código", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.fnBlue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.fnBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                }

                FitNowButton(title: "Ver mis inscripciones",
                             icon: "list.bullet.rectangle.portrait.fill") {
                    dismiss()
                }
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 20)
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
                        if selectedPlan != nil { withAnimation { step = .coupon } }
                    }

                case .coupon:
                    FitNowButton(
                        title: "Ir al pago · $\(Int(finalPrice))",
                        icon: "lock.shield.fill",
                        gradient: typeInfo.gradient
                    ) {
                        withAnimation { step = .stripePayment }
                    }

                case .stripePayment, .success:
                    EmptyView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.fnBg)
        }
    }

    // MARK: - Navigation

    private func advanceFromConfirm() {
        if showPlanStep {
            if plans.isEmpty {
                step = .coupon
            } else {
                if selectedPlan == nil { selectedPlan = plans.first }
                step = .selectPlan
            }
        } else {
            step = .coupon
        }
    }

    // MARK: - API

    private func validateCoupon() async {
        let code = couponCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        validatingCoupon = true
        couponError = nil
        couponResult = nil
        do {
            let result = try await PaymentService.shared.validateCoupon(code, activityId: activity.id)
            if result.valid {
                couponResult = result
            } else {
                couponError = result.message ?? "Cupón inválido o expirado."
            }
        } catch {
            couponError = "No se pudo validar el cupón."
        }
        validatingCoupon = false
    }

    private func createIntent() async {
        guard clientSecret == nil else { return }
        isCreatingIntent = true
        intentError = nil
        do {
            let response = try await PaymentService.shared.createPaymentIntent(
                activityId: activity.id,
                planName: selectedPlan?.name ?? "Inscripción",
                couponCode: couponResult?.valid == true ? couponCode : nil
            )
            clientSecret = response.clientSecret
            pendingEnrollmentId = response.enrollmentId
        } catch {
            intentError = error.localizedDescription
        }
        isCreatingIntent = false
    }

    private func handlePaymentSuccess() {
        NotificationsService.shared.scheduleReminders(
            activityTitle: activity.title,
            activityId: activity.id,
            dateStart: activity.date_start
        )
        Task {
            if let enrollId = pendingEnrollmentId {
                let confirmed = try? await PaymentService.shared.pollEnrollmentConfirmation(enrollmentId: enrollId)
                confirmedEnrollmentId = confirmed?.id ?? enrollId
            }
            withAnimation { step = .success }
            onEnrolled?()
        }
    }
}
