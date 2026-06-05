import Foundation
import FirebaseFirestore

enum CircleRole: String, CaseIterable, Sendable {
    case admin
    case member
    case owner

    var displayName: String {
        switch self {
        case .admin, .owner: "管理者"
        case .member: "メンバー"
        }
    }

    var canManageEvents: Bool {
        self == .admin || self == .owner
    }

    var canPostAnnouncements: Bool {
        self == .admin || self == .owner
    }

    var canManageVisitors: Bool {
        self == .admin || self == .owner
    }

    var canEditCircle: Bool {
        self == .admin || self == .owner
    }

    static func fromFirestore(_ raw: String) -> CircleRole {
        switch raw {
        case "admin", "owner": .admin
        default: .member
        }
    }

    var firestoreValue: String {
        switch self {
        case .admin, .owner: "admin"
        case .member: "member"
        }
    }
}

struct CircleMember: Identifiable, Sendable {
    let circleId: String
    let userId: String
    let role: CircleRole
    let userName: String
    let rating: Int
    let joinedAt: Date

    var id: String { "\(circleId)_\(userId)" }

    static func documentId(circleId: String, userId: String) -> String {
        "\(circleId)_\(userId)"
    }

    func toDictionary() -> [String: Any] {
        [
            "circleId": circleId,
            "userId": userId,
            "role": role.firestoreValue,
            "userName": userName,
            "rating": rating,
            "joinedAt": Timestamp(date: joinedAt)
        ]
    }

    static func from(_ document: DocumentSnapshot) -> CircleMember? {
        guard let data = document.data() else { return nil }
        guard
            let circleId = data["circleId"] as? String,
            let userId = data["userId"] as? String,
            let roleRaw = data["role"] as? String
        else { return nil }

        let userName = (data["userName"] as? String)
            ?? (data["nickname"] as? String)
            ?? ""
        guard !userName.isEmpty else { return nil }

        let role = CircleRole.fromFirestore(roleRaw)
        let rating = intValue(from: data["rating"]) ?? RatingDefaults.initialRating
        let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue() ?? Date()

        return CircleMember(
            circleId: circleId,
            userId: userId,
            role: role,
            userName: userName,
            rating: rating,
            joinedAt: joinedAt
        )
    }

    private static func intValue(from value: Any?) -> Int? {
        switch value {
        case let number as Int: number
        case let number as Int64: Int(number)
        case let number as Double: Int(number)
        default: nil
        }
    }
}

enum RatingDefaults {
    static let initialRating = 1500
}

struct CircleMembership: Identifiable, Sendable {
    let circle: Circle
    let membership: CircleMember

    var id: String { circle.circleId }
}
