import SwiftUI
import Combine

fileprivate let typicalClubSports = ["Fútbol", "Tenis", "Natación", "Básquet", "Hockey"]
fileprivate struct Sport: Identifiable, Decodable { let id: Int; let name: String }
fileprivate struct SportsResponse: Decodable { let items: [Sport] }
fileprivate func uniquePrefix(_ arr: [String], max: Int) -> [String] {
    var seen = Set<String>(); var out: [String] = []
    for s in arr where !s.trimmingCharacters(in: .whitespaces).isEmpty {
        if !seen.contains(s) { seen.insert(s); out.append(s); if out.count == max { break } }
    }
    return out
}

fileprivate struct ClubItem: Identifiable {
    let id: String
    let sportName: String
    let title: String
    let location: String?
    let activityId: Int?
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ClubSportsView
// ─────────────────────────────────────────────────────────────────────────────

struct ClubSportsView: View {
    @Environment(\.dismiss) private var dismiss
    let providerId: Int
    let clubTitle: String

    @State private var sportsFetched: [String] = []
    @State private var allSports: [String] = []
    @State private var activities: [Activity] = []
    @State private var myItems: [EnrollmentItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var bag = Set<AnyCancellable>()
    @State private var appeared = false

    private var clubItems: [ClubItem] {
        let sports = allSports.isEmpty ? typicalClubSports : allSports
        return sports.map { sport in
            if let a = activities.first(where: { ($0.sport_name ?? "").localizedCaseInsensitiveContains(sport) }) {
                return ClubItem(id: "a-\(a.id)", sportName: sport, title: a.title,
                                location: a.location, activityId: a.id)
            }
            return ClubItem(id: "p-\(sport)", sportName: sport, title: sport,
                            location: nil, activityId: nil)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if let e = error { errorCard(e) }

                // Sports overview chips
                if !allSports.isEmpty {
                    sportsChipsSection
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.05), value: appeared)
                }

                // Activity cards
                activitiesSection
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5).delay(0.10), value: appeared)
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Color.fnBg)
        .navigationTitle(clubTitle)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Label("Actividades", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .onAppear {
            reloadAll()
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
    }

    // MARK: Error Card

    private func errorCard(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.fnSecondary)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.fnSecondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.fnSecondary.opacity(0.10)))
    }

    // MARK: Sports Chips

    private var sportsChipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Deportes disponibles")

            FlowLayout(spacing: 8) {
                ForEach(allSports, id: \.self) { name in
                    HStack(spacing: 6) {
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.fnGreen)
                        Text(name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.fnSurface)
                            .overlay(Capsule().stroke(Color.fnGreen.opacity(0.2), lineWidth: 1))
                    )
                }
            }
        }
    }

    // MARK: Activities Section

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Inscribirme a un deporte")

            if loading {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in SkeletonView(cornerRadius: 18).frame(height: 90) }
                }
            } else {
                ForEach(clubItems) { item in
                    clubItemCard(item)
                }
            }
        }
    }

    private func clubItemCard(_ item: ClubItem) -> some View {
        let enrolled = item.activityId != nil && isEnrolled(item.activityId!)
        let info = ActivityTypeInfo.from(kind: "club_sport")

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(enrolled ? FNGradient.success : FNGradient.sport)
                    .frame(width: 50, height: 50)
                Image(systemName: enrolled ? "checkmark.circle.fill" : "sportscourt.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            .fnShadowColored(.fnGreen, radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(item.sportName)
                    .font(.system(size: 12))
                    .foregroundColor(.fnSlate)
                if let loc = item.location, !loc.isEmpty {
                    Label(loc, systemImage: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.fnSlate.opacity(0.7))
                        .lineLimit(1)
                }
                if item.activityId == nil {
                    Text("Próximamente")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.fnYellow)
                }
            }

            Spacer()

            Group {
                if let aid = item.activityId {
                    if enrolled {
                        FitNowOutlineButton(title: "Cancelar", color: .fnSecondary, height: 38) {
                            cancel(activityId: aid)
                        }
                        .frame(width: 96)
                    } else {
                        FitNowButton(title: "Unirme", gradient: FNGradient.sport, height: 38) {
                            enroll(activityId: aid)
                        }
                        .frame(width: 88)
                    }
                } else {
                    Text("Próximamente")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.fnYellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.fnYellow.opacity(0.12)))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.fnSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(enrolled ? Color.fnGreen.opacity(0.2) : Color.fnBorder.opacity(0.4), lineWidth: 0.5)
                )
        )
        .fnShadow()
    }

    // MARK: - Data

    private func reloadAll() {
        loading = true; error = nil

        APIClient.shared.requestPublisher("providers/\(providerId)/sports", authorized: false)
            .sink { completion in
                if case .failure = completion, self.allSports.isEmpty { self.allSports = typicalClubSports }
            } receiveValue: { (resp: SportsResponse) in
                let names = resp.items.map { $0.name }
                self.sportsFetched = names
                self.allSports = uniquePrefix(names + typicalClubSports, max: 5)
            }
            .store(in: &bag)

        let q: [URLQueryItem] = [
            .init(name: "provider_id", value: String(providerId)),
            .init(name: "kind", value: "club_sport"),
            .init(name: "include_sports", value: "1")
        ]
        APIClient.shared.requestPublisher("activities", authorized: false, query: q)
            .sink { completion in
                if case .failure(let e) = completion { self.error = e.localizedDescription }
            } receiveValue: { (resp: Paged<Activity>) in
                var seen = Set<String>()
                self.activities = resp.items.filter { a in
                    let key = (a.sport_name ?? a.title).lowercased()
                    if seen.contains(key) { return false }
                    seen.insert(key); return true
                }
            }
            .store(in: &bag)

        APIClient.shared.requestPublisher("enrollments/mine", authorized: true,
                                 query: [URLQueryItem(name: "when", value: "all")])
            .sink { _ in } receiveValue: { (resp: ListResponse<EnrollmentItem>) in
                self.myItems = resp.items; self.loading = false
            }
            .store(in: &bag)
    }

    private func isEnrolled(_ activityId: Int) -> Bool {
        myItems.contains { $0.activity_id == activityId && $0.session_id == nil }
    }

    private func enroll(activityId: Int) {
        APIClient.shared.requestPublisher("enrollments", method: "POST",
                                 body: try? JSONEncoder().encode(["activity_id": activityId]),
                                 authorized: true)
            .sink { completion in
                if case .failure(let e) = completion { self.error = e.localizedDescription }
            } receiveValue: { (_: SimpleOK) in reloadAll() }
            .store(in: &bag)
    }

    private func cancel(activityId: Int) {
        guard let eid = myItems.first(where: { $0.activity_id == activityId && $0.session_id == nil })?.id else { return }
        APIClient.shared.requestPublisher("enrollments/\(eid)", method: "DELETE", authorized: true)
            .sink { completion in
                if case .failure(let e) = completion { self.error = e.localizedDescription }
            } receiveValue: { (_: SimpleOK) in reloadAll() }
            .store(in: &bag)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Flow Layout (wrapping chips)
// ─────────────────────────────────────────────────────────────────────────────

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { y += rowHeight + spacing; x = 0; rowHeight = 0 }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX; var y = bounds.minY; var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { y += rowHeight + spacing; x = bounds.minX; rowHeight = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
