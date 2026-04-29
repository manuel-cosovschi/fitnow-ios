import StoreKit
import Observation

// MARK: - Product IDs

enum FNProductID {
    static let plusMonthly = "com.fitnow.plus.monthly"
    static let plusAnnual  = "com.fitnow.plus.annual"
    static let all: [String] = [plusMonthly, plusAnnual]
}

// MARK: - StoreKitService

@Observable
final class StoreKitService {
    static let shared = StoreKitService()

    private(set) var products: [Product] = []
    private(set) var isPlusActive = false
    private(set) var isLoading = false
    private(set) var purchaseError: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    private init() {
        transactionUpdatesTask = Task { await listenForTransactions() }
    }

    deinit { transactionUpdatesTask?.cancel() }

    func clearError() { purchaseError = nil }

    // MARK: - Load products

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: FNProductID.all)
                .sorted { $0.price < $1.price }
        } catch {
            purchaseError = error.localizedDescription
        }
        await refreshPurchaseStatus()
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshPurchaseStatus()
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func refreshPurchaseStatus() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if FNProductID.all.contains(transaction.productID) {
                hasActive = true
            }
        }
        isPlusActive = hasActive
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? checkVerified(result) else { continue }
            await transaction.finish()
            await refreshPurchaseStatus()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
        }
    }

    var monthlyProduct: Product? { products.first { $0.id == FNProductID.plusMonthly } }
    var annualProduct:  Product? { products.first { $0.id == FNProductID.plusAnnual  } }
}

enum StoreError: LocalizedError {
    case failedVerification
    var errorDescription: String? { "La compra no pudo ser verificada." }
}
