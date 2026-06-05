import Foundation
import FirebaseFirestore

struct Announcement: Identifiable, Sendable {
    let announcementId: String
    let circleId: String
    let title: String
    let body: String
    let createdBy: String
    let createdAt: Date
    let updatedAt: Date

    var id: String { announcementId }

    func toDictionary() -> [String: Any] {
        [
            "announcementId": announcementId,
            "circleId": circleId,
            "title": title,
            "body": body,
            "createdBy": createdBy,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }

    static func from(_ document: DocumentSnapshot) -> Announcement? {
        guard let data = document.data() else { return nil }
        return from(data: data, announcementId: document.documentID)
    }

    static func from(data: [String: Any], announcementId: String) -> Announcement? {
        guard
            let circleId = data["circleId"] as? String,
            let title = data["title"] as? String,
            let body = data["body"] as? String,
            let createdBy = data["createdBy"] as? String
        else { return nil }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt

        return Announcement(
            announcementId: announcementId,
            circleId: circleId,
            title: title,
            body: body,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
