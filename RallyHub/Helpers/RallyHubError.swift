import Foundation
import FirebaseFirestore

enum RallyHubError: LocalizedError {
    case notLoggedIn
    case notFound(String)
    case alreadyJoined
    case eventFull
    case permissionDenied
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            "ログインが必要です"
        case .notFound(let message):
            message
        case .alreadyJoined:
            "すでに参加済みです"
        case .eventFull:
            "定員に達しているため参加できません"
        case .permissionDenied:
            "権限がありません"
        case .invalidInput(let message):
            message
        }
    }
}

struct InviteCodeGenerator {
    private static let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate(length: Int = 6) -> String {
        String((0..<length).map { _ in characters.randomElement()! })
    }
}

struct RecurringEventPlanner {
    static func dates(
        from startDate: Date,
        to endDate: Date,
        weekday: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        guard startDate <= endDate else { return [] }

        var results: [Date] = []
        var cursor = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        while cursor <= end {
            if calendar.component(.weekday, from: cursor) == weekday {
                results.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return results
    }

    static func combine(date: Date, time: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        var merged = DateComponents()
        merged.year = day.year
        merged.month = day.month
        merged.day = day.day
        merged.hour = clock.hour
        merged.minute = clock.minute
        return calendar.date(from: merged) ?? date
    }
}
