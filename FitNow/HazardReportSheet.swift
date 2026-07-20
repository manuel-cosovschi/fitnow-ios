import SwiftUI
import CoreLocation

// Hoja de reporte rápido de zonas, estilo Waze: cuatro botones grandes,
// un toque y el reporte sale con tu ubicación actual. Lo ven todos los
// corredores de la zona y el planificador lo usa para evaluar rutas.
struct HazardReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sending = false
    @State private var sent = false
    @State private var failed = false

    private let types: [(key: String, label: String, icon: String, color: Color, severity: Int)] = [
        ("inseguridad", "Inseguridad", "exclamationmark.shield.fill", .fnSecondary, 3),
        ("iluminacion", "Mala iluminación", "lightbulb.slash.fill", .fnYellow, 2),
        ("vereda_rota", "Vereda rota", "road.lanes", .fnPrimary, 2),
        ("obra", "Obra / corte", "cone.fill", .fnCyan, 2),
    ]

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            if sent {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.fnGreen)
                    Text("¡Reporte enviado!")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Los corredores de la zona lo van a ver y el planificador lo tiene en cuenta.")
                        .font(.system(size: 13))
                        .foregroundColor(.fnSlate)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 4) {
                    Text("Reportar zona")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Se reporta en tu ubicación actual")
                        .font(.system(size: 13))
                        .foregroundColor(.fnSlate)
                }

                if failed {
                    Text("No se pudo enviar. Probá de nuevo.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.fnSecondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(types, id: \.key) { t in
                        Button {
                            send(type: t.key, severity: t.severity)
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: t.icon)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(t.color)
                                Text(t.label)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 22)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(t.color.opacity(0.35), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(sending)
                    }
                }
                .padding(.horizontal, 20)
                .opacity(sending ? 0.5 : 1)
            }

            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity)
        .background(Color.fnSurface)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
    }

    private func send(type: String, severity: Int) {
        guard let loc = LocationService.shared.lastLocation?.coordinate else { failed = true; return }
        sending = true; failed = false
        HazardService.shared.report(type: type, severity: severity, note: nil, at: loc) { ok in
            DispatchQueue.main.async {
                sending = false
                if ok {
                    withAnimation(.spring(response: 0.4)) { sent = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { dismiss() }
                } else {
                    failed = true
                }
            }
        }
    }
}
