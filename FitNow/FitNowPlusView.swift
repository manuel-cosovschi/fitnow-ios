import SwiftUI
import StoreKit

// MARK: - FitNow+ Paywall

struct FitNowPlusView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sk = StoreKitService.shared
    @State private var selectedProductId = FNProductID.plusMonthly
    @State private var isPurchasing = false
    @State private var showSuccess = false

    private let features: [(String, String, Color)] = [
        ("brain.head.profile",        "Coach IA personalizado",       .fnPurple),
        ("waveform.path.ecg",         "ACWR avanzado + tendencias",   .fnCyan),
        ("bell.badge.fill",           "Alertas inteligentes",         .fnAmber),
        ("rectangle.3.group.fill",    "Widgets en pantalla de inicio", .fnGreen),
        ("nosign",                    "Sin anuncios",                  .fnCrimson),
        ("arrow.down.circle.fill",    "Descarga de rutinas offline",   .fnYellow),
    ]

    var body: some View {
        ZStack {
            Color.fnBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroBanner
                    featureList
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                    planPicker
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                    ctaButtons
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    restoreButton
                        .padding(.top, 12)
                    legalNote
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("FitNow+")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fnBg, for: .navigationBar)
        .task { await sk.load() }
        .alert("¡Bienvenido a FitNow+!", isPresented: $showSuccess) {
            Button("Continuar") { dismiss() }
        } message: {
            Text("Tu suscripción está activa. Disfrutá todas las funciones premium.")
        }
        .alert("Error", isPresented: Binding(
            get: { sk.purchaseError != nil },
            set: { if !$0 { sk.purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) { sk.purchaseError = nil }
        } message: {
            Text(sk.purchaseError ?? "")
        }
    }

    // MARK: - Hero banner

    private var heroBanner: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.fnPurple.opacity(0.85), Color.fnBg],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 220)

            VStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .fnPurple, radius: 20)
                Text("FitNow+")
                    .font(.custom("DM Serif Display", size: 36))
                    .foregroundColor(.white)
                if sk.isPlusActive {
                    Text("ACTIVO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.fnGreen)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Color.fnGreen.opacity(0.18), in: Capsule())
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 14) {
            ForEach(features, id: \.0) { icon, label, color in
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(color.opacity(0.14)).frame(width: 38, height: 38)
                        Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(color)
                    }
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.fnWhite)
                    Spacer()
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(color)
                }
            }
        }
    }

    // MARK: - Plan picker

    private var planPicker: some View {
        VStack(spacing: 12) {
            if let monthly = sk.monthlyProduct {
                planCard(product: monthly, badge: nil)
            }
            if let annual = sk.annualProduct {
                planCard(product: annual, badge: "Ahorrás 30%")
            }
            if sk.isLoading {
                ProgressView().tint(.fnPurple)
            }
        }
    }

    private func planCard(product: Product, badge: String?) -> some View {
        let selected = selectedProductId == product.id
        return Button { selectedProductId = product.id } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(selected ? Color.fnPurple : Color.fnBorder, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle().fill(Color.fnPurple).frame(width: 12, height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.fnWhite)
                    Text(product.description)
                        .font(.system(size: 12))
                        .foregroundColor(.fnSlate)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(product.displayPrice)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(selected ? .fnPurple : .fnWhite)
                    if let b = badge {
                        Text(b)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.fnGreen)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.fnGreen.opacity(0.14), in: Capsule())
                    }
                }
            }
            .padding(16)
            .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? Color.fnPurple : Color.fnBorder.opacity(0.4), lineWidth: selected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaButtons: some View {
        Group {
            if sk.isPlusActive {
                Label("Suscripción activa", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.fnGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.fnGreen.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
            } else {
                Button {
                    Task { await doPurchase() }
                } label: {
                    Group {
                        if isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text("Suscribirse")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16).fill(Color.fnPurple)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isPurchasing || sk.products.isEmpty)
            }
        }
    }

    private func doPurchase() async {
        guard let product = sk.products.first(where: { $0.id == selectedProductId }) else { return }
        isPurchasing = true
        let success = await sk.purchase(product)
        isPurchasing = false
        if success { showSuccess = true }
    }

    // MARK: - Footer

    private var restoreButton: some View {
        Button("Restaurar compras") {
            Task { await sk.restorePurchases() }
        }
        .font(.system(size: 13))
        .foregroundColor(.fnSlate)
    }

    private var legalNote: some View {
        Text("La suscripción se renueva automáticamente. Podés cancelarla desde Ajustes de App Store en cualquier momento.")
            .font(.system(size: 11))
            .foregroundColor(.fnAsh)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }
}
