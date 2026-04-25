import SwiftUI
import Combine
import Foundation

// ─── Formatters ──────────────────────────────────────────────────────────────

fileprivate let isoFrac: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
}()
fileprivate let isoBasic: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
}()
fileprivate let mysqlDF: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f
}()
fileprivate let outDF: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "es_AR")
    f.dateStyle = .medium; f.timeStyle = .short; return f
}()
fileprivate func prettyDate(_ s: String?) -> String {
    guard let s = s else { return "—" }
    if let d = isoFrac.date(from: s) ?? isoBasic.date(from: s) ?? mysqlDF.date(from: s) { return outDF.string(from: d) }
    return s
}

// ─── ViewModel ───────────────────────────────────────────────────────────────

final class MyEnrollmentsViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case upcoming = "Próximas"
        case past     = "Pasadas"
        case all      = "Todas"
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
        APIClient.shared.requestPublisher("enrollments/mine", authorized: true, query: q)
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
        APIClient.shared.requestPublisher("enrollments/\(item.id)", method: "DELETE", authorized: true)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (_: SimpleOK) in
                self?.items.remove(at: idx)
            }
            .store(in: &bag)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MyEnrollmentsView
// ─────────────────────────────────────────────────────────────────────────────

struct MyEnrollmentsView: View {
    @StateObject private var vm = MyEnrollmentsViewModel()
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Filter tabs
            filterBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Divider().opacity(0.5)

            // Content
            Group {
                if vm.loading && vm.items.isEmpty {
                    loadingView
                } else if let error = vm.error {
                    errorView(error)
                } else if vm.items.isEmpty {
                    emptyView
                } else {
                    itemsList
                }
            }
        }
        .background(Color.fnBg)
        .navigationTitle("Mis inscripciones")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            vm.fetchMine()
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
        .onChange(of: vm.filter) { vm.fetchMine() }
    }

    // MARK: Filter Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(MyEnrollmentsViewModel.Filter.allCases) { f in
                FilterChip(
                    title: f.rawValue,
                    isSelected: vm.filter == f
                ) {
                    withAnimation(.spring(response: 0.3)) { vm.filter = f }
                }
            }
            Spacer()
            if vm.loading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    // MARK: Items List

    private var itemsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(Array(vm.items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(destination: destination(for: item)) {
                        EnrollmentRowCard(item: item, onCancel: nil)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            vm.cancel(item)
                        } label: {
                            Label("Cancelar inscripción", systemImage: "trash")
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.8)
                            .delay(Double(index) * 0.05),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: States

    private var loadingView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonView(cornerRadius: 18).frame(height: 86)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 52))
                .foregroundColor(.fnSlate.opacity(0.7))
            Text("Error al cargar")
                .font(.system(size: 18, weight: .bold))
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            FitNowButton(title: "Reintentar", icon: "arrow.clockwise") { vm.fetchMine() }
                .padding(.horizontal, 60)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(FNGradient.primary)
                    .frame(width: 80, height: 80)
                    .fnShadowBrand()
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(emptyTitle)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(emptySubtitle)
                .font(.system(size: 15))
                .foregroundColor(.fnSlate)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
            Spacer()
        }
    }

    private var emptyTitle: String {
        switch vm.filter {
        case .upcoming: return "Sin actividades próximas"
        case .past:     return "Sin actividades pasadas"
        case .all:      return "Sin inscripciones"
        }
    }

    private var emptySubtitle: String {
        switch vm.filter {
        case .upcoming: return "Explorá actividades y encontrá tu próximo entrenamiento."
        case .past:     return "Tus actividades completadas aparecerán acá."
        case .all:      return "Aún no te inscribiste a ninguna actividad."
        }
    }

    // MARK: Router
    // All enrollments go to EnrollmentDetailView which shows enrollment-specific info
    // and provides contextual links (TrainerBookingsView, ClubSportsView, etc.)

    @ViewBuilder
    private func destination(for item: EnrollmentItem) -> some View {
        EnrollmentDetailView(enrollment: item)
    }
}
