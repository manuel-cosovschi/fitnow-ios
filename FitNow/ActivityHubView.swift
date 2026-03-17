import SwiftUI

// MARK: - Models

struct HubPost: Identifiable {
    let id: UUID
    var type: HubPostType
    var title: String
    var body: String
    var fileURL: String?
    var fileName: String?
    let createdAt: Date

    static func make(_ type: HubPostType, title: String, body: String = "", file: String? = nil, fileName: String? = nil) -> HubPost {
        HubPost(id: UUID(), type: type, title: title, body: body, fileURL: file, fileName: fileName, createdAt: Date())
    }
}

enum HubPostType: String, CaseIterable {
    case announcement = "announcement"
    case file         = "file"
    case news         = "news"
    case quiz         = "quiz"

    var label: String {
        switch self {
        case .announcement: return "Aviso"
        case .file:         return "Archivo"
        case .news:         return "Novedad"
        case .quiz:         return "Cuestionario"
        }
    }
    var icon: String {
        switch self {
        case .announcement: return "megaphone.fill"
        case .file:         return "doc.fill"
        case .news:         return "newspaper.fill"
        case .quiz:         return "questionmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .announcement: return .fnPurple
        case .file:         return .fnCyan
        case .news:         return .fnSecondary
        case .quiz:         return .orange
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ActivityHubViewModel: ObservableObject {
    @Published var posts: [HubPost] = []
    @Published var loading = false

    private let activityId: Int

    init(activityId: Int) {
        self.activityId = activityId
        loadLocalPosts()
    }

    private func loadLocalPosts() {
        // Seed with a welcome announcement on first load
        if posts.isEmpty {
            posts = [
                .make(.announcement, title: "Bienvenidos", body: "¡Hola a todos! Este es el tablón oficial de la actividad. Acá voy a publicar avisos, rutinas y novedades."),
            ]
        }
    }

    func addPost(_ post: HubPost) {
        posts.insert(post, at: 0)
    }

    func deletePost(at offsets: IndexSet) {
        posts.remove(atOffsets: offsets)
    }
}

// MARK: - ActivityHubView

struct ActivityHubView: View {
    let activity: Activity

    @StateObject private var hubVM: ActivityHubViewModel
    @State private var showCompose = false
    @State private var selectedPost: HubPost?

    init(activity: Activity) {
        self.activity = activity
        _hubVM = StateObject(wrappedValue: ActivityHubViewModel(activityId: activity.id))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                activityHeader
                Divider().padding(.top, 4)
                postsSection
            }
        }
        .navigationTitle("Actividad")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCompose = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.fnPurple)
                }
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposePostSheet { post in
                hubVM.addPost(post)
            }
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(post: post)
        }
    }

    // MARK: Header

    private var activityHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            let info = ActivityTypeInfo.from(kind: activity.kind ?? "")
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(info.color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: info.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(info.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.title)
                        .font(.system(size: 17, weight: .bold))
                    HStack(spacing: 6) {
                        statusBadge(activity.status ?? "active")
                        if let price = activity.price {
                            Text("$\(Int(price))/mes")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func statusBadge(_ status: String) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case "active":  return ("Activa", .fnCyan)
            case "paused":  return ("Pausada", .orange)
            default:        return ("Inactiva", .secondary)
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: Posts

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Tablón")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(hubVM.posts.count) publicaciones")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if hubVM.posts.isEmpty {
                emptyPosts
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(hubVM.posts) { post in
                        postCard(post)
                            .padding(.horizontal, 16)
                            .onTapGesture { selectedPost = post }
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private var emptyPosts: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Sin publicaciones")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Tocá + para agregar un aviso, archivo, novedad o cuestionario.")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func postCard(_ post: HubPost) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(post.type.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: post.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(post.type.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(post.type.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(post.type.color)
                    Spacer()
                    Text(post.createdAt, style: .relative)
                        .font(.system(size: 11))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                Text(post.title)
                    .font(.system(size: 15, weight: .semibold))
                if !post.body.isEmpty {
                    Text(post.body)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                if let fileName = post.fileName {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 11))
                        Text(fileName)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.fnCyan)
                    .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Compose Post Sheet

struct ComposePostSheet: View {
    let onSave: (HubPost) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var postType: HubPostType = .announcement
    @State private var title = ""
    @State private var body = ""
    @State private var fileName = ""
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de publicación") {
                    Picker("Tipo", selection: $postType) {
                        ForEach(HubPostType.allCases, id: \.self) { t in
                            Label(t.label, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Contenido") {
                    TextField("Título *", text: $title)
                    TextField("Descripción (opcional)", text: $body, axis: .vertical)
                        .lineLimit(3...8)
                }
                if postType == .file {
                    Section("Archivo adjunto") {
                        HStack {
                            Image(systemName: "paperclip").foregroundColor(.fnCyan)
                            TextField("Nombre del archivo (ej: rutina_semana1.pdf)", text: $fileName)
                        }
                        Text("Próximamente: subida de archivos real desde tu dispositivo.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                if postType == .quiz {
                    Section {
                        Text("Los cuestionarios permiten enviar preguntas a tus alumnos. Esta función estará disponible próximamente.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Cuestionarios")
                    }
                }
            }
            .navigationTitle("Nueva publicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publicar") {
                        let post = HubPost.make(
                            postType,
                            title: title.trimmingCharacters(in: .whitespaces),
                            body: body.trimmingCharacters(in: .whitespaces),
                            fileName: fileName.isEmpty ? nil : fileName
                        )
                        onSave(post)
                        dismiss()
                    }
                    .bold()
                    .foregroundColor(.fnPurple)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Post Detail View

struct PostDetailView: View {
    let post: HubPost
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(post.type.color.opacity(0.12))
                                .frame(width: 48, height: 48)
                            Image(systemName: post.type.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(post.type.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.type.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(post.type.color)
                            Text(post.createdAt, style: .date)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    Text(post.title)
                        .font(.system(size: 20, weight: .bold))
                    if !post.body.isEmpty {
                        Text(post.body)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    if let fileName = post.fileName {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.fnCyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fileName)
                                    .font(.system(size: 14, weight: .medium))
                                Text("Tocar para descargar")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.fnCyan)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Publicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
