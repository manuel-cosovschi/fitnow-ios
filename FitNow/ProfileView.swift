import SwiftUI
import Combine

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthViewModel

    private var initials: String {
        let parts = (auth.user?.name ?? "").split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
            .isEmpty ? "?" : parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    private var roleLabel: String {
        switch auth.user?.role {
        case "provider_admin": return "Proveedor"
        case "admin":    return "Admin"
        default:         return "Usuario"
        }
    }

    private var roleColor: Color {
        switch auth.user?.role {
        case "provider_admin": return .fnPurple
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

                // ── Mi cuenta ──
                Section("Mi cuenta") {
                    NavigationLink {
                        PersonalInfoView()
                    } label: {
                        Label("Información personal", systemImage: "person.circle")
                    }
                    // Provider-only items
                    if auth.user?.role == "provider_admin" {
                        if let pid = auth.user?.provider_id {
                            NavigationLink {
                                ProviderInfoView(providerId: pid)
                            } label: {
                                Label("Mi local", systemImage: "building.2.fill")
                                    .foregroundColor(.fnPurple)
                            }
                        }
                        NavigationLink {
                            ProviderMyOffersView()
                        } label: {
                            Label("Mis ofertas especiales", systemImage: "tag.fill")
                                .foregroundColor(.fnYellow)
                        }
                    }
                    // User-only items
                    if auth.user?.role != "provider_admin" && auth.user?.role != "admin" {
                        NavigationLink {
                            MembershipView()
                        } label: {
                            Label("Membresía", systemImage: "star.circle")
                        }
                        NavigationLink {
                            FavoritesView()
                        } label: {
                            Label("Favoritos", systemImage: "heart.fill")
                        }
                        NavigationLink {
                            CalendarView()
                        } label: {
                            Label("Calendario", systemImage: "calendar")
                        }
                        NavigationLink {
                            MyEnrollmentsView()
                        } label: {
                            Label("Mis clases", systemImage: "calendar.badge.checkmark")
                        }
                    }
                    // Admin-only: dashboard
                    if auth.user?.role == "admin" {
                        NavigationLink {
                            AdminView()
                        } label: {
                            Label("Panel de administración", systemImage: "shield.fill")
                                .foregroundColor(.fnSecondary)
                        }
                    }
                }

                // ── Actividad ──
                if auth.user?.role != "provider_admin" && auth.user?.role != "admin" {
                    Section("Actividad") {
                        NavigationLink {
                            GamificationView()
                        } label: {
                            Label("Mi progreso", systemImage: "trophy.fill")
                                .foregroundColor(.fnYellow)
                        }
                        NavigationLink {
                            AnalyticsView()
                        } label: {
                            Label("Rendimiento", systemImage: "chart.bar.fill")
                                .foregroundColor(.fnCyan)
                        }
                        NavigationLink {
                            TrainingPlanHubView()
                        } label: {
                            Label("Planes de entrenamiento", systemImage: "brain.head.profile")
                                .foregroundColor(.fnPurple)
                        }
                    }
                }

                // ── FitNow+ ──
                Section {
                    NavigationLink { FitNowPlusView() } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.fnPurple.opacity(0.14)).frame(width: 32, height: 32)
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.fnPurple)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("FitNow+")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(StoreKitService.shared.isPlusActive ? "Suscripción activa" : "Desbloquear funciones premium")
                                    .font(.system(size: 12))
                                    .foregroundColor(StoreKitService.shared.isPlusActive ? .fnGreen : .fnSlate)
                            }
                        }
                    }
                }

                // ── Pagos ──
                Section("Pagos") {
                    NavigationLink { SavedPaymentsView() } label: {
                        Label("Métodos de pago guardados", systemImage: "creditcard.fill")
                    }
                }

                // ── Seguridad ──
                Section("Seguridad") {
                    NavigationLink {
                        ChangePasswordView()
                    } label: {
                        Label("Cambiar contraseña", systemImage: "lock.rotation")
                    }
                }

                // ── Configuración ──
                Section("Configuración") {
                    NavigationLink {
                        AppSettingsView()
                    } label: {
                        Label("Preferencias", systemImage: "gearshape")
                    }
                }

                // ── Información de la app ──
                Section("Información") {
                    NavigationLink {
                        TermsView()
                    } label: {
                        Label("Términos y condiciones", systemImage: "doc.text")
                    }
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
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Personal Info
private struct PersonalInfoView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Form {
            Section("Nombre") {
                Text(auth.user?.name ?? "—")
                    .foregroundColor(.primary)
            }
            Section("Email") {
                Text(auth.user?.email ?? "—")
                    .foregroundColor(.primary)
            }
            Section("Rol") {
                Text({
                    switch auth.user?.role {
                    case "provider_admin": return "Proveedor"
                    case "admin":    return "Admin"
                    default:         return "Usuario"
                    }
                }())
                .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Información personal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Membership
private struct MembershipView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(FNGradient.primary)
                        .frame(width: 80, height: 80)
                        .fnShadowBrand()
                    Image(systemName: "star.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 40)

                VStack(spacing: 8) {
                    Text("Plan Gratuito")
                        .font(.custom("DM Serif Display", size: 26))
                    Text("Accedé a actividades básicas sin costo")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 0) {
                    membershipRow(icon: "checkmark.circle.fill", color: .fnGreen, text: "Búsqueda de actividades")
                    Divider().padding(.leading, 44)
                    membershipRow(icon: "checkmark.circle.fill", color: .fnGreen, text: "Inscripción a clases")
                    Divider().padding(.leading, 44)
                    membershipRow(icon: "checkmark.circle.fill", color: .fnGreen, text: "Historial de actividades")
                    Divider().padding(.leading, 44)
                    membershipRow(icon: "lock.fill", color: .fnSlate.opacity(0.7), text: "Descuentos exclusivos (Premium)")
                    Divider().padding(.leading, 44)
                    membershipRow(icon: "lock.fill", color: .fnSlate.opacity(0.7), text: "Rutas ilimitadas (Premium)")
                }
                .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)

                Text("Próximamente podrás actualizar a Premium")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Membresía")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func membershipRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - App Settings
private struct AppSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("weeklyDigest") private var weeklyDigest = false

    var body: some View {
        Form {
            Section("Notificaciones") {
                Toggle("Recordatorios de actividades", isOn: $notificationsEnabled)
                Toggle("Resumen semanal", isOn: $weeklyDigest)
            }
            Section("Apariencia") {
                HStack {
                    Label("Tema", systemImage: "circle.lefthalf.filled")
                    Spacer()
                    Text("Sistema")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
            }
        }
        .navigationTitle("Preferencias")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Terms
private struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    termSection(title: "1. Aceptación de los términos",
                        body: "Al usar FitNow, aceptás estos términos y condiciones de uso. Si no estás de acuerdo con alguna parte, por favor no uses la aplicación.")
                    termSection(title: "2. Uso del servicio",
                        body: "FitNow es una plataforma para conectar usuarios con proveedores de actividades físicas. El servicio se ofrece tal como está, sin garantías de disponibilidad continua.")
                    termSection(title: "3. Inscripciones y pagos",
                        body: "Las inscripciones a actividades son gestionadas a través de la plataforma. Los pagos se procesan directamente con cada proveedor. FitNow no se responsabiliza por disputas de pago entre usuarios y proveedores.")
                    termSection(title: "4. Privacidad de datos",
                        body: "Tus datos personales (nombre, email) se usan únicamente para autenticación y personalización dentro de la app. No compartimos tu información con terceros sin consentimiento.")
                    termSection(title: "5. Cancelaciones",
                        body: "Podés cancelar tu inscripción a una actividad desde la sección 'Mis inscripciones'. Las políticas de reembolso dependen de cada proveedor.")
                    termSection(title: "6. Modificaciones",
                        body: "FitNow se reserva el derecho de modificar estos términos en cualquier momento. Te notificaremos de cambios importantes a través de la aplicación.")
                }
                .padding(.horizontal, 20)

                Text("Última actualización: marzo 2026")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
            .padding(.top, 20)
        }
        .navigationTitle("Términos y condiciones")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func termSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(body)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Change Password
private struct ChangePasswordView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var current = ""
    @State private var newPass = ""
    @State private var confirm = ""
    @State private var message: String?
    @State private var isLoading = false
    @State private var bag = Set<AnyCancellable>()

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
                    submit()
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

    private func submit() {
        guard newPass == confirm else { message = "Las contraseñas no coinciden."; return }
        guard newPass.count >= 8 else { message = "La contraseña debe tener al menos 8 caracteres."; return }

        let payload: [String: String] = [
            "current_password": current,
            "new_password": newPass
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }

        isLoading = true
        message = nil
        APIClient.shared.requestPublisher("auth/me/password", method: "POST", body: data, authorized: true)
            .sink { completion in
                isLoading = false
                if case .failure(let e) = completion {
                    if case APIError.http(let code, let body) = e {
                        if code == 401 || (code == 400 && body.lowercased().contains("current")) {
                            message = "La contraseña actual es incorrecta."
                        } else {
                            message = "No se pudo actualizar la contraseña."
                        }
                    } else {
                        message = e.localizedDescription
                    }
                }
            } receiveValue: { (_: SimpleOK) in
                message = "✓ Contraseña actualizada."
                current = ""
                newPass = ""
                confirm = ""
            }
            .store(in: &bag)
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
                        .font(.custom("DM Serif Display", size: 32))
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

// MARK: - Provider Info View

struct ProviderInfoView: View {
    let providerId: Int

    @State private var providerName = ""
    @State private var kind = "gym"
    @State private var description = ""
    @State private var address = ""
    @State private var city = ""
    @State private var phone = ""
    @State private var website = ""
    @State private var loading = true
    @State private var saving = false
    @State private var message: String?
    @State private var bag = Set<AnyCancellable>()

    private let kinds = ["gym", "studio", "trainer", "club", "other"]
    private func kindLabel(_ k: String) -> String {
        switch k {
        case "gym": return "Gimnasio"
        case "studio": return "Estudio"
        case "trainer": return "Entrenador personal"
        case "club": return "Club deportivo"
        default: return "Otro"
        }
    }

    var body: some View {
        Form {
            if loading {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }
            } else {
                Section("Nombre del local") {
                    TextField("Nombre", text: $providerName)
                }
                Section("Tipo de proveedor") {
                    Picker("Tipo", selection: $kind) {
                        ForEach(kinds, id: \.self) { k in
                            Text(kindLabel(k)).tag(k)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Descripción") {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }
                Section("Dirección") {
                    TextField("Dirección", text: $address)
                    TextField("Ciudad", text: $city)
                }
                Section("Contacto") {
                    TextField("Teléfono", text: $phone).keyboardType(.phonePad)
                    TextField("Sitio web", text: $website).keyboardType(.URL).textInputAutocapitalization(.never)
                }
                if let msg = message {
                    Section {
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundColor(msg.hasPrefix("✓") ? .fnGreen : .fnSecondary)
                    }
                }
                Section {
                    Button {
                        save()
                    } label: {
                        if saving {
                            HStack { Spacer(); ProgressView(); Spacer() }
                        } else {
                            Text("Guardar cambios").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(saving || providerName.isEmpty)
                }
            }
        }
        .navigationTitle("Mi local")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadProvider() }
    }

    private func loadProvider() {
        loading = true
        APIClient.shared.requestPublisher("providers/\(providerId)")
            .sink { _ in loading = false }
                   receiveValue: { (p: Provider) in
                loading = false
                providerName = p.name
                kind         = p.kind ?? "gym"
                description  = p.description ?? ""
                address      = p.address ?? ""
                city         = p.city ?? ""
                phone        = p.phone ?? ""
                website      = p.website_url ?? ""
            }
            .store(in: &bag)
    }

    private func save() {
        saving = true; message = nil
        var payload: [String: String] = [
            "name": providerName,
            "kind": kind,
            "description": description,
            "address": address,
            "city": city,
            "phone": phone,
            "website_url": website
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        APIClient.shared.requestPublisher("providers/\(providerId)", method: "PATCH", body: data)
            .sink { completion in
                saving = false
                if case .failure = completion { message = "Error al guardar. Intentá de nuevo." }
            } receiveValue: { (_: Provider) in
                saving = false
                message = "✓ Información actualizada"
            }
            .store(in: &bag)
    }
}

#if DEBUG
#Preview {
    ProfileView()
        .environmentObject({
            let vm = AuthViewModel()
            vm.user = User(id: 1, name: "Juan Pérez", email: "juan@test.com", role: "user", provider_id: nil)
            return vm
        }())
}
#endif
