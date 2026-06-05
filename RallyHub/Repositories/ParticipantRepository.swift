import Foundation
import FirebaseFirestore

@MainActor
final class ParticipantRepository {
    static let shared = ParticipantRepository()

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func fetchParticipants(eventId: String) async throws -> [EventParticipant] {
        let snapshot = try await db.collection(FirestoreCollections.eventParticipants)
            .whereField("eventId", isEqualTo: eventId)
            .getDocuments()

        return snapshot.documents
            .compactMap { EventParticipant.from($0) }
            .sorted { lhs, rhs in
                if lhs.status == rhs.status {
                    return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
                }
                return Self.statusOrder(lhs.status) < Self.statusOrder(rhs.status)
            }
    }

    func fetchParticipant(eventId: String, userId: String) async throws -> EventParticipant? {
        let snapshot = try await db.collection(FirestoreCollections.eventParticipants)
            .document(EventParticipant.documentId(eventId: eventId, userId: userId))
            .getDocument()
        return EventParticipant.from(snapshot)
    }

    func updateAttendance(
        event: Event,
        userId: String,
        nickname: String,
        newStatus: ParticipantStatus
    ) async throws {
        let participantRef = db.collection(FirestoreCollections.eventParticipants)
            .document(EventParticipant.documentId(eventId: event.eventId, userId: userId))
        let eventRef = db.collection(FirestoreCollections.events).document(event.eventId)

        let existing = try await participantRef.getDocument()
        let previousStatus = existing.exists
            ? EventParticipant.from(existing)?.status
            : nil

        if newStatus == .join, event.isFull, previousStatus != .join {
            throw RallyHubError.eventFull
        }

        let participant = EventParticipant(
            eventId: event.eventId,
            circleId: event.circleId,
            userId: userId,
            nickname: nickname,
            status: newStatus,
            updatedAt: Date()
        )

        let counts = Self.adjustedCounts(
            event: event,
            previousStatus: previousStatus,
            newStatus: newStatus
        )

        let isFull = Event.computeIsFull(
            isCapacityLimited: event.isCapacityLimited,
            capacity: event.capacity,
            participantCount: counts.participantCount,
            visitorCount: event.visitorCount
        )

        try await db.runTransaction { transaction, errorPointer in
            do {
                transaction.setData(participant.toDictionary(), forDocument: participantRef)

                var updates: [String: Any] = [
                    "participantCount": counts.participantCount,
                    "absentCount": counts.absentCount,
                    "pendingCount": counts.pendingCount,
                    "isFull": isFull,
                    "updatedAt": Timestamp(date: Date())
                ]

                if event.isFull != isFull {
                    if isFull {
                        updates["fullNotifiedAt"] = NSNull()
                    } else {
                        updates["vacancyNotifiedAt"] = NSNull()
                    }
                }

                transaction.updateData(updates, forDocument: eventRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            return nil
        }
    }

    private static func adjustedCounts(
        event: Event,
        previousStatus: ParticipantStatus?,
        newStatus: ParticipantStatus
    ) -> (participantCount: Int, absentCount: Int, pendingCount: Int) {
        var participantCount = event.participantCount
        var absentCount = event.absentCount
        var pendingCount = event.pendingCount

        if let previousStatus {
            switch previousStatus {
            case .join: participantCount -= 1
            case .absent: absentCount -= 1
            case .pending: pendingCount -= 1
            }
        }

        switch newStatus {
        case .join: participantCount += 1
        case .absent: absentCount += 1
        case .pending: pendingCount += 1
        }

        return (
            max(participantCount, 0),
            max(absentCount, 0),
            max(pendingCount, 0)
        )
    }

    private static func statusOrder(_ status: ParticipantStatus) -> Int {
        switch status {
        case .join: 0
        case .pending: 1
        case .absent: 2
        }
    }
}
