import Foundation
import FirebaseFirestore
import Observation

@MainActor
@Observable
final class EventDetailViewModel {
    let membership: CircleMembership
    let eventId: String

    var event: Event?
    var participants: [EventParticipant] = []
    var visitors: [EventVisitor] = []
    var myParticipant: EventParticipant?
    var isLoading = false
    var isUpdating = false
    var errorMessage: String?

    private var eventListener: ListenerRegistration?

    init(membership: CircleMembership, eventId: String) {
        self.membership = membership
        self.eventId = eventId
    }

    var canManageVisitors: Bool {
        membership.membership.role.canManageVisitors
    }

    var canJoin: Bool {
        guard let event else { return false }
        if myParticipant?.status == .join { return true }
        return !event.isFull
    }

    func stopListening() {
        eventListener?.remove()
        eventListener = nil
    }

    func startListening() {
        eventListener?.remove()
        eventListener = EventRepository.shared.listenEvent(eventId: eventId) { [weak self] event in
            Task { @MainActor in
                self?.event = event
            }
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let eventTask = EventRepository.shared.fetchEvent(eventId: eventId)
            async let participantsTask = ParticipantRepository.shared.fetchParticipants(eventId: eventId)
            async let visitorsTask = VisitorRepository.shared.fetchVisitors(eventId: eventId)

            event = try await eventTask
            participants = try await participantsTask
            visitors = try await visitorsTask

            if let uid = AuthService.shared.uid {
                myParticipant = try await ParticipantRepository.shared.fetchParticipant(
                    eventId: eventId,
                    userId: uid
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateAttendance(_ status: ParticipantStatus) async {
        guard let event, let uid = AuthService.shared.uid else { return }

        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }

        do {
            try await ParticipantRepository.shared.updateAttendance(
                event: event,
                userId: uid,
                nickname: AuthService.shared.nickname,
                newStatus: status
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
