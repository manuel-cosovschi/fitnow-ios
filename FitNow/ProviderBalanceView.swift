import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// Saldo del proveedor: lo acreditado por cada inscripción pagada (menos la
// comisión de la plataforma), los movimientos, y el pedido de retiro por
// CBU o alias. El admin liquida la transferencia y la marca como pagada.
// ─────────────────────────────────────────────────────────────────────────────

struct ProviderBalance: Decodable {
    let available: Double
    let credited_total: Double
    let commission_total: Double
    let withdrawn_or_pending: Double
    let movements: Int
    let commission_pct: Double
}

struct ProviderLedgerEntry: Identifiable, Decodable {
    let id: Int
    let gross_amount: String?
    let commission: String?
    let amount: String?
    let description: String?
    let created_at: String?
}

struct ProviderWithdrawal: Identifiable, Decodable {
    let id: Int
    let amount: String?
    let cbu_alias: String?
    let status: String?
    let requested_at: String?
}

private struct LedgerResponse: Decodable { let items: [ProviderLedgerEntry] }
private struct WithdrawalsResponse: Decodable { let items: [ProviderWithdrawal] }

final class ProviderBalanceViewModel: ObservableObject {
    @Published var balance: ProviderBalance?
    @Published var ledger: [ProviderLedgerEntry] = []
    @Published var withdrawals: [ProviderWithdrawal] = []
    @Published var error: String?
    private var bag = Set<AnyCancellable>()

    func load() {
        APIClient.shared.requestPublisher("providers/me/balance", authorized: true)
            .sink { done in
                if case .failure(let e) = done { self.error = e.localizedDescription }
            } receiveValue: { (b: ProviderBalance) in self.balance = b }
            .store(in: &bag)
        APIClient.shared.requestPublisher("providers/me/ledger", authorized: true)
            .sink { _ in } receiveValue: { (r: LedgerResponse) in self.ledger = r.items }
            .store(in: &bag)
        APIClient.shared.requestPublisher("providers/me/withdrawals", authorized: true)
            .sink { _ in } receiveValue: { (r: WithdrawalsResponse) in self.withdrawals = r.items }
            .store(in: &bag)
    }

    func requestWithdrawal(amount: Double, cbu: String, completion: @escaping (String?) -> Void) {
        let body: [String: Any] = ["amount": amount, "cbu_alias": cbu]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        APIClient.shared.requestPublisher("providers/me/withdrawals", method: "POST", body: data, authorized: true)
            .sink { done in
                if case .failure(let e) = done { completion(Self.friendly(e)) }
            } receiveValue: { (_: ProviderWithdrawal) in
                self.load()
                completion(nil)
            }
            .store(in: &bag)
    }

    private static func friendly(_ error: Error) -> String {
        if case APIError.http(_, let body) = error,
           let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = json["error"] as? [String: Any],
           let msg = err["message"] as? String, !msg.isEmpty {
            return msg
        }
        return "No se pudo enviar la solicitud."
    }
}

struct ProviderBalanceView: View {
    @StateObject private var vm = ProviderBalanceViewModel()
    @State private var showWithdrawSheet = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                balanceCard
                if let b = vm.balance, b.available > 0 {
                    FitNowButton(title: "Retirar saldo", icon: "banknote.fill", gradient: FNGradient.club) {
                        showWithdrawSheet = true
                    }
                }
                if !vm.withdrawals.isEmpty { withdrawalsSection }
                if !vm.ledger.isEmpty { ledgerSection }
                if let e = vm.error {
                    Text(e).font(.system(size: 13)).foregroundColor(.fnSecondary)
                }
                Spacer(minLength: 30)
            }
            .padding(16)
        }
        .background(Color.fnBg)
        .navigationTitle("Saldo y retiros")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { vm.load() }
        .refreshable { vm.load() }
        .sheet(isPresented: $showWithdrawSheet) {
            WithdrawSheet(vm: vm, available: vm.balance?.available ?? 0)
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Saldo disponible")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .textCase(.uppercase)
            Text(money(vm.balance?.available))
                .font(.custom("DM Serif Display", size: 40))
                .foregroundColor(.white)
            HStack(spacing: 0) {
                miniStat(money(vm.balance?.credited_total), "Acreditado")
                miniStat(money(vm.balance?.commission_total), "Comisión (\(Int(vm.balance?.commission_pct ?? 10)) %)")
                miniStat(money(vm.balance?.withdrawn_or_pending), "Retirado")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(FNGradient.club))
        .fnShadowColored(.fnPurple)
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var withdrawalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Retiros")
            ForEach(vm.withdrawals) { w in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(money(Double(w.amount ?? "")))
                            .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        Text(w.cbu_alias ?? "").font(.system(size: 11)).foregroundColor(.fnSlate)
                    }
                    Spacer()
                    Text(statusLabel(w.status))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(statusColor(w.status))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(statusColor(w.status).opacity(0.12)))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.fnSurface))
            }
        }
    }

    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Movimientos")
            ForEach(vm.ledger) { m in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.description ?? "Inscripción pagada")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                            .lineLimit(1)
                        Text("Bruto \(money(Double(m.gross_amount ?? ""))) · comisión \(money(Double(m.commission ?? "")))")
                            .font(.system(size: 11)).foregroundColor(.fnSlate)
                    }
                    Spacer()
                    Text("+\(money(Double(m.amount ?? "")))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.fnGreen)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.fnSurface))
            }
        }
    }

    private func statusLabel(_ s: String?) -> String {
        switch s { case "paid": return "Pagado"; case "rejected": return "Rechazado"; default: return "Pendiente" }
    }
    private func statusColor(_ s: String?) -> Color {
        switch s { case "paid": return .fnGreen; case "rejected": return .fnSecondary; default: return .fnYellow }
    }
}

private func money(_ v: Double?) -> String {
    guard let v else { return "$0" }
    let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
    return "$" + (f.string(from: NSNumber(value: v)) ?? "0")
}

// Hoja para pedir el retiro: monto + CBU o alias.
private struct WithdrawSheet: View {
    @ObservedObject var vm: ProviderBalanceViewModel
    let available: Double
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var cbu = ""
    @State private var sending = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Color.white.opacity(0.2)).frame(width: 40, height: 5).padding(.top, 10)
            Text("Retirar saldo")
                .font(.system(size: 19, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text("Disponible: \(money(available)). La transferencia se procesa manualmente y vas a ver el estado acá.")
                .font(.system(size: 13)).foregroundColor(.fnSlate)
                .multilineTextAlignment(.center).padding(.horizontal, 24)

            VStack(spacing: 12) {
                TextField("Monto", text: $amountText)
                    .keyboardType(.decimalPad)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    .foregroundColor(.white)
                TextField("CBU o alias", text: $cbu)
                    .autocapitalization(.none)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)

            if let e = error {
                Text(e).font(.system(size: 13, weight: .medium)).foregroundColor(.fnSecondary)
            }

            FitNowButton(title: "Solicitar retiro", icon: "paperplane.fill",
                         gradient: FNGradient.club, isLoading: sending,
                         isDisabled: sending || amountText.isEmpty || cbu.count < 6) {
                send()
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity)
        .background(Color.fnSurface)
        .presentationDetents([.height(360)])
    }

    private func send() {
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")), amount > 0 else {
            error = "Ingresá un monto válido."; return
        }
        sending = true; error = nil
        vm.requestWithdrawal(amount: amount, cbu: cbu) { err in
            DispatchQueue.main.async {
                sending = false
                if let err { error = err } else { dismiss() }
            }
        }
    }
}
