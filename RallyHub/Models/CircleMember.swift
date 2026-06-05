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

    var canManageManualMembers: Bool {
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
    let documentId: String
    let circleId: String
    /// 正式メンバーの Firebase Auth UID。手動登録の場合は nil
    let userId: String?
    let role: CircleRole
    let userName: String
    let rating: Int
    let memberType: MemberType
    let level: String?
    let notes: String?
    let isActive: Bool
    let createdBy: String?
    let joinedAt: Date
    let updatedAt: Date?

    var id: String { documentId }

    var isRegistered: Bool { memberType == .registered }
    var isManual: Bool { memberType == .manual }

    var matchParticipantId: String {
        switch memberType {
        case .registered:
            return userId ?? documentId
        case .manual:
            return "manual:\(documentId)"
        }
    }

    static func documentId(circleId: String, userId: String) -> String {
        "\(circleId)_\(userId)"
    }

    static func manualDocumentId(circleId: String, memberId: String) -> String {
        "\(circleId)_\(memberId)"
    }

    func toDictionary(createdByUid: String? = nil) -> [String: Any] {
        var data: [String: Any] = [
            "circleId": circleId,
            "role": role.firestoreValue,
            "userName": userName,
            "displayName": userName,
            "rating": rating,
            "memberType": memberType.rawValue,
            "isActive": isActive,
            "joinedAt": Timestamp(date: joinedAt),
            "updatedAt": Timestamp(date: updatedAt ?? .now),
        ]

        if let userId {
            data["userId"] = userId
        }
        if let level {
            data["level"] = level
        }
        if let notes, !notes.isEmpty {
            data["notes"] = notes
        }
        if let creator = createdBy ?? createdByUid {
            data["createdBy"] = creator
        }

        return data
    }

    static func from(_ document: DocumentSnapshot) -> CircleMember? {
        guard let data = document.data() else { return nil }
        guard
            let circleId = data["circleId"] as? String,
            let roleRaw = data["role"] as? String
        else { return nil }

        let userName = (data["userName"] as? String)
            ?? (data["displayName"] as? String)
            ?? (data["nickname"] as? String)
            ?? ""
        guard !userName.isEmpty else { return nil }

        let userId = data["userId"] as? String
        let memberType: MemberType
        if let raw = data["memberType"] as? String {
            memberType = MemberType.fromFirestore(raw)
        } else if userId != nil {
            memberType = .registered
        } else {
            return nil
        }

        if memberType == .registered && userId == nil { return nil }
        if memberType == .manual && userId != nil { return nil }

        let role = CircleRole.fromFirestore(roleRaw)
        let rating = intValue(from: data["rating"]) ?? RatingDefaults.initialRating
        let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue()
            ?? (data["createdAt"] as? Timestamp)?.dateValue()
            ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        let level = data["level"] as? String
        let notes = data["notes"] as? String
        let isActive = data["isActive"] as? Bool ?? true
        let createdBy = data["createdBy"] as? String

        guard isActive else { return nil }

        return CircleMember(
            documentId: document.documentID,
            circleId: circleId,
            userId: userId,
            role: role,
            userName: userName,
            rating: rating,
            memberType: memberType,
            level: level,
            notes: notes,
            isActive: isActive,
            createdBy: createdBy,
            joinedAt: joinedAt,
            updatedAt: updatedAt
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
