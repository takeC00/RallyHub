import Foundation
import FirebaseFirestore

struct EventVisitor: Identifiable, Sendable {
    let visitorId: String
    let eventId: String
    let circleId: String
    let name: String
    let level: String?
    let memo: String?
    let createdBy: String
    let createdAt: Date

    var id: String { visitorId }

    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "visitorId": visitorId,
            "eventId": eventId,
            "circleId": circleId,
            "name": name,
            "createdBy": createdBy,
            "createdAt": Timestamp(date: createdAt)
        ]

        if let level {
            data["level"] = level
        } else {
            data["level"] = NSNull()
        }

        if let memo {
            data["memo"] = memo
        } else {
            data["memo"] = NSNull()
        }

        return data
    }

    static func from(_ document: DocumentSnapshot) -> EventVisitor? {
        guard let data = document.data() else { return nil }
        guard
            let eventId = data["eventId"] as? String,
            let circleId = data["circleId"] as? String,
            let name = data["name"] as? String,
            let createdBy = data["createdBy"] as? String
        else { return nil }

        let level = data["level"] as? String
        let memo = data["memo"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return EventVisitor(
            visitorId: document.documentID,
            eventId: eventId,
            circleId: circleId,
            name: name,
            level: level,
            memo: memo,
            createdBy: createdBy,
            createdAt: createdAt
        )
    }
}
