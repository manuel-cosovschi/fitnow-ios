import SwiftUI
import Combine

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var isRegister = false
    @State private var appeared = false
    @State private var showAdminLogin = false
    @State private var showForgotPassword = false

    private let roles = ["Usuario", "Proveedor"]

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
                        .padding(.bottom, 16)

                    // Admin access
                    Button {
                        showAdminLogin = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Acceso Admin")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(Color(.tertiaryLabel))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemBackground), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showAdminLogin) {
            AdminLoginSheet()
                .environmentObject(auth)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet()
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
            // Role picker (register only)
            if isRegister {
                Picker("Tipo de cuenta", selection: Binding(
                    get: { auth.selectedRole },
                    set: { auth.selectedRole = $0 }
                )) {
                    Text("Usuario").tag("user")
                    Text("Proveedor").tag("provider_admin")
                }
                .pickerStyle(.segmented)
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }

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

            // Provider name field (register as provider only)
            if isRegister && auth.selectedRole == "provider_admin" {
                FNTextField(
                    placeholder: "Nombre del local / negocio",
                    icon: "building.2.fill",
                    text: $auth.providerName
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
        VStack(spacing: 12) {
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

            if !isRegister {
                Button {
                    showForgotPassword = true
                } label: {
                    Text("¿Olvidaste tu contraseña?")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
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

// MARK: - Forgot Password Sheet

struct ForgotPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 1   // 1 = enter email, 2 = enter code + new pass
    @State private var email = ""
    @State private var token = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var loading = false
    @State private var message: String?
    @State private var isError = false
    @State private var bag = Set<AnyCancellable>()

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Color.fnPrimary.opacity(0.12))
                        .frame(width: 70, height: 70)
                    Image(systemName: "key.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.fnPrimary)
                }
                .padding(.top, 8)

                VStack(spacing: 4) {
                    Text(step == 1 ? "Recuperar contraseña" : "Nueva contraseña")
                        .font(.system(size: 18, weight: .bold))
                    Text(step == 1
                         ? "Ingresá tu email y te enviaremos un código de recuperación."
                         : "Ingresá el código que recibiste por email y tu nueva contraseña.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                VStack(spacing: 12) {
                    if step == 1 {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 14)).foregroundColor(.fnPrimary).frame(width: 20)
                            TextField("tu@email.com", text: $email)
                                .font(.system(size: 15))
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "number.circle.fill")
                                .font(.system(size: 14)).foregroundColor(.fnPrimary).frame(width: 20)
                            TextField("Código de verificación", text: $token)
                                .font(.system(size: 15))
                                .keyboardType(.numberPad)
                                .textInputAutocapitalization(.never)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14)).foregroundColor(.fnPrimary).frame(width: 20)
                            SecureField("Nueva contraseña", text: $newPassword)
                                .font(.system(size: 15))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14)).foregroundColor(.fnPrimary).frame(width: 20)
                            SecureField("Confirmar contraseña", text: $confirmPassword)
                                .font(.system(size: 15))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                if let msg = message {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(isError ? .fnSecondary : .fnGreen)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Button {
                    step == 1 ? sendCode() : resetPassword()
                } label: {
                    HStack {
                        Spacer()
                        if loading {
                            ProgressView().tint(.white)
                        } else {
                            Text(step == 1 ? "Enviar código" : "Cambiar contraseña")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 15)
                    .background(Color.fnPrimary, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(loading)

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                if step == 2 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation { step = 1; message = nil }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
        }
    }

    private func sendCode() {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            isError = true; message = "Ingresá tu email."; return
        }
        loading = true; message = nil
        let payload = ["email": email.trimmingCharacters(in: .whitespaces)]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        APIClient.shared.request("auth/forgot-password", method: "POST", body: data, authorized: false)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                loading = false
                if case .failure(let e) = completion {
                    isError = true
                    message = (e as? APIError).flatMap { if case .http(let c, _) = $0, c == 404 { return "No encontramos una cuenta con ese email." } else { return nil } }
                        ?? "Error al enviar el código. Intentá de nuevo."
                }
            } receiveValue: { (_: SimpleOK) in
                isError = false
                message = "✓ Código enviado a \(email). Revisá tu casilla."
                withAnimation { step = 2 }
            }
            .store(in: &bag)
    }

    private func resetPassword() {
        guard !token.isEmpty else { isError = true; message = "Ingresá el código recibido."; return }
        guard newPassword.count >= 8 else { isError = true; message = "La contraseña debe tener al menos 8 caracteres."; return }
        guard newPassword == confirmPassword else { isError = true; message = "Las contraseñas no coinciden."; return }
        loading = true; message = nil
        let payload: [String: Any] = ["token": token, "password": newPassword]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        APIClient.shared.request("auth/reset-password", method: "POST", body: data, authorized: false)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                loading = false
                if case .failure = completion {
                    isError = true; message = "Código inválido o expirado. Solicitá uno nuevo."
                }
            } receiveValue: { (_: SimpleOK) in
                isError = false
                message = "✓ Contraseña actualizada. Ya podés iniciar sesión."
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { dismiss() }
            }
            .store(in: &bag)
    }
}

// MARK: - Admin Login Sheet

private struct AdminLoginSheet: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var adminEmail    = "admin@fitnow.com"
    @State private var adminPassword = "Admin1234!"
    @State private var localError: String?
    @State private var loading = false
    @State private var cancellable: AnyCancellable?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.fnSecondary.opacity(0.12))
                        .frame(width: 70, height: 70)
                    Image(systemName: "shield.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.fnSecondary)
                }
                .padding(.top, 8)

                VStack(spacing: 4) {
                    Text("Panel de Administración")
                        .font(.system(size: 18, weight: .bold))
                    Text("Acceso restringido")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.fnSecondary)
                            .frame(width: 20)
                        TextField("Email", text: $adminEmail)
                            .font(.system(size: 15))
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.fnSecondary)
                            .frame(width: 20)
                        SecureField("Contraseña", text: $adminPassword)
                            .font(.system(size: 15))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                if let err = localError {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.fnSecondary)
                        .multilineTextAlignment(.center)
                }



                Button {
                    adminLogin()
                } label: {
                    HStack {
                        Spacer()
                        if loading {
                            ProgressView().tint(.white)
                        } else {
                            Label("Ingresar como Admin", systemImage: "arrow.right.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 15)
                    .background(Color.fnSecondary, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(loading)

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func adminLogin() {
        localError = nil
        loading = true
        guard let data = try? JSONSerialization.data(withJSONObject: ["email": adminEmail, "password": adminPassword]) else { return }
        cancellable = APIClient.shared.request("auth/login", method: "POST", body: data, authorized: false)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                loading = false
                if case .failure(let e) = completion {
                    if case APIError.http(let code, _) = e {
                        switch code {
                        case 401: localError = "Email o contraseña incorrectos."
                        case 403: localError = "No tenés permisos de administrador."
                        case 404: localError = "Usuario no encontrado."
                        default:  localError = "Error al iniciar sesión (código \(code))."
                        }
                    } else {
                        localError = "No se pudo conectar. Verificá tu conexión a internet."
                    }
                }
            } receiveValue: { (resp: AuthResponse) in
                loading = false
                let role = resp.user.role ?? ""
                guard role == "admin" else {
                    localError = "Esta cuenta no tiene permisos de administrador."
                    return
                }
                APIClient.shared.setToken(resp.token)
                let u = User(id: resp.user.id, name: resp.user.name, email: resp.user.email, role: "admin", provider_id: nil)
                if let d = try? JSONEncoder().encode(u) { UserDefaults.standard.set(d, forKey: "saved_user") }
                auth.user = u
                auth.isAuthenticated = true
                dismiss()
            }
    }
}
