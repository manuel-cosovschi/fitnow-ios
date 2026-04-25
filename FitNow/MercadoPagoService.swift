import SwiftUI

// MARK: - MercadoPagoService

@Observable
final class MercadoPagoService {
    static let shared = MercadoPagoService()
    private init() {}

    var isProcessing = false
    var lastError: String?

    // MARK: - Create Preference

    func createPreference(
        activityId: Int,
        planName: String,
        couponCode: String?
    ) async throws -> MercadoPagoPreference {
        struct Payload: Encodable {
            let activityId: Int
            let planName: String
            let couponCode: String?
            enum CodingKeys: String, CodingKey {
                case activityId  = "activity_id"
                case planName    = "plan_name"
                case couponCode  = "coupon_code"
            }
        }
        let payload = Payload(activityId: activityId, planName: planName, couponCode: couponCode)
        guard let body = try? JSONEncoder().encode(payload) else { throw APIError.badURL }
        return try await APIClient.shared.request(
            "payments/mercadopago/preference", method: "POST", body: body, authorized: true
        )
    }

    // MARK: - Poll enrollment after MP redirect

    func pollConfirmation(enrollmentId: Int) async throws -> EnrollmentItem {
        try await PaymentService.shared.pollEnrollmentConfirmation(enrollmentId: enrollmentId)
    }
}

// MARK: - MercadoPagoWebView

struct MercadoPagoWebView: View {
    let initPoint: String
    let onSuccess: (Int) -> Void   // enrollmentId
    let onFailure: (String) -> Void
    let onCancel:  () -> Void

    @State private var isLoading = true
    @State private var localError: String?

    var body: some View {
        VStack(spacing: 24) {
            // Payment provider logo row
            HStack(spacing: 16) {
                ForEach(["creditcard.fill", "banknote.fill", "dollarsign.circle.fill"], id: \.self) { icon in
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.fnElevated)
                            .frame(width: 52, height: 36)
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.fnBorder, lineWidth: 1))
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(.fnSlate)
                    }
                }
                Spacer()
                Text("MercadoPago")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.00, green: 0.48, blue: 1.00))
            }

            if let err = localError {
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

            // Primary pay button
            Button {
                openMercadoPago()
            } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "safari.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Pagar con MercadoPago")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(red: 0.00, green: 0.48, blue: 1.00),
                            in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isLoading)

            Button("Cancelar") { onCancel() }
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)
        }
        .onAppear { isLoading = false }
    }

    private func openMercadoPago() {
        // Opens MP checkout in Safari; deep-link back via fitnow://mp-success?enrollment_id=X
        // handled in DeepLinkHandler. Stub: simulate success after 2s for dev.
        guard let url = URL(string: initPoint) else {
            localError = "URL de pago inválida."
            return
        }
        isLoading = true
        UIApplication.shared.open(url) { _ in
            // Real: DeepLinkHandler catches fitnow://mp-success and calls onSuccess
            // Stub: simulate success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isLoading = false
                // In production remove this stub and rely on deep-link callback
                onSuccess(0)
            }
        }
    }
}
