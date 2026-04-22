import SwiftUI

struct ActivitiesListView: View {
    @StateObject private var vm = ActivitiesViewModel()
    @EnvironmentObject var auth: AuthViewModel
    @State private var showingFilters = false
    @State private var appeared = false

    private let kindFilters: [(label: String, value: String)] = [
        ("Todos",        ""),
        ("Entrenadores", "trainer"),
        ("Gimnasios",    "gym"),
        ("Clubes",       "club"),
        ("Deportes",     "club_sport"),
    ]

    var body: some View {
        ZStack {
            Color.fnBg.ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(kindFilters, id: \.value) { f in
                            FilterChip(title: f.label,
                                       isSelected: vm.selectedKind == f.value) {
                                withAnimation(.spring(response: 0.3)) {
                                    vm.selectedKind = f.value
                                }
                                vm.fetch()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .padding(.bottom, 8)

                Rectangle()
                    .fill(Color.fnBorder.opacity(0.5))
                    .frame(height: 0.5)

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
        }
        .navigationTitle("Explorar")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.fnBg, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingFilters = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .medium))
                        Text("Filtros")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.fnBlue)
                }
            }
        }
        .onAppear {
            vm.fetch()
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
        .sheet(isPresented: $showingFilters) {
            FiltersSheet(vm: vm, isPresented: $showingFilters)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.fnBlue)
            TextField("Buscar actividades, entrenadores…", text: $vm.query)
                .font(.system(size: 15))
                .foregroundColor(.fnWhite)
                .tint(.fnBlue)
                .onSubmit { vm.fetch() }
                .submitLabel(.search)
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                    vm.fetch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.fnAsh)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.fnElevated)
                .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.fnBorder, lineWidth: 1))
        )
    }

    // MARK: - List

    private var activityList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                if vm.loading {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.85).tint(.fnBlue)
                        Text("Actualizando…")
                            .font(.system(size: 13))
                            .foregroundColor(.fnSlate)
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
            .padding(.vertical, 14)
        }
    }

    // MARK: - States

    private var loadingState: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonView(cornerRadius: 20).frame(height: 100)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.fnAsh)
            Text("No se pudo cargar")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.fnWhite)
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            FitNowButton(title: "Reintentar", icon: "arrow.clockwise") {
                vm.fetch()
            }
            .padding(.horizontal, 60)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Color.fnBlue.opacity(0.18)).frame(width: 92, height: 92)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.fnBlue)
            }
            Text("Sin resultados")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.fnWhite)
            Text("Probá buscar con otros términos\no ajustá los filtros.")
                .font(.system(size: 15))
                .foregroundColor(.fnSlate)
                .multilineTextAlignment(.center)
            FitNowOutlineButton(title: "Limpiar filtros", icon: "xmark.circle") {
                vm.clearFilters()
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
            ZStack {
                Color.fnBg.ignoresSafeArea()

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
                            .foregroundColor(.fnBlue)
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
                            .foregroundColor(.fnPurple)
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
                                in: 0...50000, step: 500
                            ) {
                                Text(vm.minPrice == nil ? "—" : "$\(vm.minPrice!)")
                                    .font(.custom(\"JetBrains Mono\", size: 14).weight(.semibold))
                                    .foregroundColor(.fnBlue)
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
                                in: 0...50000, step: 500
                            ) {
                                Text(vm.maxPrice == nil ? "—" : "$\(vm.maxPrice!)")
                                    .font(.custom(\"JetBrains Mono\", size: 14).weight(.semibold))
                                    .foregroundColor(.fnBlue)
                            }
                        }
                    } header: {
                        Label("Precio", systemImage: "creditcard.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.fnGreen)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.fnBg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Limpiar") { vm.clearFilters() }
                        .foregroundColor(.fnCrimson)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        isPresented = false
                        vm.fetch()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.fnBlue)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
