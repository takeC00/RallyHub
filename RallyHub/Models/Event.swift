import Foundation
import FirebaseFirestore

struct Event: Identifiable, Sendable {
    let eventId: String
    let circleId: String
    let title: String
    let startAt: Date
    let endAt: Date
    let location: String
    let note: String
    let capacity: Int?
    let isCapacityLimited: Bool
    let participantCount: Int
    let absentCount: Int
    let pendingCount: Int
    let visitorCount: Int
    let isFull: Bool
    let createdBy: String
    let createdAt: Date
    let updatedAt: Date
    let fullNotifiedAt: Date?
    let vacancyNotifiedAt: Date?

    var id: String { eventId }

    var isUpcoming: Bool {
        startAt >= Date()
    }

    var totalJoinedCount: Int {
        participantCount + visitorCount
    }

    var capacityDisplay: String {
        if isCapacityLimited, let capacity {
            return "\(totalJoinedCount) / \(capacity) 人"
        }
        return "\(totalJoinedCount) 人"
    }

    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "eventId": eventId,
            "circleId": circleId,
            "title": title,
            "startAt": Timestamp(date: startAt),
            "endAt": Timestamp(date: endAt),
            "location": location,
            "note": note,
            "isCapacityLimited": isCapacityLimited,
            "participantCount": participantCount,
            "absentCount": absentCount,
            "pendingCount": pendingCount,
            "visitorCount": visitorCount,
            "isFull": isFull,
            "createdBy": createdBy,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]

        if let capacity {
            data["capacity"] = capacity
        } else {
            data["capacity"] = NSNull()
        }

        if let fullNotifiedAt {
            data["fullNotifiedAt"] = Timestamp(date: fullNotifiedAt)
        } else {
            data["fullNotifiedAt"] = NSNull()
        }

        if let vacancyNotifiedAt {
            data["vacancyNotifiedAt"] = Timestamp(date: vacancyNotifiedAt)
        } else {
            data["vacancyNotifiedAt"] = NSNull()
        }

        return data
    }

    static func from(_ document: DocumentSnapshot) -> Event? {
        guard let data = document.data() else { return nil }
        return from(data: data, eventId: document.documentID)
    }

    static func from(data: [String: Any], eventId: String) -> Event? {
        guard
            let circleId = data["circleId"] as? String,
            let title = data["title"] as? String,
            let startAt = (data["startAt"] as? Timestamp)?.dateValue(),
            let endAt = (data["endAt"] as? Timestamp)?.dateValue(),
            let location = data["location"] as? String,
            let createdBy = data["createdBy"] as? String
        else { return nil }

        let note = data["note"] as? String ?? ""
        let isCapacityLimited = data["isCapacityLimited"] as? Bool ?? false
        let capacity = Self.intValue(from: data["capacity"])
        let participantCount = Self.intValue(from: data["participantCount"]) ?? 0
        let absentCount = Self.intValue(from: data["absentCount"]) ?? 0
        let pendingCount = Self.intValue(from: data["pendingCount"]) ?? 0
        let visitorCount = Self.intValue(from: data["visitorCount"]) ?? 0
        let isFull = data["isFull"] as? Bool ?? false
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
        let fullNotifiedAt = (data["fullNotifiedAt"] as? Timestamp)?.dateValue()
        let vacancyNotifiedAt = (data["vacancyNotifiedAt"] as? Timestamp)?.dateValue()

        return Event(
            eventId: eventId,
            circleId: circleId,
            title: title,
            startAt: startAt,
            endAt: endAt,
            location: location,
            note: note,
            capacity: capacity,
            isCapacityLimited: isCapacityLimited,
            participantCount: participantCount,
            absentCount: absentCount,
            pendingCount: pendingCount,
            visitorCount: visitorCount,
            isFull: isFull,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            fullNotifiedAt: fullNotifiedAt,
            vacancyNotifiedAt: vacancyNotifiedAt
        )
    }

    private static func intValue(from value: Any?) -> Int? {
        switch value {
        case let number as Int:
            return number
        case let number as Int64:
            return Int(number)
        case let number as Double:
            return Int(number)
        default:
            return nil
        }
    }

    static func computeIsFull(
        isCapacityLimited: Bool,
        capacity: Int?,
        participantCount: Int,
        visitorCount: Int
    ) -> Bool {
        guard isCapacityLimited, let capacity else { return false }
        return participantCount + visitorCount >= capacity
    }
}
