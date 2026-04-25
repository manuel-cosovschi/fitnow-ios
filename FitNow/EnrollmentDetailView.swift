import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - EnrollmentDetailView
// Shows enrollment-specific info when user taps an item in Mis inscripciones.
// Different from ActivityDetailView — focuses on the USER's enrollment state.
// ─────────────────────────────────────────────────────────────────────────────

fileprivate let isoFracED: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
}()
fileprivate let isoBasicED: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
}()
fileprivate let mysqlDFED: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f
}()
fileprivate let outDFED: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "es_AR")
    f.dateStyle = .medium; f.timeStyle = .short; return f
}()
fileprivate func prettyED(_ s: String?) -> String {
    guard let s = s else { return "—" }
    if let d = isoFracED.date(from: s) ?? isoBasicED.date(from: s) ?? mysqlDFED.date(from: s) { return outDFED.string(from: d) }
    return s
}

// Minimal provider info for detail view
struct EDProviderInfo: Decodable {
    let name: String?; let kind: String?; let address: String?; let city: String?
}
struct EDActivityAndProvider: Decodable {
    let activity: Activity; let provider: EDProviderInfo?
}

final class EnrollmentDetailViewModel: ObservableObject {
    @Published var activity: Activity?
    @Published var provider: EDProviderInfo?
    @Published var loading = true
    @Published var cancelling = false
    @Published var cancelled = false
    @Published var error: String?

    private var bag = Set<AnyCancellable>()

    func load(activityId: Int) {
        loading = true; error = nil
        APIClient.shared.requestPublisher("activities/\(activityId)", authorized: false)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: EDActivityAndProvider) in
                self?.activity = resp.activity
                self?.provider = resp.provider
                self?.loading = false
            }
            .store(in: &bag)
    }

    func cancel(enrollmentId: Int, completion: @escaping () -> Void) {
        cancelling = true
        APIClient.shared.requestPublisher("enrollments/\(enrollmentId)", method: "DELETE", authorized: true)
            .sink { [weak self] comp in
                self?.cancelling = false
                if case .failure(let e) = comp { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (_: SimpleOK) in
                self?.cancelled = true
                NotificationsService.shared.cancelReminders(activityId: enrollmentId)
                completion()
            }
            .store(in: &bag)
    }
}

struct EnrollmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let enrollment: EnrollmentItem

    @StateObject private var vm = EnrollmentDetailViewModel()
    @State private var showCancelConfirm = false
    @State private var appeared = false

    private var kind: String { enrollment.activity_kind ?? "" }
    private var typeInfo: ActivityTypeInfo { ActivityTypeInfo.from(kind: kind) }

    private var navTitle: String {
        switch kind {
        case "trainer":    return "Mi entrenador"
        case "gym":        return "Mi membresía"
        case "club":       return "Mi club"
        case "club_sport": return "Mi deporte"
        default:           return "Mi inscripción"
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if vm.loading {
                loadingSkeleton
            } else if vm.cancelled {
                cancelledState
            } else {
                content
            }
        }
        .background(Color.fnBg)
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if let aid = enrollment.activity_id { vm.load(activityId: aid) }
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
        .confirmationDialog("¿Cancelar inscripción?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Sí, cancelar inscripción", role: .destructive) {
                vm.cancel(enrollmentId: enrollment.id) { dismiss() }
            }
        } message: {
            Text("No vas a poder deshacer esta acción.")
        }
    }

    // MARK: - Main Content

    private var content: some View {
        VStack(spacing: 20) {
            // Hero header
            enrollmentHeader
                .padding(.horizontal, 20)
                .padding(.top, 20)

            // Plan / membership info
            planSection
                .padding(.horizontal, 20)

            // Provider card
            if vm.provider?.name != nil || vm.activity?.location != nil {
                providerSection
                    .padding(.horizontal, 20)
            }

            // Type-specific section
            typeSpecificSection

            // Running access card
            if vm.activity?.enable_running == true {
                runningCard
                    .padding(.horizontal, 20)
            }

            // Error
            if let err = vm.error {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(.fnSecondary)
                    .padding(.horizontal, 20)
            }

            // Cancel
            if !vm.cancelled {
                cancelSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appeared)
    }

    // MARK: - Enrollment Header

    private var enrollmentHeader: some View {
        VStack(spacing: 0) {
            typeInfo.gradient
                .frame(maxWidth: .infinity)
                .frame(height: 130)
                .overlay(
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.2)).frame(width: 54, height: 54)
                            Image(systemName: typeInfo.icon)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(enrollment.title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("Inscripto")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Plan Section

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tu inscripción")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.fnSlate)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                if let planName = enrollment.plan_name, !planName.isEmpty {
                    detailRow(label: "Plan",    value: planName,
                              icon: "star.fill", color: typeInfo.color)
                    Divider().padding(.leading, 44)
                }
                if let planPrice = enrollment.plan_price, planPrice > 0 {
                    detailRow(label: "Precio del plan", value: "$\(Int(planPrice))",
                              icon: "creditcard.fill", color: .fnGreen)
                    Divider().padding(.leading, 44)
                } else if let price = enrollment.price, price > 0 {
                    detailRow(label: "Precio pagado", value: "$\(Int(price))",
                              icon: "creditcard.fill", color: .fnGreen)
                    Divider().padding(.leading, 44)
                }
                detailRow(label: "Inicio",     value: prettyED(enrollment.date_start),
                          icon: "calendar",              color: .fnCyan)
                if let end = enrollment.date_end, !end.isEmpty {
                    Divider().padding(.leading, 44)
                    detailRow(label: "Vencimiento", value: prettyED(end),
                              icon: "calendar.badge.checkmark", color: .fnSecondary)
                }
            }
            .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func detailRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Provider Section

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(kind == "trainer" ? "Entrenador" : kind == "gym" ? "Gimnasio" : kind == "club" ? "Club" : "Proveedor")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.fnSlate)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                if let name = vm.provider?.name, !name.isEmpty {
                    providerRow(icon: "person.circle.fill", color: typeInfo.color, text: name)
                }
                if let addr = vm.provider?.address, !addr.isEmpty {
                    Divider().padding(.leading, 44)
                    providerRow(icon: "mappin.circle.fill", color: .fnSecondary, text: addr)
                }
                if let city = vm.provider?.city, !city.isEmpty {
                    Divider().padding(.leading, 44)
                    providerRow(icon: "building.2.fill", color: .fnSlate.opacity(0.7), text: city)
                }
                if let loc = enrollment.location ?? vm.activity?.location, !loc.isEmpty,
                   vm.provider?.address == nil {
                    Divider().padding(.leading, 44)
                    providerRow(icon: "mappin.circle.fill", color: .fnSecondary, text: loc)
                }
            }
            .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func providerRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 32)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Type-Specific Section

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch kind {
        case "trainer":
            if let aid = enrollment.activity_id {
                trainerSection(activityId: aid)
                    .padding(.horizontal, 20)
            }
        case "club":
            if let pid = enrollment.provider_id {
                clubSection(providerId: pid)
                    .padding(.horizontal, 20)
            }
        case "gym":
            gymSection
                .padding(.horizontal, 20)
        default:
            EmptyView()
        }
    }

    private func trainerSection(activityId: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clases")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.fnSlate)
                .textCase(.uppercase)
                .tracking(0.5)
            NavigationLink {
                TrainerBookingsView(activityId: activityId, title: enrollment.title)
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FNGradient.trainer)
                            .frame(width: 48, height: 48)
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ver y reservar clases")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("Gestioná tus sesiones con el entrenador")
                            .font(.system(size: 12))
                            .foregroundColor(.fnSlate)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.fnSlate.opacity(0.7))
                }
                .padding(16)
                .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.fnPrimary.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func clubSection(providerId: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deportes del club")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.fnSlate)
                .textCase(.uppercase)
                .tracking(0.5)
            NavigationLink {
                ClubSportsView(providerId: providerId, clubTitle: enrollment.title)
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FNGradient.club)
                            .frame(width: 48, height: 48)
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ver deportes disponibles")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("Inscribite a los deportes de tu club")
                            .font(.system(size: 12))
                            .foregroundColor(.fnSlate)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.fnSlate.opacity(0.7))
                }
                .padding(16)
                .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.fnPurple.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var gymSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tu membresía")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.fnSlate)
                .textCase(.uppercase)
                .tracking(0.5)
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FNGradient.gym)
                        .frame(width: 48, height: 48)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(enrollment.plan_name ?? "Membresía activa")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Accedés a todas las instalaciones del gimnasio")
                        .font(.system(size: 12))
                        .foregroundColor(.fnSlate)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.fnGreen)
            }
            .padding(16)
            .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.fnCyan.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - Running Card

    private var runningCard: some View {
        NavigationLink { RunPlannerView() } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FNGradient.run)
                        .frame(width: 48, height: 48)
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                .fnShadowColored(.fnCyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rutas de running")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Generá rutas personalizadas cerca tuyo")
                        .font(.system(size: 12))
                        .foregroundColor(.fnSlate)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.fnSlate.opacity(0.7))
            }
            .padding(16)
            .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.fnCyan.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Cancel Section

    private var cancelSection: some View {
        VStack(spacing: 8) {
            Button {
                showCancelConfirm = true
            } label: {
                HStack(spacing: 8) {
                    if vm.cancelling {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(vm.cancelling ? "Cancelando…" : "Cancelar inscripción")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.fnSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.fnSecondary.opacity(0.4), lineWidth: 1.5)
                )
            }
            .disabled(vm.cancelling)
            .opacity(vm.cancelling ? 0.6 : 1)

            Text("Las políticas de reembolso dependen de cada proveedor.")
                .font(.system(size: 11))
                .foregroundColor(.fnSlate.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Cancelled State

    private var cancelledState: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.fnSlate.opacity(0.7))
            Text("Inscripción cancelada")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text("Tu inscripción fue cancelada exitosamente.")
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        VStack(spacing: 16) {
            SkeletonView(cornerRadius: 20).frame(height: 130).padding(.horizontal, 20).padding(.top, 20)
            SkeletonView(cornerRadius: 14).frame(height: 120).padding(.horizontal, 20)
            SkeletonView(cornerRadius: 14).frame(height: 100).padding(.horizontal, 20)
        }
    }
}
