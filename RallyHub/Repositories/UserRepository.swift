import Foundation
import FirebaseFirestore

@MainActor
final class UserRepository {
    static let shared = UserRepository()

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func fetchUser(uid: String) async throws -> AppUser? {
        let snapshot = try await db.collection(FirestoreCollections.users).document(uid).getDocument()
        return AppUser.from(snapshot)
    }
}
