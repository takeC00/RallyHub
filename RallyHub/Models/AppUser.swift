import Foundation
import FirebaseFirestore

struct AppUser: Identifiable, Sendable {
    let uid: String
    let name: String
    let email: String
    let currentCircleId: String?
    let createdAt: Date
    let updatedAt: Date
    let fcmTokens: [String]

    var id: String { uid }

    /// RallyMate / RallyHub 共通フィールド名
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "userId": uid,
            "name": name,
            "email": email,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "fcmTokens": fcmTokens
        ]
        if let currentCircleId {
            data["currentCircleId"] = currentCircleId
        } else {
            data["currentCircleId"] = NSNull()
        }
        return data
    }

    static func from(_ document: DocumentSnapshot) -> AppUser? {
        guard let data = document.data() else { return nil }
        return from(data: data, uid: document.documentID)
    }

    static func from(data: [String: Any], uid: String) -> AppUser? {
        guard let email = data["email"] as? String else { return nil }

        let name = (data["name"] as? String)
            ?? (data["nickname"] as? String)
            ?? ""

        guard !name.isEmpty else { return nil }

        let currentCircleId = data["currentCircleId"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
        let fcmTokens = data["fcmTokens"] as? [String] ?? []

        return AppUser(
            uid: uid,
            name: name,
            email: email,
            currentCircleId: currentCircleId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            fcmTokens: fcmTokens
        )
    }
}
