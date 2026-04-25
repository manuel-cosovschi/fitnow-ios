import SwiftUI

// MARK: - CheckIn models

struct CheckInResult: Decodable {
    let enrollmentId: Int
    let athleteName: String
    let activityTitle: String
    let planName: String?
    let checkedInAt: String?

    enum CodingKeys: String, CodingKey {
        case enrollmentId  = "enrollment_id"
        case athleteName   = "athlete_name"
        case activityTitle = "activity_title"
        case planName      = "plan_name"
        case checkedInAt   = "checked_in_at"
    }
}

struct ProviderEnrollment: Identifiable, Decodable {
    let id: Int
    let athleteName: String
    let activityTitle: String
    let planName: String?
    let status: String?
    let checkedIn: Bool
    let dateStart: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case athleteName   = "athlete_name"
        case activityTitle = "activity_title"
        case planName      = "plan_name"
        case checkedIn     = "checked_in"
        case dateStart     = "date_start"
    }
}

// MARK: - CheckInService

@Observable
final class CheckInService {
    static let shared = CheckInService()
    private init() {}

    var isProcessing = false
    var lastResult: CheckInResult?
    var lastError: String?

    func checkIn(enrollmentId: Int) async throws -> CheckInResult {
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }
        let result: CheckInResult = try await APIClient.shared.request(
            "enrollments/\(enrollmentId)/checkin", method: "POST", authorized: true
        )
        lastResult = result
        return result
    }

    func parseQR(_ value: String) -> Int? {
        // Accepts: fitnow://checkin/123  OR just "123"
        if let url = URL(string: value),
           url.scheme == "fitnow",
           url.host == "checkin",
           let idStr = url.pathComponents.last,
           let id = Int(idStr) { return id }
        return Int(value)
    }
}

// MARK: - ProviderEnrollmentsTab

struct ProviderEnrollmentsTab: View {
    let providerId: Int?
    @State private var enrollments: [ProviderEnrollment] = []
    @State private var isLoading = false
    @State private var showScanner = false
    @State private var scanResult: CheckInResult? = nil
    @State private var scanError: String? = nil
    @State private var activityFilter = ""

    var body: some View {
        ZStack {
            Color.fnBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Filter bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.fnSlate)
                        .font(.system(size: 14))
                    TextField("Buscar atleta o actividad…", text: $activityFilter)
                        .font(.system(size: 14))
                        .foregroundColor(.fnWhite)
                }
                .padding(12)
                .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fnBorder, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Rectangle().fill(Color.fnBorder.opacity(0.5)).frame(height: 0.5)

                if isLoading && enrollments.isEmpty {
                    loadingView
                } else if filtered.isEmpty {
                    emptyView
                } else {
                    enrollmentList
                }
            }
        }
        .navigationTitle("Inscripciones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fnBg, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    scanError = nil; scanResult = nil; showScanner = true
                } label: {
                    Label("Escanear", systemImage: "qrcode.viewfinder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.fnPurple)
                }
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            scannerSheet
        }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Scanner sheet

    private var scannerSheet: some View {
        ZStack(alignment: .bottom) {
            QRScannerView { value in
                showScanner = false
                Task { await handleScan(value) }
            } onCancel: {
                showScanner = false
            }

            if let result = scanResult {
                checkInResultBanner(result, success: true)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let err = scanError {
                checkInResultBanner(nil, success: false, error: err)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
    }

    private func checkInResultBanner(_ result: CheckInResult?, success: Bool, error: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(success ? .fnGreen : .fnCrimson)
            VStack(alignment: .leading, spacing: 3) {
                if let r = result {
                    Text(r.athleteName)
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.fnWhite)
                    Text(r.activityTitle)
                        .font(.system(size: 13)).foregroundColor(.fnSlate)
                } else {
                    Text(error ?? "Error").font(.system(size: 14)).foregroundColor(.fnCrimson)
                }
            }
            Spacer()
            if success { Text("CHECK-IN ✓")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.fnGreen)
            }
        }
        .padding(16)
        .background(Color.fnElevated, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(success ? Color.fnGreen.opacity(0.3) : Color.fnCrimson.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }

    // MARK: - List

    private var filtered: [ProviderEnrollment] {
        guard !activityFilter.isEmpty else { return enrollments }
        let q = activityFilter.lowercased()
        return enrollments.filter {
            $0.athleteName.lowercased().contains(q) ||
            $0.activityTitle.lowercased().contains(q)
        }
    }

    private var enrollmentList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(filtered) { e in
                    enrollmentRow(e)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func enrollmentRow(_ e: ProviderEnrollment) -> some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(e.checkedIn ? Color.fnGreen : Color.fnSlate.opacity(0.4))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(e.athleteName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.fnWhite)
                HStack(spacing: 6) {
                    Text(e.activityTitle)
                        .font(.system(size: 12))
                        .foregroundColor(.fnSlate)
                    if let plan = e.planName {
                        Text("· \(plan)")
                            .font(.system(size: 12))
                            .foregroundColor(.fnAsh)
                    }
                }
            }

            Spacer()

            if e.checkedIn {
                Text("Presente")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.fnGreen)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.fnGreen.opacity(0.12), in: Capsule())
            } else {
                Button {
                    Task {
                        if let result = try? await CheckInService.shared.checkIn(enrollmentId: e.id) {
                            withAnimation { scanResult = result }
                            await load()
                        }
                    }
                } label: {
                    Text("Check-in")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.fnPurple)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.fnPurple.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(Color.fnPurple.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.fnSurface, in: RoundedRectangle(cornerRadius: 13))
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { _ in
                SkeletonView(cornerRadius: 13).frame(height: 60)
            }
        }
        .padding(.horizontal, 16).padding(.top, 12)
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.2.slash").font(.system(size: 48)).foregroundColor(.fnAsh)
            Text("Sin inscripciones").font(.system(size: 18, weight: .bold)).foregroundColor(.fnWhite)
            Text("Cuando tus atletas se inscriban aparecerán acá.")
                .font(.system(size: 14)).foregroundColor(.fnSlate).multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - API

    private func load() async {
        isLoading = true
        let resp: ListResponse<ProviderEnrollment>? = try? await APIClient.shared.request(
            "enrollments/provider", authorized: true
        )
        enrollments = resp?.items ?? []
        isLoading = false
    }

    private func handleScan(_ value: String) async {
        guard let enrollmentId = CheckInService.shared.parseQR(value) else {
            withAnimation { scanError = "QR no reconocido: \(value)" }
            return
        }
        do {
            let result = try await CheckInService.shared.checkIn(enrollmentId: enrollmentId)
            withAnimation { scanResult = result }
            await load()
        } catch {
            withAnimation { scanError = "Check-in fallido. Verificá el código." }
        }
    }
}
