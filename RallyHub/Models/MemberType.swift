import Foundation

/// Firestore `circleMembers.memberType`（RallyOS 共通）
enum MemberType: String, Codable, Sendable, CaseIterable {
    case registered
    case manual

    var displayName: String {
        switch self {
        case .registered: "メンバー"
        case .manual: "手動登録"
        }
    }

    static func fromFirestore(_ raw: String?) -> MemberType {
        guard let raw else { return .registered }
        return MemberType(rawValue: raw) ?? .registered
    }
}
