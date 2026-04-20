import SwiftUI
import Combine

// MARK: - Backend Model

struct ActivityPost: Identifiable, Decodable {
    let id: Int
    let activity_id: Int
    let provider_id: Int
    let type: String
    let title: String
    let body: String?
    let file_url: String?
    let file_name: String?
    let created_at: String

    var postType: HubPostType {
        HubPostType(rawValue: type) ?? .announcement
    }

    var createdDate: Date {
        let fracF = ISO8601DateFormatter()
        fracF.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let basicF = ISO8601DateFormatter()
        basicF.formatOptions = [.withInternetDateTime]
        return fracF.date(from: created_at) ?? basicF.date(from: created_at) ?? Date()
    }
}

// MARK: - Post Type

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
    @Published var posts: [ActivityPost] = []
    @Published var loading = false
    @Published var error: String?

    private let activityId: Int
    private var bag = Set<AnyCancellable>()

    init(activityId: Int) {
        self.activityId = activityId
        load()
    }

    func load() {
        loading = true
        error = nil
        APIClient.shared.request("activities/\(activityId)/posts", authorized: false)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion {
                    self?.error = e.localizedDescription
                }
            } receiveValue: { [weak self] (resp: ListResponse<ActivityPost>) in
                self?.posts = resp.items
            }
            .store(in: &bag)
    }

    func addPost(type: HubPostType, title: String, body: String, fileName: String?) {
        var dict: [String: Any] = ["type": type.rawValue, "title": title]
        if !body.isEmpty { dict["body"] = body }
        if let fn = fileName, !fn.isEmpty { dict["file_name"] = fn }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        APIClient.shared.request(
            "activities/\(activityId)/posts",
            method: "POST",
            body: data,
            authorized: true
        )
        .sink { _ in }
        receiveValue: { [weak self] (_: ActivityPost) in
            self?.load()
        }
        .store(in: &bag)
    }

    func deletePost(_ post: ActivityPost) {
        // Optimistic remove
        posts.removeAll { $0.id == post.id }
        // Fire-and-forget (backend returns 204, no body)
        APIClient.shared.request(
            "activities/\(activityId)/posts/\(post.id)",
            method: "DELETE",
            authorized: true
        )
        .sink { [weak self] completion in
            if case .failure = completion { self?.load() }
        }
        receiveValue: { (_: SimpleOK) in }
        .store(in: &bag)
    }
}

// MARK: - ActivityHubView

struct ActivityHubView: View {
    let activity: Activity

    @StateObject private var hubVM: ActivityHubViewModel
    @State private var showCompose = false
    @State private var selectedPost: ActivityPost?

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
            ComposePostSheet { type, title, body, fileName in
                hubVM.addPost(type: type, title: title, body: body, fileName: fileName)
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
                if hubVM.loading {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Text("\(hubVM.posts.count) publicaciones")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if let err = hubVM.error {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            } else if hubVM.posts.isEmpty && !hubVM.loading {
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

    private func postCard(_ post: ActivityPost) -> some View {
        let pType = post.postType
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(pType.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: pType.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(pType.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pType.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(pType.color)
                    Spacer()
                    Text(post.createdDate, style: .relative)
                        .font(.system(size: 11))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                Text(post.title)
                    .font(.system(size: 15, weight: .semibold))
                if let body = post.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                if let fileName = post.file_name {
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
    let onSave: (HubPostType, String, String, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var postType: HubPostType = .announcement
    @State private var title = ""
    @State private var postBody = ""
    @State private var fileName = ""

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
                    TextField("Descripción (opcional)", text: $postBody, axis: .vertical)
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
                        onSave(postType, title.trimmingCharacters(in: .whitespaces),
                               postBody.trimmingCharacters(in: .whitespaces),
                               fileName.isEmpty ? nil : fileName)
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
    let post: ActivityPost
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    let pType = post.postType
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(pType.color.opacity(0.12))
                                .frame(width: 48, height: 48)
                            Image(systemName: pType.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(pType.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pType.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(pType.color)
                            Text(post.createdDate, style: .date)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    Text(post.title)
                        .font(.system(size: 20, weight: .bold))
                    if let body = post.body, !body.isEmpty {
                        Text(body)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    if let fileName = post.file_name {
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
