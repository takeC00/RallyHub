import Foundation
import FirebaseFirestore

@MainActor
final class EventRepository {
    static let shared = EventRepository()

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    struct EventDraft {
        let title: String
        let startAt: Date
        let endAt: Date
        let location: String
        let note: String
        let capacity: Int?
        let isCapacityLimited: Bool
    }

    func createEvent(
        circleId: String,
        draft: EventDraft,
        createdBy: String
    ) async throws -> Event {
        let ref = db.collection(FirestoreCollections.events).document()
        let now = Date()

        let event = Event(
            eventId: ref.documentID,
            circleId: circleId,
            title: draft.title,
            startAt: draft.startAt,
            endAt: draft.endAt,
            location: draft.location,
            note: draft.note,
            capacity: draft.isCapacityLimited ? draft.capacity : nil,
            isCapacityLimited: draft.isCapacityLimited,
            participantCount: 0,
            absentCount: 0,
            pendingCount: 0,
            visitorCount: 0,
            isFull: false,
            createdBy: createdBy,
            createdAt: now,
            updatedAt: now,
            fullNotifiedAt: nil,
            vacancyNotifiedAt: nil
        )

        try await ref.setData(event.toDictionary())
        return event
    }

    func createRecurringEvents(
        circleId: String,
        draft: EventDraft,
        dates: [Date],
        startTime: Date,
        endTime: Date,
        createdBy: String,
        calendar: Calendar = .current
    ) async throws -> [Event] {
        guard !dates.isEmpty else {
            throw RallyHubError.invalidInput("作成対象の日付がありません")
        }

        var created: [Event] = []
        let batch = db.batch()
        let now = Date()

        for date in dates {
            let startAt = RecurringEventPlanner.combine(date: date, time: startTime, calendar: calendar)
            let endAt = RecurringEventPlanner.combine(date: date, time: endTime, calendar: calendar)
            let ref = db.collection(FirestoreCollections.events).document()

            let event = Event(
                eventId: ref.documentID,
                circleId: circleId,
                title: draft.title,
                startAt: startAt,
                endAt: endAt,
                location: draft.location,
                note: draft.note,
                capacity: draft.isCapacityLimited ? draft.capacity : nil,
                isCapacityLimited: draft.isCapacityLimited,
                participantCount: 0,
                absentCount: 0,
                pendingCount: 0,
                visitorCount: 0,
                isFull: false,
                createdBy: createdBy,
                createdAt: now,
                updatedAt: now,
                fullNotifiedAt: nil,
                vacancyNotifiedAt: nil
            )

            batch.setData(event.toDictionary(), forDocument: ref)
            created.append(event)
        }

        try await batch.commit()
        return created
    }

    func fetchEvents(circleId: String) async throws -> [Event] {
        let snapshot = try await db.collection(FirestoreCollections.events)
            .whereField("circleId", isEqualTo: circleId)
            .getDocuments()

        return snapshot.documents
            .compactMap { Event.from($0) }
            .sorted { $0.startAt < $1.startAt }
    }

    func fetchEvent(eventId: String) async throws -> Event? {
        let snapshot = try await db.collection(FirestoreCollections.events).document(eventId).getDocument()
        return Event.from(snapshot)
    }

    func listenEvent(
        eventId: String,
        onChange: @escaping (Event?) -> Void
    ) -> ListenerRegistration {
        db.collection(FirestoreCollections.events).document(eventId)
            .addSnapshotListener { snapshot, _ in
                let event = snapshot.flatMap { Event.from($0) }
                Task { @MainActor in
                    onChange(event)
                }
            }
    }
}
