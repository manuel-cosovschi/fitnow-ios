import SwiftUI

// MARK: - RefundView

struct RefundView: View {
    let enrollment: EnrollmentItem
    @Environment(\.dismiss) private var dismiss

    @State private var reason = ""
    @State private var selectedReason = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var error: String?

    private let reasons = [
        "No puedo asistir",
        "Cambio de planes",
        "Problemas de salud",
        "El servicio no cumplió mis expectativas",
        "Otro motivo",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.fnBg.ignoresSafeArea()

                if submitted {
                    successView
                } else {
                    formView
                }
            }
            .navigationTitle("Solicitar reembolso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.fnBg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(submitted ? "Cerrar" : "Cancelar") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Enrollment summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inscripción")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.fnSlate)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    HStack(spacing: 10) {
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.fnBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(enrollment.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.fnWhite)
                            if let price = enrollment.price, price > 0 {
                                Text("$\(Int(price)) abonado")
                                    .font(.system(size: 12))
                                    .foregroundColor(.fnSlate)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 12))
                }

                // Reason picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Motivo")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.fnSlate)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    ForEach(reasons, id: \.self) { r in
                        Button {
                            withAnimation(.spring(response: 0.25)) { selectedReason = r }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .stroke(selectedReason == r ? Color.fnBlue : Color.fnSlate.opacity(0.5), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                    if selectedReason == r {
                                        Circle().fill(Color.fnBlue).frame(width: 12, height: 12)
                                    }
                                }
                                Text(r)
                                    .font(.system(size: 14))
                                    .foregroundColor(.fnWhite)
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedReason == r ? Color.fnBlue.opacity(0.08) : Color.fnSurface)
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedReason == r ? Color.fnBlue : Color.clear, lineWidth: 1))
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }

                // Free text comment
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comentario adicional (opcional)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.fnSlate)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    TextEditor(text: $reason)
                        .font(.system(size: 14))
                        .foregroundColor(.fnWhite)
                        .frame(height: 100)
                        .padding(10)
                        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fnBorder, lineWidth: 1))
                        .scrollContentBackground(.hidden)
                }

                if let err = error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.fnCrimson)
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.fnCrimson)
                    }
                    .padding(12)
                    .background(Color.fnCrimson.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }

                // Policy note
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.fnSlate)
                    Text("El reembolso se procesa en 3-5 días hábiles. El monto devuelto depende de la política de cancelación de la actividad.")
                        .font(.system(size: 12))
                        .foregroundColor(.fnSlate)
                }
                .padding(12)
                .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 10))

                FitNowButton(
                    title: isSubmitting ? "Enviando…" : "Solicitar reembolso",
                    icon: "arrow.uturn.backward.circle.fill",
                    isLoading: isSubmitting,
                    isDisabled: selectedReason.isEmpty || isSubmitting
                ) {
                    Task { await submitRefund() }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().fill(Color.fnGreen).frame(width: 90, height: 90)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(spacing: 10) {
                Text("Solicitud enviada")
                    .font(.custom("DM Serif Display", size: 26))
                    .foregroundColor(.fnWhite)
                Text("Revisaremos tu solicitud y te avisaremos por correo en los próximos días hábiles.")
                    .font(.system(size: 14))
                    .foregroundColor(.fnSlate)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            FitNowButton(title: "Entendido", icon: "checkmark.circle.fill") {
                dismiss()
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - API

    private func submitRefund() async {
        isSubmitting = true
        error = nil
        struct Payload: Encodable {
            let enrollmentId: Int; let reason: String; let comment: String?
            enum CodingKeys: String, CodingKey {
                case enrollmentId = "enrollment_id"; case reason, comment
            }
        }
        let payload = Payload(enrollmentId: enrollment.id,
                              reason: selectedReason,
                              comment: reason.isEmpty ? nil : reason)
        guard let body = try? JSONEncoder().encode(payload) else {
            error = "Error interno."; isSubmitting = false; return
        }
        do {
            let _: RefundRequest = try await APIClient.shared.request(
                "payments/refunds", method: "POST", body: body, authorized: true
            )
            submitted = true
        } catch {
            self.error = "No se pudo enviar la solicitud. Intentá de nuevo."
        }
        isSubmitting = false
    }
}
