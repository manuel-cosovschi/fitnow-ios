import SwiftUI
import Combine
import Foundation

// --------- FORMATTERS ---------
fileprivate let isoFrac: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
fileprivate let isoBasic: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()
fileprivate let mysqlDF: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()
fileprivate let outDF: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "es_AR")
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
}()
fileprivate func prettyDate(_ s: String?) -> String {
    guard let s = s else { return "—" }
    if let d = isoFrac.date(from: s) ?? isoBasic.date(from: s) ?? mysqlDF.date(from: s) {
        return outDF.string(from: d)
    }
    return s
}

// --------- VIEWMODEL ---------
final class MyEnrollmentsViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case upcoming = "Próximas"
        case past = "Pasadas"
        case all = "Todas"
        var id: String { rawValue }
        var queryValue: String {
            switch self {
            case .upcoming: return "upcoming"
            case .past:     return "past"
            case .all:      return "all"
            }
        }
    }

    @Published var items: [EnrollmentItem] = []
    @Published var loading = false
    @Published var error: String?
    @Published var filter: Filter = .upcoming

    private var bag = Set<AnyCancellable>()

    func fetchMine() {
        loading = true; error = nil
        let q = [URLQueryItem(name: "when", value: filter.queryValue)]
        APIClient.shared.request("enrollments/mine", authorized: true, query: q)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: ListResponse<EnrollmentItem>) in
                self?.items = resp.items
            }
            .store(in: &bag)
    }

    func cancel(_ item: EnrollmentItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        loading = true; error = nil
        APIClient.shared.request("enrollments/\(item.id)", method: "DELETE", authorized: true)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (_: SimpleOK) in
                self?.items.remove(at: idx)
            }
            .store(in: &bag)
    }
}

// --------- VISTA ---------
struct MyEnrollmentsView: View {
    @StateObject private var vm = MyEnrollmentsViewModel()

    var body: some View {
        VStack {
            Picker("Filtro", selection: $vm.filter) {
                ForEach(MyEnrollmentsViewModel.Filter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            List {
                if vm.loading { Section { ProgressView("Cargando...") } }
                if let e = vm.error { Section { Text(e).foregroundColor(.red) } }

                ForEach(vm.items) { item in
                    NavigationLink(destination: destination(for: item)) {
                        itemRow(item)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            vm.cancel(item)
                        } label: {
                            Label("Cancelar", systemImage: "trash")
                        }
                    }
                }

                if !vm.loading && vm.items.isEmpty {
                    Text("No hay inscripciones \(vm.filter == .past ? "pasadas" : vm.filter == .all ? "" : "próximas").")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Mis inscripciones")
        .onAppear { vm.fetchMine() }
        .onChange(of: vm.filter) {
            vm.fetchMine()
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
        } else if kind == "gym", let aid = item.activity_id {
            ActivityDetailLoader(activityId: aid, title: item.title)
        } else if let aid = item.activity_id {
            ActivityDetailLoader(activityId: aid, title: item.title)
        } else {
            Text(item.title)
        }
    }

    private func itemRow(_ item: EnrollmentItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title).bold()
                Spacer()
                Text(price(item.price))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            if let loc = item.location, !loc.isEmpty {
                Text(loc).font(.caption).foregroundColor(.secondary)
            }
            Text(prettyDate(item.date_start))
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func price(_ p: Double?) -> String {
        guard let p = p else { return "—" }
        return String(format: "$%.0f", p)
    }
}










