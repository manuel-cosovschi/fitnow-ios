import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Encabezado
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            // OJO: usamos auth (sin $) y la propiedad existente user (no user2)
                            Text("Hola, \(auth.user?.name ?? "¡bienvenido!")")
                                .font(.title2).bold()

                            if let email = auth.user?.email {
                                Text(email)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                    }

                    // Promo destacada
                    PromoCard(
                        title: "2×1 en clases de Yoga",
                        subtitle: "Sólo esta semana para socios",
                        buttonTitle: "Ver actividades"
                    )

                    // Accesos rápidos
                    Text("Accesos rápidos")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        NavigationLink {
                            ActivitiesListView()
                        } label: {
                            ActionCard(title: "Explorar actividades",
                                       systemImage: "magnifyingglass.circle.fill")
                        }

                        NavigationLink {
                            MyEnrollmentsView()
                        } label: {
                            ActionCard(title: "Mis inscripciones",
                                       systemImage: "list.bullet.rectangle.portrait.fill")
                        }
                    }

                    // Novedades
                    Text("Novedades")
                        .font(.headline)
                        .padding(.top, 8)

                    VStack(spacing: 12) {
                        InfoRow(icon: "sparkles", text: "Nuevos entrenadores verificados en tu zona.")
                        InfoRow(icon: "creditcard.fill", text: "Pagá con tarjeta o transferencia.")
                        InfoRow(icon: "bell.badge.fill", text: "Activá recordatorios de tus clases.")
                    }
                }
                .padding()
            }
            .navigationTitle("Inicio")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salir") { auth.logout() }
                }
            }
        }
    }
}

// MARK: - Subviews bonitas

private struct PromoCard: View {
    let title: String
    let subtitle: String
    let buttonTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundColor(.secondary)

            NavigationLink {
                ActivitiesListView()
            } label: {
                Text(buttonTitle)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [.blue.opacity(0.15), .blue.opacity(0.05)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }
}

private struct ActionCard: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
            Text(title)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color(.systemGray6)))
            Text(text)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray5))
        )
    }
}

#if DEBUG
#Preview {
    HomeView()
        .environmentObject(AuthViewModel()) // para el preview
}
#endif

