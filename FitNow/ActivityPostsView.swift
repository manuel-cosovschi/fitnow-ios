import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ActivityPostsViewModel
// ─────────────────────────────────────────────────────────────────────────────

final class ActivityPostsViewModel: ObservableObject {
    @Published var posts: [ActivityPost] = []
    @Published var loading = false
    @Published var error: String?

    private var bag = Set<AnyCancellable>()

    func load(activityId: Int) {
        loading = true; error = nil
        APIClient.shared.request("activities/\(activityId)/posts", authorized: false)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: ActivityPostsResponse) in
                self?.posts = resp.items
            }
            .store(in: &bag)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ActivityPostsSection
// Embedded section shown inside ActivityDetailView when there are posts.
// ─────────────────────────────────────────────────────────────────────────────

struct ActivityPostsSection: View {
    let activityId: Int
    @StateObject private var vm = ActivityPostsViewModel()

    var body: some View {
        Group {
            if vm.loading && vm.posts.isEmpty {
                postsLoading
            } else if !vm.posts.isEmpty {
                postsContent
            }
            // If empty (no posts) render nothing — keep the view uncluttered
        }
        .onAppear { vm.load(activityId: activityId) }
    }

    private var postsLoading: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Novedades")
            SkeletonView(cornerRadius: 12).frame(height: 72)
            SkeletonView(cornerRadius: 12).frame(height: 72)
        }
    }

    private var postsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Novedades")
            VStack(spacing: 8) {
                ForEach(vm.posts) { post in
                    postCard(post)
                }
            }
        }
    }

    private func postCard(_ post: ActivityPost) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.fnPrimary.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.fnPrimary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    if let title = post.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(.label))
                    }
                    Text(post.body)
                        .font(.system(size: 14))
                        .foregroundColor(Color(.secondaryLabel))
                        .lineLimit(4)
                }
            }
            if let dateStr = post.created_at {
                Text(formattedDate(dateStr))
                    .font(.system(size: 11))
                    .foregroundColor(Color(.tertiaryLabel))
                    .padding(.leading, 46)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.fnPrimary.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func formattedDate(_ s: String) -> String {
        let parsers: [DateFormatter] = []
        let isoFrac: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
        let isoBasic: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }()
        let mysql: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f }()
        let out: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "es_AR"); f.dateStyle = .medium; f.timeStyle = .none; return f }()
        _ = parsers // suppress warning
        if let d = isoFrac.date(from: s) ?? isoBasic.date(from: s) ?? mysql.date(from: s) {
            return out.string(from: d)
        }
        return s
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ActivityPostsView (standalone, full-screen)
// Used when user taps "Ver todas las novedades" from detail view.
// ─────────────────────────────────────────────────────────────────────────────

struct ActivityPostsView: View {
    let activityId: Int
    let activityTitle: String

    @StateObject private var vm = ActivityPostsViewModel()
    @State private var appeared = false

    var body: some View {
        Group {
            if vm.loading && vm.posts.isEmpty {
                loadingState
            } else if let err = vm.error {
                errorState(err)
            } else if vm.posts.isEmpty {
                emptyState
            } else {
                postsList
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Novedades")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            vm.load(activityId: activityId)
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
    }

    private var postsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(Array(vm.posts.enumerated()), id: \.element.id) { index, post in
                    fullPostCard(post)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 18)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.06), value: appeared)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func fullPostCard(_ post: ActivityPost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(FNGradient.primary)
                        .frame(width: 44, height: 44)
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if let title = post.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.label))
                    }
                    if let dateStr = post.created_at {
                        Text(formattedDate(dateStr))
                            .font(.system(size: 12))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
                Spacer()
            }
            Text(post.body)
                .font(.system(size: 15))
                .foregroundColor(Color(.label))
                .lineSpacing(4)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator).opacity(0.3), lineWidth: 0.5))
        .fnShadow()
    }

    private var loadingState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonView(cornerRadius: 16).frame(height: 110)
                }
            }
            .padding(.horizontal, 16).padding(.top, 14)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "megaphone.slash")
                .font(.system(size: 52))
                .foregroundColor(Color(.tertiaryLabel))
            Text("Sin novedades por ahora")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text("Cuando el proveedor publique novedades sobre esta actividad, las verás acá.")
                .font(.system(size: 14))
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
            Spacer()
        }
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(.fnYellow)
            Text(msg)
                .font(.system(size: 14))
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
            Button("Reintentar") { vm.load(activityId: activityId) }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.fnPrimary)
            Spacer()
        }
    }

    private func formattedDate(_ s: String) -> String {
        let isoFrac: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
        let isoBasic: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }()
        let mysql: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f }()
        let out: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "es_AR"); f.dateStyle = .medium; f.timeStyle = .none; return f }()
        if let d = isoFrac.date(from: s) ?? isoBasic.date(from: s) ?? mysql.date(from: s) {
            return out.string(from: d)
        }
        return s
    }
}
