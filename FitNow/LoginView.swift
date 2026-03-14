import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var isRegister = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.fnPrimary.opacity(0.15),
                    Color(.systemBackground),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Logo / branding
                    brandingSection
                        .padding(.top, 60)
                        .padding(.bottom, 40)

                    // Form card
                    formCard
                        .padding(.horizontal, 24)

                    // Toggle link
                    toggleButton
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }

    // MARK: - Branding

    private var brandingSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(FNGradient.primary)
                    .frame(width: 80, height: 80)
                    .fnShadowBrand()
                Image(systemName: "bolt.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.65), value: appeared)

            VStack(spacing: 6) {
                Text("FitNow")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(FNGradient.primary)
                Text(isRegister ? "Creá tu cuenta gratis" : "Tu fitness, sin límites")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
                    .animation(.easeInOut(duration: 0.2), value: isRegister)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.spring(response: 0.55).delay(0.1), value: appeared)
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 20) {
            // Name field (register only)
            if isRegister {
                FNTextField(
                    placeholder: "Nombre completo",
                    icon: "person.fill",
                    text: $auth.name
                )
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }

            FNTextField(
                placeholder: "Email",
                icon: "envelope.fill",
                text: $auth.email,
                keyboardType: .emailAddress,
                autocapitalization: .never
            )

            FNSecureField(
                placeholder: "Contraseña",
                icon: "lock.fill",
                text: $auth.password
            )

            // Error message
            if let error = auth.error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.fnSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.fnSecondary.opacity(0.10))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Primary action button
            FitNowButton(
                title: isRegister ? "Crear cuenta" : "Iniciar sesión",
                icon: isRegister ? "person.badge.plus" : "arrow.right.circle.fill",
                isLoading: auth.loading,
                isDisabled: auth.loading
            ) {
                isRegister ? auth.register() : auth.login()
            }
            .animation(.none, value: isRegister)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.18), value: appeared)
        .animation(.spring(response: 0.4), value: isRegister)
    }

    // MARK: - Toggle Button

    private var toggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                isRegister.toggle()
                auth.error = nil
            }
        } label: {
            HStack(spacing: 4) {
                Text(isRegister ? "¿Ya tenés cuenta?" : "¿No tenés cuenta?")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.secondaryLabel))
                Text(isRegister ? "Iniciá sesión" : "Registrate gratis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.fnPrimary)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.55).delay(0.28), value: appeared)
    }
}

// MARK: - Custom Text Field

private struct FNTextField: View {
    let placeholder: String
    let icon: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.fnPrimary)
                .frame(width: 22)
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.tertiarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Custom Secure Field

private struct FNSecureField: View {
    let placeholder: String
    let icon: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.fnPrimary)
                .frame(width: 22)
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(.system(size: 15))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.tertiarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                )
        )
    }
}
