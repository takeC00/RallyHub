import Foundation
import Observation

@MainActor
@Observable
final class CircleListViewModel {
    var memberships: [CircleMembership] = []
    var isLoading = false
    var errorMessage: String?

    func load() async {
        guard let uid = AuthService.shared.uid else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            memberships = try await CircleRepository.shared.fetchMemberships(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        do {
            try AuthService.shared.logout()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
