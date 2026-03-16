import SwiftUI
import Combine

// ─── Date helpers ─────────────────────────────────────────────────────────────

private let isoFracCal: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
private let isoBasicCal: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()
private let mysqlCal: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()
private func calParseDate(_ s: String) -> Date? {
    isoFracCal.date(from: s) ?? isoBasicCal.date(from: s) ?? mysqlCal.date(from: s)
}
private let calTimeDF: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "es_AR")
    f.timeStyle = .short
    return f
}()

// ─── ViewModel ────────────────────────────────────────────────────────────────

final class CalendarViewModel: ObservableObject {
    @Published var items: [EnrollmentItem] = []
    @Published var loading = false
    @Published var error: String?

    private var bag = Set<AnyCancellable>()

    func fetch() {
        loading = true; error = nil
        let q = [URLQueryItem(name: "when", value: "upcoming")]
        APIClient.shared.request("enrollments/mine", authorized: true, query: q)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: ListResponse<EnrollmentItem>) in
                self?.items = resp.items
            }
            .store(in: &bag)
    }

    /// Returns items whose date_start falls on `day` (same calendar day)
    func items(on day: Date) -> [EnrollmentItem] {
        let cal = Calendar.current
        return items.filter { item in
            guard let ds = item.date_start, let d = calParseDate(ds) else { return false }
            return cal.isDate(d, inSameDayAs: day)
        }
    }

    /// Set of days that have at least one enrollment
    var activeDays: Set<String> {
        Set(items.compactMap { item -> String? in
            guard let ds = item.date_start, let d = calParseDate(ds) else { return nil }
            return Calendar.current.startOfDay(for: d).ISO8601Format()
        })
    }
}

// ─── View ─────────────────────────────────────────────────────────────────────

struct CalendarView: View {
    @StateObject private var vm = CalendarViewModel()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    // 21-day window starting today
    private let days: [Date] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<21).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }()

    var body: some View {
        VStack(spacing: 0) {
            weekStrip
            Divider().opacity(0.5)
            dayContent
        }
        .background(Color(.systemBackground))
        .navigationTitle("Calendario")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { vm.fetch() }
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { day in
                        DayCell(
                            day: day,
                            isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDay),
                            hasEvent: vm.activeDays.contains(Calendar.current.startOfDay(for: day).ISO8601Format())
                        ) {
                            withAnimation(.spring(response: 0.3)) { selectedDay = day }
                        }
                        .id(day)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onAppear {
                proxy.scrollTo(selectedDay, anchor: .center)
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Day Content

    @ViewBuilder
    private var dayContent: some View {
        let items = vm.items(on: selectedDay)
        if vm.loading && vm.items.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.error {
            VStack(spacing: 14) {
                Spacer()
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 44))
                    .foregroundColor(Color(.tertiaryLabel))
                Text("Error al cargar")
                    .font(.system(size: 16, weight: .bold))
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Reintentar") { vm.fetch() }
                    .buttonStyle(.borderedProminent)
                    .tint(.fnPrimary)
                Spacer()
            }
        } else if items.isEmpty {
            emptyDayView
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(items, id: \.id) { item in
                        NavigationLink(destination: destination(for: item)) {
                            CalendarEventRow(item: item)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var emptyDayView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(Color(.tertiaryLabel))
            let cal = Calendar.current
            if cal.isDateInToday(selectedDay) {
                Text("Nada para hoy")
                    .font(.system(size: 18, weight: .bold))
                Text("Explorá actividades y agendá tu próximo entreno.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("Día libre")
                    .font(.system(size: 18, weight: .bold))
                Text("No hay actividades agendadas para este día.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }

    // MARK: - Router

    @ViewBuilder
    private func destination(for item: EnrollmentItem) -> some View {
        let kind = item.activity_kind ?? ""
        if kind == "trainer", let aid = item.activity_id {
            TrainerBookingsView(activityId: aid, title: item.title)
        } else if kind == "club", let pid = item.provider_id {
            ClubSportsView(providerId: pid, clubTitle: item.title)
        } else if let aid = item.activity_id {
            ActivityDetailLoader(activityId: aid, title: item.title)
        } else {
            Text(item.title).padding()
        }
    }
}

// ─── Day Cell ─────────────────────────────────────────────────────────────────

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let hasEvent: Bool
    let onTap: () -> Void

    private static let dayNameDF: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_AR"); f.dateFormat = "EEE"; return f
    }()
    private static let dayNumDF: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(Self.dayNameDF.string(from: day).prefix(3).uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .white : Color(.secondaryLabel))
                Text(Self.dayNumDF.string(from: day))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : Color(.label))
                Circle()
                    .fill(hasEvent ? (isSelected ? Color.white.opacity(0.8) : Color.fnPrimary) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 44, height: 68)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AnyShapeStyle(FNGradient.primary) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// ─── Event Row ────────────────────────────────────────────────────────────────

private struct CalendarEventRow: View {
    let item: EnrollmentItem
    private var typeInfo: ActivityTypeInfo { ActivityTypeInfo.from(kind: item.activity_kind ?? "") }

    var body: some View {
        HStack(spacing: 14) {
            // Time column
            VStack(spacing: 2) {
                if let ds = item.date_start, let d = calParseDate(ds) {
                    Text(calTimeDF.string(from: d))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(typeInfo.color)
                }
                Rectangle()
                    .fill(typeInfo.color.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 44)

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(typeInfo.gradient)
                    .frame(width: 42, height: 42)
                Image(systemName: typeInfo.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .fnShadowColored(typeInfo.color, radius: 6, y: 2)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                if let loc = item.location, !loc.isEmpty {
                    Label(loc, systemImage: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                ActivityTypeBadge(kind: item.activity_kind ?? "")
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(typeInfo.color.opacity(0.15), lineWidth: 1)
                )
        )
        .fnShadow(radius: 8, y: 3)
    }
}
