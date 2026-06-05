import Foundation
import FirebaseFirestore

@MainActor
final class AnnouncementRepository {
    static let shared = AnnouncementRepository()

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func fetchAnnouncements(circleId: String) async throws -> [Announcement] {
        let snapshot = try await db.collection(FirestoreCollections.announcements)
            .whereField("circleId", isEqualTo: circleId)
            .getDocuments()

        return snapshot.documents
            .compactMap { Announcement.from($0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func createAnnouncement(
        circleId: String,
        title: String,
        body: String,
        createdBy: String
    ) async throws -> Announcement {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            throw RallyHubError.invalidInput("タイトルを入力してください")
        }
        guard !trimmedBody.isEmpty else {
            throw RallyHubError.invalidInput("本文を入力してください")
        }

        let ref = db.collection(FirestoreCollections.announcements).document()
        let now = Date()

        let announcement = Announcement(
            announcementId: ref.documentID,
            circleId: circleId,
            title: trimmedTitle,
            body: trimmedBody,
            createdBy: createdBy,
            createdAt: now,
            updatedAt: now
        )

        try await ref.setData(announcement.toDictionary())
        return announcement
    }
}
