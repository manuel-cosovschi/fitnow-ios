import SwiftUI

// MARK: - TwoFactorView

struct TwoFactorView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    let tempToken: String

    @State private var digits  = Array(repeating: "", count: 6)
    @State private var focused = 0
    @FocusState private var fieldFocus: Int?

    var body: some View {
        ZStack {
            Color.fnBg.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.fnBlue.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.fnBlue)
                }

                // Header
                VStack(spacing: 8) {
                    Text("Verificación en dos pasos")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.fnWhite)
                    Text("Ingresá el código de 6 dígitos de tu\naplicación de autenticación")
                        .font(.system(size: 14))
                        .foregroundColor(.fnSlate)
                        .multilineTextAlignment(.center)
                }

                // OTP input
                otpField

                // Error
                if let error = auth.twoFactorError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.fnCrimson)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.fnCrimson.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 24)
                }

                // Verify button
                FitNowButton(
                    title: "Verificar",
                    icon: "checkmark.shield.fill",
                    isLoading: auth.loading,
                    isDisabled: code.count < 6 || auth.loading
                ) {
                    auth.verifyTwoFactor(tempToken: tempToken, code: code)
                }
                .padding(.horizontal, 32)

                // Cancel
                Button("Cancelar y volver al login") {
                    auth.cancelTwoFactor()
                    dismiss()
                }
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { fieldFocus = 0 }
        .onChange(of: auth.isAuthenticated) { _, isAuth in
            if isAuth { dismiss() }
        }
    }

    // MARK: - OTP field

    private var otpField: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { idx in
                digitCell(idx)
            }
        }
        .padding(.horizontal, 24)
    }

    private func digitCell(_ idx: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.fnElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            fieldFocus == idx ? Color.fnBlue : Color.fnBorder,
                            lineWidth: fieldFocus == idx ? 2 : 1
                        )
                )
                .frame(width: 46, height: 56)

            if idx < digits.count {
                Text(digits[idx].isEmpty ? "" : "●")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.fnWhite)
            }

            TextField("", text: Binding(
                get: { digits[idx] },
                set: { newVal in handleInput(newVal, at: idx) }
            ))
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .foregroundColor(.clear)
            .accentColor(.clear)
            .frame(width: 46, height: 56)
            .focused($fieldFocus, equals: idx)
        }
        .onTapGesture { fieldFocus = idx }
    }

    private func handleInput(_ value: String, at idx: Int) {
        let filtered = value.filter { $0.isNumber }
        if filtered.isEmpty {
            digits[idx] = ""
            if idx > 0 { fieldFocus = idx - 1 }
        } else {
            let char = String(filtered.last!)
            digits[idx] = char
            if idx < 5 { fieldFocus = idx + 1 }
        }
    }

    private var code: String { digits.joined() }
}
