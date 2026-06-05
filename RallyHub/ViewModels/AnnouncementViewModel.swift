import Foundation
import Observation

@MainActor
@Observable
final class AnnouncementViewModel {
    let membership: CircleMembership

    var announcements: [Announcement] = []
    var isLoading = false
    var errorMessage: String?

    init(membership: CircleMembership) {
        self.membership = membership
    }

    var canPost: Bool {
        membership.membership.role.canPostAnnouncements
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            announcements = try await AnnouncementRepository.shared.fetchAnnouncements(
                circleId: membership.circle.circleId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
