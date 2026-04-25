import Foundation
import SwiftUI

// MARK: - Payment models

struct PaymentIntentResponse: Decodable {
    let clientSecret: String
    let enrollmentId: Int
    let amount: Int         // in cents
    let currency: String

    enum CodingKeys: String, CodingKey {
        case clientSecret  = "client_secret"
        case enrollmentId  = "enrollment_id"
        case amount, currency
    }
}

struct CouponValidationResponse: Decodable {
    let valid: Bool
    let discountAmount: Double?
    let discountPercent: Int?
    let finalPrice: Double?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case valid
        case discountAmount  = "discount_amount"
        case discountPercent = "discount_percent"
        case finalPrice      = "final_price"
        case message
    }
}

// MARK: - PaymentService

@Observable
final class PaymentService {
    static let shared = PaymentService()
    private init() {}

    var isProcessing = false
    var lastError: String?

    // MARK: - Stripe publishable key
    // Set via build config or remote config; never hardcode production key in source.
    static var publishableKey: String {
        Bundle.main.object(forInfoDictionaryKey: "StripePublishableKey") as? String ?? ""
    }

    // MARK: - Create Payment Intent

    func createPaymentIntent(
        activityId: Int,
        planName: String,
        couponCode: String?
    ) async throws -> PaymentIntentResponse {
        struct Payload: Encodable {
            let activityId: Int
            let planName: String
            let couponCode: String?
            enum CodingKeys: String, CodingKey {
                case activityId = "activity_id"
                case planName   = "plan_name"
                case couponCode = "coupon_code"
            }
        }
        let payload = Payload(activityId: activityId,
                              planName: planName, couponCode: couponCode)
        guard let body = try? JSONEncoder().encode(payload) else { throw APIError.badURL }
        return try await APIClient.shared.request(
            "payments/stripe/intent", method: "POST", body: body, authorized: true
        )
    }

    // MARK: - Validate Coupon

    func validateCoupon(_ code: String, activityId: Int) async throws -> CouponValidationResponse {
        struct Payload: Encodable { let code: String; let activityId: Int
            enum CodingKeys: String, CodingKey { case code; case activityId = "activity_id" }
        }
        guard let body = try? JSONEncoder().encode(Payload(code: code, activityId: activityId)) else {
            throw APIError.badURL
        }
        return try await APIClient.shared.request(
            "payments/coupons/validate", method: "POST", body: body, authorized: true
        )
    }

    // MARK: - Poll enrollment confirmation

    func pollEnrollmentConfirmation(enrollmentId: Int, maxAttempts: Int = 10) async throws -> EnrollmentItem {
        for attempt in 0..<maxAttempts {
            let items: ListResponse<EnrollmentItem> = try await APIClient.shared.request(
                "enrollments/mine", authorized: true
            )
            if let enrollment = items.items.first(where: { $0.id == enrollmentId }),
               enrollment.status == "active" {
                return enrollment
            }
            let delay = UInt64(min(2 + attempt, 5)) * 1_000_000_000
            try await Task.sleep(nanoseconds: delay)
        }
        throw APIError.http(408, "Timeout esperando confirmación de pago")
    }
}

// MARK: - StripePaymentSheet presenter
// This view controller bridges UIKit's Stripe PaymentSheet to SwiftUI.
// Requires StripePaymentSheet SDK. Add via SPM:
// https://github.com/stripe/stripe-ios  package: StripePaymentSheet

struct StripePaymentView: View {
    let clientSecret: String
    let merchantName: String
    let onSuccess: (String) -> Void  // paymentIntentId
    let onCancel:  () -> Void

    @State private var isLoading = false
    @State private var localError: String?

    var body: some View {
        VStack(spacing: 24) {
            // Payment method icon row
            HStack(spacing: 16) {
                ForEach(["creditcard.fill", "apple.logo", "banknote.fill"], id: \.self) { icon in
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
            }

            if let err = localError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.fnCrimson)
                        .font(.system(size: 13))
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.fnCrimson)
                }
                .padding(12)
                .background(Color.fnCrimson.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }

            // Primary payment button (opens native Stripe sheet when SDK present)
            Button { presentStripeSheet() } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 16, weight: .medium))
                        Text("Pagar con Apple Pay")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isLoading)

            Button { presentStripeSheet() } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().tint(.fnBlue)
                    } else {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 15, weight: .medium))
                        Text("Pagar con tarjeta")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.fnBlue)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.fnBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.fnBlue.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isLoading)

            Button("Cancelar") { onCancel() }
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)
        }
    }

    private func presentStripeSheet() {
        // When StripePaymentSheet SDK is installed:
        //
        // var config = PaymentSheet.Configuration()
        // config.merchantDisplayName = merchantName
        // config.applePay = .init(merchantId: "merchant.com.fitnow.app", merchantCountryCode: "AR")
        // let sheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: config)
        // sheet.present(from: topViewController()) { result in
        //     switch result {
        //     case .completed:
        //         let intentId = clientSecret.components(separatedBy: "_secret_").first ?? ""
        //         onSuccess(intentId)
        //     case .canceled:
        //         onCancel()
        //     case .failed(let error):
        //         localError = error.localizedDescription
        //     }
        // }
        //
        // Stub: simulate success after 1.5s for development
        isLoading = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            isLoading = false
            let intentId = clientSecret.components(separatedBy: "_secret_").first ?? "pi_stub"
            onSuccess(intentId)
        }
    }
}
