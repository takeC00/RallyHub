import Foundation
import FirebaseFirestore

struct Circle: Identifiable, Sendable {
    let circleId: String
    let name: String
    let description: String
    let sportName: String
    let location: String
    let circleCode: String
    let ownerId: String
    let memberIds: [String]
    let createdAt: Date

    var id: String { circleId }

    var memberCount: Int { memberIds.count }

    func toDictionary() -> [String: Any] {
        [
            "name": name,
            "description": description,
            "sportName": sportName,
            "location": location,
            "circleCode": circleCode,
            "ownerId": ownerId,
            "memberIds": memberIds,
            "createdAt": Timestamp(date: createdAt)
        ]
    }

    static func from(_ document: DocumentSnapshot) -> Circle? {
        guard let data = document.data() else { return nil }
        return from(data: data, circleId: document.documentID)
    }

    static func from(data: [String: Any], circleId: String) -> Circle? {
        guard
            let name = data["name"] as? String,
            let ownerId = data["ownerId"] as? String
        else { return nil }

        let description = data["description"] as? String ?? ""
        let sportName = data["sportName"] as? String ?? RallySportOptions.defaultSport
        let location = data["location"] as? String ?? ""
        let circleCode = (data["circleCode"] as? String)
            ?? (data["inviteCode"] as? String)
            ?? String(circleId.prefix(6)).uppercased()
        let memberIds = data["memberIds"] as? [String] ?? []
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return Circle(
            circleId: circleId,
            name: name,
            description: description,
            sportName: sportName,
            location: location,
            circleCode: circleCode,
            ownerId: ownerId,
            memberIds: memberIds,
            createdAt: createdAt
        )
    }
}
