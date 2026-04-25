import Foundation
import Combine

final class EnrollmentsViewModel: ObservableObject {
    @Published var items: [EnrollmentItem] = []
    @Published var loading = false
    @Published var error: String?

    private var bag = Set<AnyCancellable>()

    func fetchMine() {
        loading = true; error = nil
        APIClient.shared.requestPublisher("enrollments/mine", authorized: true)
            .sink { [weak self] completion in
                self?.loading = false
                if case .failure(let e) = completion { self?.error = e.localizedDescription }
            } receiveValue: { [weak self] (resp: ListResponse<EnrollmentItem>) in
                self?.items = resp.items
            }
            .store(in: &bag)
    }
}


