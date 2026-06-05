import Foundation
import FirebaseFirestore

enum ParticipantStatus: String, CaseIterable, Sendable {
    case join
    case absent
    case pending

    var displayName: String {
        switch self {
        case .join: "参加"
        case .absent: "不参加"
        case .pending: "保留"
        }
    }
}

struct EventParticipant: Identifiable, Sendable {
    let eventId: String
    let circleId: String
    let userId: String
    let nickname: String
    let status: ParticipantStatus
    let updatedAt: Date

    var id: String { "\(eventId)_\(userId)" }

    static func documentId(eventId: String, userId: String) -> String {
        "\(eventId)_\(userId)"
    }

    func toDictionary() -> [String: Any] {
        [
            "eventId": eventId,
            "circleId": circleId,
            "userId": userId,
            "nickname": nickname,
            "status": status.rawValue,
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }

    static func from(_ document: DocumentSnapshot) -> EventParticipant? {
        guard let data = document.data() else { return nil }
        guard
            let eventId = data["eventId"] as? String,
            let circleId = data["circleId"] as? String,
            let userId = data["userId"] as? String,
            let nickname = data["nickname"] as? String,
            let statusRaw = data["status"] as? String,
            let status = ParticipantStatus(rawValue: statusRaw)
        else { return nil }

        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        return EventParticipant(
            eventId: eventId,
            circleId: circleId,
            userId: userId,
            nickname: nickname,
            status: status,
            updatedAt: updatedAt
        )
    }
}
