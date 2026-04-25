import SwiftUI

// MARK: - InAppMessage model

struct InAppMessage: Identifiable, Decodable {
    let id: Int
    let title: String
    let body: String
    let kind: String?        // "enrollment", "payment", "promo", "system"
    let read: Bool
    let deepLink: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, body, kind, read
        case deepLink  = "deep_link"
        case createdAt = "created_at"
    }
}

// MARK: - MessagesViewModel

@Observable
final class MessagesViewModel {
    var messages: [InAppMessage] = []
    var isLoading = false
    var error: String?
    var unreadCount: Int { messages.filter { !$0.read }.count }

    func load() async {
        isLoading = true
        error = nil
        do {
            let resp: ListResponse<InAppMessage> = try await APIClient.shared.request(
                "users/me/messages", authorized: true
            )
            messages = resp.items
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func markRead(id: Int) async {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        // Optimistic update
        let old = messages[idx]
        messages[idx] = InAppMessage(id: old.id, title: old.title, body: old.body,
                                     kind: old.kind, read: true,
                                     deepLink: old.deepLink, createdAt: old.createdAt)
        let _: SimpleOK? = try? await APIClient.shared.request(
            "users/me/messages/\(id)/read", method: "PUT", authorized: true
        )
    }

    func markAllRead() async {
        messages = messages.map {
            InAppMessage(id: $0.id, title: $0.title, body: $0.body,
                         kind: $0.kind, read: true,
                         deepLink: $0.deepLink, createdAt: $0.createdAt)
        }
        let _: SimpleOK? = try? await APIClient.shared.request(
            "users/me/messages/read-all", method: "PUT", authorized: true
        )
    }
}

// MARK: - MessagesView

struct MessagesView: View {
    @State private var vm = MessagesViewModel()

    var body: some View {
        ZStack {
            Color.fnBg.ignoresSafeArea()

            Group {
                if vm.isLoading && vm.messages.isEmpty {
                    loadingView
                } else if vm.messages.isEmpty {
                    emptyView
                } else {
                    messageList
                }
            }
        }
        .navigationTitle("Mensajes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fnBg, for: .navigationBar)
        .toolbar {
            if vm.unreadCount > 0 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Marcar todo leído") {
                        Task { await vm.markAllRead() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.fnBlue)
                }
            }
        }
        .task { await vm.load() }
    }

    // MARK: - List

    private var messageList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(vm.messages) { msg in
                    messageRow(msg)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func messageRow(_ msg: InAppMessage) -> some View {
        Button {
            Task { await vm.markRead(id: msg.id) }
            if let link = msg.deepLink, let url = URL(string: link) {
                DeepLinkHandler.shared.handle(url: url)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Kind icon
                ZStack {
                    Circle()
                        .fill(kindColor(msg.kind).opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: kindIcon(msg.kind))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(kindColor(msg.kind))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(msg.title)
                            .font(.system(size: 14, weight: msg.read ? .medium : .bold))
                            .foregroundColor(.fnWhite)
                            .lineLimit(1)
                        Spacer()
                        if let date = msg.createdAt {
                            Text(relativeDate(date))
                                .font(.system(size: 11))
                                .foregroundColor(.fnAsh)
                        }
                    }
                    Text(msg.body)
                        .font(.system(size: 13))
                        .foregroundColor(.fnSlate)
                        .lineLimit(2)
                }

                if !msg.read {
                    Circle()
                        .fill(Color.fnBlue)
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(msg.read ? Color.fnSurface : Color.fnBlue.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(msg.read ? Color.fnBorder : Color.fnBlue.opacity(0.2), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonView(cornerRadius: 14).frame(height: 72)
            }
        }
        .padding(.horizontal, 16).padding(.top, 12)
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.fnAsh)
            Text("Sin mensajes")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.fnWhite)
            Text("Acá vas a ver tus notificaciones, confirmaciones de pago y novedades.")
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func kindIcon(_ kind: String?) -> String {
        switch kind {
        case "enrollment": return "ticket.fill"
        case "payment":    return "creditcard.fill"
        case "promo":      return "tag.fill"
        default:           return "bell.fill"
        }
    }

    private func kindColor(_ kind: String?) -> Color {
        switch kind {
        case "enrollment": return .fnBlue
        case "payment":    return .fnGreen
        case "promo":      return .fnAmber
        default:           return .fnSlate
        }
    }

    private func relativeDate(_ iso: String) -> String {
        let fracF  = ISO8601DateFormatter()
        fracF.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let basicF = ISO8601DateFormatter()
        basicF.formatOptions = [.withInternetDateTime]
        guard let date = fracF.date(from: iso) ?? basicF.date(from: iso) else { return "" }
        let diff = Date().timeIntervalSince(date)
        switch diff {
        case ..<60:        return "Ahora"
        case ..<3600:      return "\(Int(diff / 60))m"
        case ..<86400:     return "\(Int(diff / 3600))h"
        default:           return "\(Int(diff / 86400))d"
        }
    }
}
