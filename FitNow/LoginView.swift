import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var isRegister = false

    var body: some View {
        VStack(spacing: 16) {
            Text(isRegister ? "Crear cuenta" : "Iniciar sesión")
                .font(.largeTitle).bold()

            if isRegister {
                TextField("Nombre", text: $auth.name)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("Email", text: $auth.email)
                .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            #endif

            SecureField("Contraseña", text: $auth.password)
                .textFieldStyle(.roundedBorder)

            if let e = auth.error {
                Text(e).foregroundColor(.red).font(.footnote)
            }

            Button(auth.loading ? "Cargando..." : (isRegister ? "Registrarme" : "Entrar")) {
                isRegister ? auth.register() : auth.login()
            }
            .buttonStyle(.borderedProminent)
            .disabled(auth.loading)

            Button(isRegister ? "Ya tengo cuenta" : "Crear una cuenta") {
                isRegister.toggle()
            }
            .font(.footnote)

            Spacer()
        }
        .padding()
    }
}




