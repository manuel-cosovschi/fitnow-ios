import SwiftUI

struct ActivitiesListView: View {
    @StateObject private var vm = ActivitiesViewModel()
    @EnvironmentObject var auth: AuthViewModel

    @State private var showingFilters = false

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Buscar...", text: $vm.query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { vm.fetch() }
                    Button("Buscar") { vm.fetch() }
                }
                .padding([.horizontal, .top])

                if vm.loading { ProgressView("Cargando...") }
                if let e = vm.error { Text(e).foregroundColor(.red) }

                List(vm.items) { item in
                    NavigationLink {
                        // SIEMPRE pasamos por el Loader, que decide y además
                        // inyecta el previousTitle para que aparezca la flecha “Actividades”.
                        ActivityDetailLoader(activityId: item.id, title: item.title)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.title).bold()
                            Text(item.location ?? "—")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Actividades")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink("Mis inscripciones") { MyEnrollmentsView() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Filtros") { showingFilters = true }
                        Button("Salir") { auth.logout() }
                    }
                }
            }
            .onAppear { vm.fetch() }
            .sheet(isPresented: $showingFilters) {
                FiltersSheet(vm: vm, isPresented: $showingFilters)
            }
        }
    }
}

// MARK: - Hoja de Filtros (igual que tenías)
struct FiltersSheet: View {
    @ObservedObject var vm: ActivitiesViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dificultad")) {
                    Picker("Dificultad", selection: $vm.selectedDifficulty) {
                        Text("Cualquiera").tag("")
                        ForEach(vm.difficultyOptions.filter { !$0.isEmpty }, id: \.self) { opt in
                            Text(opt.capitalized).tag(opt)
                        }
                    }
                }
                Section(header: Text("Modalidad")) {
                    Picker("Modalidad", selection: $vm.selectedModality) {
                        Text("Cualquiera").tag("")
                        ForEach(vm.modalityOptions.filter { !$0.isEmpty }, id: \.self) { opt in
                            Text(opt.capitalized).tag(opt)
                        }
                    }
                }
                Section(header: Text("Precio")) {
                    HStack {
                        Text("Mín.")
                        Spacer()
                        Stepper(
                            value: Binding(
                                get: { vm.minPrice ?? 0 },
                                set: { vm.minPrice = ($0 == 0 ? nil : $0) }
                            ),
                            in: 0...50000,
                            step: 500
                        ) { Text(vm.minPrice == nil ? "—" : "$\(vm.minPrice!)") }
                    }
                    HStack {
                        Text("Máx.")
                        Spacer()
                        Stepper(
                            value: Binding(
                                get: { vm.maxPrice ?? 0 },
                                set: { vm.maxPrice = ($0 == 0 ? nil : $0) }
                            ),
                            in: 0...50000,
                            step: 500
                        ) { Text(vm.maxPrice == nil ? "—" : "$\(vm.maxPrice!)") }
                    }
                }
            }
            .navigationTitle("Filtros")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Limpiar") { vm.clearFilters() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        isPresented = false
                        vm.fetch()
                    }
                }
            }
        }
    }
}






