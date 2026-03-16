import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    private var initials: String {
        let parts = (auth.user?.name ?? "").split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
            .isEmpty ? "?" : parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    private var roleLabel: String {
        switch auth.user?.role {
        case "provider": return "Proveedor"
        case "admin":    return "Admin"
        default:         return "Usuario"
        }
    }

    private var roleColor: Color {
        switch auth.user?.role {
        case "provider": return .fnPurple
        case "admin":    return .fnSecondary
        default:         return .fnCyan
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Avatar Header ──
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(FNGradient.primary)
                                .frame(width: 64, height: 64)
                            Text(initials)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(auth.user?.name ?? "—")
                                .font(.system(size: 17, weight: .semibold))
                            Text(auth.user?.email ?? "—")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text(roleLabel)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(roleColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(roleColor.opacity(0.12), in: Capsule())
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // ── Seguridad ──
                Section("Seguridad") {
                    NavigationLink {
                        ChangePasswordView()
                    } label: {
                        Label("Cambiar contraseña", systemImage: "lock.rotation")
                    }
                }

                // ── Información de la app ──
                Section("Información") {
                    HStack {
                        Label("Versión", systemImage: "info.circle")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("Acerca de FitNow", systemImage: "bolt.circle")
                    }
                }

                // ── Cerrar sesión ──
                Section {
                    Button(role: .destructive) {
                        auth.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Mi perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Change Password (placeholder)
private struct ChangePasswordView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var current = ""
    @State private var newPass = ""
    @State private var confirm = ""
    @State private var message: String?
    @State private var isLoading = false

    var body: some View {
        Form {
            Section("Contraseña actual") {
                SecureField("••••••••", text: $current)
            }
            Section("Nueva contraseña") {
                SecureField("Mínimo 8 caracteres", text: $newPass)
                SecureField("Confirmar contraseña", text: $confirm)
            }
            if let msg = message {
                Section {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(msg.starts(with: "✓") ? .fnGreen : .fnSecondary)
                }
            }
            Section {
                Button {
                    guard newPass == confirm else { message = "Las contraseñas no coinciden."; return }
                    guard newPass.count >= 8 else { message = "La contraseña debe tener al menos 8 caracteres."; return }
                    // TODO: call PATCH /auth/change-password when backend supports it
                    message = "✓ Contraseña actualizada (próximamente disponible)"
                } label: {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Guardar cambios").frame(maxWidth: .infinity)
                    }
                }
                .disabled(current.isEmpty || newPass.isEmpty || confirm.isEmpty || isLoading)
            }
        }
        .navigationTitle("Cambiar contraseña")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About
private struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(FNGradient.primary)
                        .frame(width: 90, height: 90)
                        .fnShadowBrand()
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 32)

                VStack(spacing: 8) {
                    Text("FitNow")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(FNGradient.primary)
                    Text("Tu fitness, sin límites")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    infoRow(icon: "magnifyingglass", color: .fnPrimary,
                            title: "Explorá actividades",
                            body: "Encontrá entrenadores, gimnasios, clubes y deportes cerca tuyo.")
                    infoRow(icon: "list.bullet.rectangle.portrait.fill", color: .fnCyan,
                            title: "Gestioná tus inscripciones",
                            body: "Seguí todas tus clases y membresías en un solo lugar.")
                    infoRow(icon: "figure.run", color: .fnGreen,
                            title: "Planificá tus salidas",
                            body: "Usá el planificador de rutas para tus entrenamientos al aire libre.")
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Acerca de FitNow")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(body).font(.system(size: 13)).foregroundColor(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview {
    ProfileView()
        .environmentObject({
            let vm = AuthViewModel()
            vm.user = User(id: 1, name: "Juan Pérez", email: "juan@test.com", role: "user")
            return vm
        }())
}
#endif
