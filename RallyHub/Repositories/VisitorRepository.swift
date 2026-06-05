import Foundation
import FirebaseFirestore

@MainActor
final class VisitorRepository {
    static let shared = VisitorRepository()

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func fetchVisitors(eventId: String) async throws -> [EventVisitor] {
        let snapshot = try await db.collection(FirestoreCollections.eventVisitors)
            .whereField("eventId", isEqualTo: eventId)
            .getDocuments()

        return snapshot.documents
            .compactMap { EventVisitor.from($0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addVisitor(
        event: Event,
        name: String,
        level: String?,
        memo: String?,
        createdBy: String
    ) async throws -> EventVisitor {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw RallyHubError.invalidInput("名前を入力してください")
        }

        let ref = db.collection(FirestoreCollections.eventVisitors).document()
        let visitor = EventVisitor(
            visitorId: ref.documentID,
            eventId: event.eventId,
            circleId: event.circleId,
            name: trimmedName,
            level: level?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            memo: memo?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            createdBy: createdBy,
            createdAt: Date()
        )

        let newVisitorCount = event.visitorCount + 1
        let isFull = Event.computeIsFull(
            isCapacityLimited: event.isCapacityLimited,
            capacity: event.capacity,
            participantCount: event.participantCount,
            visitorCount: newVisitorCount
        )

        let eventRef = db.collection(FirestoreCollections.events).document(event.eventId)

        try await db.runTransaction { transaction, errorPointer in
            do {
                transaction.setData(visitor.toDictionary(), forDocument: ref)

                var updates: [String: Any] = [
                    "visitorCount": newVisitorCount,
                    "isFull": isFull,
                    "updatedAt": Timestamp(date: Date())
                ]

                if event.isFull != isFull, isFull {
                    updates["fullNotifiedAt"] = NSNull()
                }

                transaction.updateData(updates, forDocument: eventRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            return nil
        }

        return visitor
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
