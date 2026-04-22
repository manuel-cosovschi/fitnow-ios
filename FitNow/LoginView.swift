import SwiftUI
import Combine

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var isRegister = false
    @State private var appeared = false
    @State private var showAdminLogin = false

    var body: some View {
        ZStack {
            Color.fnBg.ignoresSafeArea()

            // Top gradient overlay
            VStack {
                LinearGradient(
                    colors: [Color.fnBlue.opacity(0.18), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 320)
                Spacer()
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    brandingSection
                        .padding(.top, 60)
                        .padding(.bottom, 40)

                    formCard
                        .padding(.horizontal, 24)

                    toggleButton
                        .padding(.top, 24)
                        .padding(.bottom, 16)

                    Button { showAdminLogin = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Acceso Admin")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.fnSlate)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.fnElevated, in: Capsule())
                        .overlay(Capsule().stroke(Color.fnBorder, lineWidth: 1))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showAdminLogin) {
            AdminLoginSheet().environmentObject(auth)
        }
    }

    // MARK: - Branding

    private var brandingSection: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(FNGradient.primary)
                    .frame(width: 72, height: 72)
                    .fnShadowBrand()
                Image(systemName: "bolt.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.65), value: appeared)

            VStack(spacing: 8) {
                Text("FitNow")
                    .font(.custom("DM Serif Display", size: 36))
                    .foregroundColor(.fnWhite)

                Text(isRegister ? "Creá tu cuenta gratis" : "Bienvenido de vuelta")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.fnSlate)
                    .animation(.easeInOut(duration: 0.2), value: isRegister)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.spring(response: 0.55).delay(0.1), value: appeared)
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 16) {
            if isRegister {
                HStack(spacing: 12) {
                    roleCard(icon: "person.fill",
                             title: "Atleta",
                             subtitle: "Quiero entrenar",
                             color: .fnBlue,
                             isSelected: auth.selectedRole == "user") {
                        auth.selectedRole = "user"
                    }
                    roleCard(icon: "building.2.fill",
                             title: "Proveedor",
                             subtitle: "Ofrezco clases",
                             color: .fnPurple,
                             isSelected: auth.selectedRole == "provider_admin") {
                        auth.selectedRole = "provider_admin"
                    }
                }
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal:   .push(from: .bottom).combined(with: .opacity)
                ))
            }

            if isRegister {
                fnField(placeholder: "Nombre completo",
                        icon: "person.fill",
                        text: $auth.name)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal:   .push(from: .bottom).combined(with: .opacity)
                    ))
            }

            if isRegister && auth.selectedRole == "provider_admin" {
                fnField(placeholder: "Nombre del local / negocio",
                        icon: "building.2.fill",
                        text: $auth.providerName)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal:   .push(from: .bottom).combined(with: .opacity)
                    ))
            }

            fnField(placeholder: "Email",
                    icon: "envelope.fill",
                    text: $auth.email,
                    keyboardType: .emailAddress,
                    autocapitalization: .never)

            fnSecureField(placeholder: "Contraseña",
                          icon: "lock.fill",
                          text: $auth.password)

            if let error = auth.error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.fnCrimson)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.fnCrimson.opacity(0.12))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            FitNowButton(
                title: isRegister ? "Crear cuenta" : "Iniciar sesión",
                icon: isRegister ? "person.badge.plus" : "arrow.right.circle.fill",
                isLoading: auth.loading,
                isDisabled: auth.loading
            ) {
                isRegister ? auth.register() : auth.login()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.fnSurface)
                .overlay(RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.fnBorder, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.18), value: appeared)
        .animation(.spring(response: 0.4), value: isRegister)
    }

    private func roleCard(icon: String,
                          title: String,
                          subtitle: String,
                          color: Color,
                          isSelected: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color.opacity(0.22) : Color.fnElevated)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? color : .fnSlate)
                }
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isSelected ? .fnWhite : .fnSlate)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.fnSlate)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.fnElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? color : Color.fnBorder,
                                    lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func fnField(placeholder: String,
                         icon: String,
                         text: Binding<String>,
                         keyboardType: UIKeyboardType = .default,
                         autocapitalization: TextInputAutocapitalization = .sentences) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.fnBlue)
                .frame(width: 22)
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .foregroundColor(.fnWhite)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.fnElevated)
        .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.fnBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func fnSecureField(placeholder: String,
                               icon: String,
                               text: Binding<String>) -> some View {
        FNDarkSecureField(placeholder: placeholder, icon: icon, text: text)
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
                    .foregroundColor(.fnSlate)
                Text(isRegister ? "Iniciá sesión" : "Registrate gratis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.fnBlue)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.55).delay(0.28), value: appeared)
    }
}

// MARK: - Dark Secure Field

private struct FNDarkSecureField: View {
    let placeholder: String
    let icon: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.fnBlue)
                .frame(width: 22)
            Group {
                if isVisible { TextField(placeholder, text: $text) }
                else         { SecureField(placeholder, text: $text) }
            }
            .font(.system(size: 15))
            .foregroundColor(.fnWhite)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button { isVisible.toggle() } label: {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.fnAsh)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.fnElevated)
        .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.fnBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            ZStack {
                Color.fnBg.ignoresSafeArea()

                VStack(spacing: 24) {
                    ZStack {
                        Circle().fill(Color.fnCrimson.opacity(0.14)).frame(width: 70, height: 70)
                        Image(systemName: "shield.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.fnCrimson)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 4) {
                        Text("Panel de Administración")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.fnWhite)
                        Text("Acceso restringido")
                            .font(.system(size: 13))
                            .foregroundColor(.fnSlate)
                    }

                    VStack(spacing: 12) {
                        adminRow(icon: "envelope.fill") {
                            TextField("Email", text: $adminEmail)
                                .font(.system(size: 15))
                                .foregroundColor(.fnWhite)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        adminRow(icon: "lock.fill") {
                            SecureField("Contraseña", text: $adminPassword)
                                .font(.system(size: 15))
                                .foregroundColor(.fnWhite)
                        }
                    }

                    if let err = localError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.fnCrimson)
                            .multilineTextAlignment(.center)
                    }

                    Button { adminLogin() } label: {
                        HStack {
                            Spacer()
                            if loading {
                                ProgressView().tint(.white)
                            } else {
                                Label("Ingresar como Admin",
                                      systemImage: "arrow.right.circle.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 15)
                        .background(FNGradient.danger, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(loading)
                    .fnShadowColored(.fnCrimson, radius: 16, y: 6)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundColor(.fnSlate)
                }
            }
            .toolbarBackground(Color.fnBg, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func adminRow<Field: View>(icon: String,
                                        @ViewBuilder field: () -> Field) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.fnCrimson)
                .frame(width: 20)
            field()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.fnElevated, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.fnBorder, lineWidth: 1))
    }

    private func adminLogin() {
        localError = nil; loading = true
        guard let data = try? JSONSerialization.data(
            withJSONObject: ["email": adminEmail, "password": adminPassword]
        ) else { return }
        cancellable = APIClient.shared
            .request("auth/login", method: "POST", body: data, authorized: false)
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
                let u = User(id: resp.user.id,
                             name: resp.user.name,
                             email: resp.user.email,
                             role: "admin",
                             provider_id: nil)
                if let d = try? JSONEncoder().encode(u) {
                    UserDefaults.standard.set(d, forKey: "saved_user")
                }
                auth.user = u
                auth.isAuthenticated = true
                dismiss()
            }
    }
}
