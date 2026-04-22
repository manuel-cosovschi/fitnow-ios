import SwiftUI

struct SplashView: View {
    @State private var appeared = false
    @State private var dot1: CGFloat = 0.8
    @State private var dot2: CGFloat = 0.8
    @State private var dot3: CGFloat = 0.8

    var body: some View {
        ZStack {
            Color(hex: "#020a14").ignoresSafeArea()

            RadialGradient(
                colors: [Color.fnBlue.opacity(0.18), .clear],
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 0, endRadius: 360
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(FNGradient.primary)
                        .frame(width: 92, height: 92)
                        .fnShadowBrand()
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.05),
                           value: appeared)

                Spacer().frame(height: 28)

                // Wordmark
                Text("FitNow")
                    .font(.custom("DM Serif Display", size: 54))
                    .foregroundColor(.fnWhite)
                    .tracking(-1)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.2),
                               value: appeared)

                Spacer().frame(height: 10)

                Text("TU FITNESS SIN LÍMITES")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.fnSlate)
                    .tracking(3)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4).delay(0.35), value: appeared)

                Spacer()

                HStack(spacing: 10) {
                    dot(scale: dot1)
                    dot(scale: dot2)
                    dot(scale: dot3)
                }
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 64)
            }
        }
        .onAppear {
            withAnimation { appeared = true }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                dot1 = 1.4
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.2)) {
                dot2 = 1.4
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.4)) {
                dot3 = 1.4
            }
        }
    }

    private func dot(scale: CGFloat) -> some View {
        Circle()
            .fill(Color.fnBlue)
            .frame(width: 10, height: 10)
            .scaleEffect(scale)
            .opacity(Double(scale) * 0.7)
    }
}
