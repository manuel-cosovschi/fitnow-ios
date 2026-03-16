import SwiftUI

struct ActivitiesListView: View {
    @StateObject private var vm = ActivitiesViewModel()
    @EnvironmentObject var auth: AuthViewModel
    @State private var showingFilters = false
    @State private var appeared = false

    // Quick filter chips
    private let kindFilters: [(label: String, value: String, color: Color)] = [
        ("Todos",          "",            .fnPrimary),
        ("Entrenadores",   "trainer",     .fnPrimary),
        ("Gimnasios",      "gym",         .fnCyan),
        ("Clubes",         "club",        .fnPurple),
        ("Deportes",       "club_sport",  .fnGreen),
    ]
    @State private var selectedKind = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search + filter bar
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Kind filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(kindFilters, id: \.value) { f in
                        FilterChip(
                            title: f.label,
                            isSelected: selectedKind == f.value
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedKind = f.value
                            }
                            vm.fetch()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .padding(.bottom, 8)

            Divider()
                .opacity(0.5)

            // List content
            Group {
                if vm.loading && vm.items.isEmpty {
                    loadingState
                } else if let error = vm.error {
                    errorState(error)
                } else if vm.items.isEmpty {
                    emptyState
                } else {
                    activityList
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Actividades")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingFilters = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .medium))
                        Text("Filtros")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.fnPrimary)
                }
            }
        }
        .onAppear {
            vm.fetch()
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
        .sheet(isPresented: $showingFilters) {
            FiltersSheet(vm: vm, isPresented: $showingFilters)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(.tertiaryLabel))
            TextField("Buscar actividades, entrenadores…", text: $vm.query)
                .font(.system(size: 15))
                .onSubmit { vm.fetch() }
                .submitLabel(.search)
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                    vm.fetch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Activity List

    private var activityList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                if vm.loading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.85)
                        Text("Actualizando…")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.secondaryLabel))
                    }
                    .padding(.top, 4)
                }

                ForEach(Array(vm.items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink {
                        ActivityDetailLoader(activityId: item.id, title: item.title)
                    } label: {
                        ActivityListCard(activity: item)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.8)
                            .delay(Double(index) * 0.04),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonView(cornerRadius: 20)
                        .frame(height: 100)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Error State

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(Color(.tertiaryLabel))
            Text("No se pudo cargar")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(.label))
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            FitNowButton(title: "Reintentar", icon: "arrow.clockwise") {
                vm.fetch()
            }
            .padding(.horizontal, 60)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundStyle(FNGradient.primary)
            Text("Sin resultados")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))
            Text("Probá buscar con otros términos\no ajustá los filtros.")
                .font(.system(size: 15))
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
            FitNowOutlineButton(title: "Limpiar filtros", icon: "xmark.circle") {
                vm.clearFilters()
                selectedKind = ""
                vm.fetch()
            }
            .padding(.horizontal, 80)
            Spacer()
        }
    }
}

// MARK: - Filters Sheet

struct FiltersSheet: View {
    @ObservedObject var vm: ActivitiesViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Dificultad", selection: $vm.selectedDifficulty) {
                        Text("Cualquiera").tag("")
                        ForEach(vm.difficultyOptions.filter { !$0.isEmpty }, id: \.self) { opt in
                            Text(opt.capitalized).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Label("Dificultad", systemImage: "chart.bar.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.fnPrimary)
                }

                Section {
                    Picker("Modalidad", selection: $vm.selectedModality) {
                        Text("Cualquiera").tag("")
                        ForEach(vm.modalityOptions.filter { !$0.isEmpty }, id: \.self) { opt in
                            Text(opt.capitalized).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Label("Modalidad", systemImage: "figure.mixed.cardio")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.fnCyan)
                }

                Section {
                    HStack {
                        Text("Mínimo")
                        Spacer()
                        Stepper(
                            value: Binding(
                                get: { vm.minPrice ?? 0 },
                                set: { vm.minPrice = $0 == 0 ? nil : $0 }
                            ),
                            in: 0...50000,
                            step: 500
                        ) {
                            Text(vm.minPrice == nil ? "—" : "$\(vm.minPrice!)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.fnPrimary)
                        }
                    }
                    HStack {
                        Text("Máximo")
                        Spacer()
                        Stepper(
                            value: Binding(
                                get: { vm.maxPrice ?? 0 },
                                set: { vm.maxPrice = $0 == 0 ? nil : $0 }
                            ),
                            in: 0...50000,
                            step: 500
                        ) {
                            Text(vm.maxPrice == nil ? "—" : "$\(vm.maxPrice!)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.fnPrimary)
                        }
                    }
                } header: {
                    Label("Precio", systemImage: "creditcard.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.fnGreen)
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Limpiar") {
                        vm.clearFilters()
                    }
                    .foregroundColor(.fnSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        isPresented = false
                        vm.fetch()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.fnPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
