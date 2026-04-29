import SwiftUI

// MARK: - SavedPaymentsService

@Observable
final class SavedPaymentsService {
    static let shared = SavedPaymentsService()
    private init() {}

    var methods: [SavedPaymentMethod] = []
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            let resp: ListResponse<SavedPaymentMethod> = try await APIClient.shared.request(
                "payments/methods", authorized: true
            )
            methods = resp.items
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func setDefault(id: Int) async {
        do {
            let body = try? JSONEncoder().encode(["id": id])
            let _: SimpleOK = try await APIClient.shared.request(
                "payments/methods/\(id)/default", method: "PUT", body: body, authorized: true
            )
            await load()
        } catch {}
    }

    func delete(id: Int) async {
        do {
            let _: SimpleOK = try await APIClient.shared.request(
                "payments/methods/\(id)", method: "DELETE", authorized: true
            )
            methods.removeAll { $0.id == id }
        } catch {}
    }
}

// MARK: - SavedPaymentsView

struct SavedPaymentsView: View {
    @State private var service = SavedPaymentsService.shared
    @State private var showDeleteAlert = false
    @State private var pendingDeleteId: Int?

    var body: some View {
        ZStack {
            Color.fnBg.ignoresSafeArea()

            Group {
                if service.isLoading && service.methods.isEmpty {
                    loadingView
                } else if service.methods.isEmpty {
                    emptyView
                } else {
                    methodsList
                }
            }
        }
        .navigationTitle("Métodos de pago")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fnBg, for: .navigationBar)
        .task { await service.load() }
        .alert("Eliminar método", isPresented: $showDeleteAlert) {
            Button("Eliminar", role: .destructive) {
                if let id = pendingDeleteId {
                    Task { await service.delete(id: id) }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("¿Eliminás esta tarjeta guardada? No se puede deshacer.")
        }
    }

    private var methodsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(service.methods) { method in
                    methodCard(method)
                }

                Text("Tus métodos de pago están protegidos con encriptación.")
                    .font(.system(size: 12))
                    .foregroundColor(.fnAsh)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func methodCard(_ method: SavedPaymentMethod) -> some View {
        HStack(spacing: 14) {
            // Brand icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.fnSurface)
                    .frame(width: 52, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.fnBorder, lineWidth: 1))
                Image(systemName: brandIcon(method.brand))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(brandColor(method.brand))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(brandName(method.brand))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.fnWhite)
                    if method.isDefault {
                        Text("PREDETERMINADA")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.fnBlue, in: Capsule())
                    }
                }
                if let last4 = method.last4 {
                    Text("•••• \(last4)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.fnSlate)
                }
                if let m = method.expiryMonth, let y = method.expiryYear {
                    Text(String(format: "Vence %02d/%02d", m, y % 100))
                        .font(.system(size: 11))
                        .foregroundColor(.fnAsh)
                }
            }

            Spacer()

            Menu {
                if !method.isDefault {
                    Button {
                        Task { await service.setDefault(id: method.id) }
                    } label: {
                        Label("Establecer como predeterminada", systemImage: "checkmark.circle")
                    }
                }
                Button(role: .destructive) {
                    pendingDeleteId = method.id
                    showDeleteAlert = true
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.fnSlate)
                    .padding(8)
            }
        }
        .padding(14)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(method.isDefault ? Color.fnBlue.opacity(0.4) : Color.fnBorder, lineWidth: 1))
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonView(cornerRadius: 16).frame(height: 80)
            }
        }
        .padding(.horizontal, 16).padding(.top, 14)
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.fnAsh)
            Text("Sin métodos guardados")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.fnWhite)
            Text("Cuando pagues con tarjeta podrás guardarla para futuras compras.")
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func brandIcon(_ brand: String?) -> String {
        switch brand?.lowercased() {
        case "visa":       return "creditcard.fill"
        case "mastercard": return "creditcard.fill"
        case "amex":       return "creditcard.fill"
        default:           return "creditcard"
        }
    }

    private func brandColor(_ brand: String?) -> Color {
        switch brand?.lowercased() {
        case "visa":       return Color(red: 0.07, green: 0.27, blue: 0.68)
        case "mastercard": return Color(red: 0.85, green: 0.20, blue: 0.20)
        case "amex":       return Color(red: 0.00, green: 0.46, blue: 0.73)
        default:           return .fnSlate
        }
    }

    private func brandName(_ brand: String?) -> String {
        switch brand?.lowercased() {
        case "visa":       return "Visa"
        case "mastercard": return "Mastercard"
        case "amex":       return "Amex"
        default:           return brand?.capitalized ?? "Tarjeta"
        }
    }
}
