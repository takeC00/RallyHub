import Foundation
import Observation

enum EventListFilter: String, CaseIterable, Identifiable {
    case upcoming
    case past

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upcoming: "開催予定"
        case .past: "過去"
        }
    }
}

@MainActor
@Observable
final class EventListViewModel {
    let membership: CircleMembership

    var events: [Event] = []
    var filter: EventListFilter = .upcoming
    var isLoading = false
    var errorMessage: String?

    init(membership: CircleMembership) {
        self.membership = membership
    }

    var filteredEvents: [Event] {
        let now = Date()
        switch filter {
        case .upcoming:
            return events.filter { $0.startAt >= now }.sorted { $0.startAt < $1.startAt }
        case .past:
            return events.filter { $0.startAt < now }.sorted { $0.startAt > $1.startAt }
        }
    }

    var canManageEvents: Bool {
        membership.membership.role.canManageEvents
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            events = try await EventRepository.shared.fetchEvents(circleId: membership.circle.circleId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
