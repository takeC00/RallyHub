import Foundation
import FirebaseFirestore

@MainActor
final class CircleRepository {
    static let shared = CircleRepository()

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func createCircle(
        name: String,
        sportName: String,
        description: String,
        location: String,
        ownerId: String,
        ownerName: String
    ) async throws -> Circle {
        let circleRef = db.collection(FirestoreCollections.circles).document()
        let circleId = circleRef.documentID
        let now = Date()
        let circleCode = String(circleId.prefix(6)).uppercased()

        let circle = Circle(
            circleId: circleId,
            name: name,
            description: description,
            sportName: sportName,
            location: location,
            circleCode: circleCode,
            ownerId: ownerId,
            memberIds: [ownerId],
            createdAt: now
        )

        let member = CircleMember(
            circleId: circle.circleId,
            userId: ownerId,
            role: .admin,
            userName: ownerName,
            rating: RatingDefaults.initialRating,
            joinedAt: now
        )

        let memberRef = db.collection(FirestoreCollections.circleMembers)
            .document(CircleMember.documentId(circleId: circle.circleId, userId: ownerId))
        let userRef = db.collection(FirestoreCollections.users).document(ownerId)

        try await db.runTransaction { transaction, errorPointer in
            transaction.setData(circle.toDictionary(), forDocument: circleRef)
            transaction.setData(member.toDictionary(), forDocument: memberRef)
            transaction.updateData([
                "currentCircleId": circleId,
                "updatedAt": Timestamp(date: now)
            ], forDocument: userRef)
            return nil
        }

        return circle
    }

    func fetchMemberships(for userId: String) async throws -> [CircleMembership] {
        let memberSnapshot = try await db.collection(FirestoreCollections.circleMembers)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        var results: [CircleMembership] = []

        for memberDoc in memberSnapshot.documents {
            guard let membership = CircleMember.from(memberDoc) else { continue }
            let circleDoc = try await db.collection(FirestoreCollections.circles)
                .document(membership.circleId)
                .getDocument()
            guard let circle = Circle.from(circleDoc) else { continue }
            results.append(CircleMembership(circle: circle, membership: membership))
        }

        return results.sorted { $0.circle.name.localizedCaseInsensitiveCompare($1.circle.name) == .orderedAscending }
    }

    func fetchMembership(circleId: String, userId: String) async throws -> CircleMember? {
        let snapshot = try await db.collection(FirestoreCollections.circleMembers)
            .document(CircleMember.documentId(circleId: circleId, userId: userId))
            .getDocument()
        return CircleMember.from(snapshot)
    }

    func joinCircle(circleCode: String, userId: String, userName: String) async throws -> Circle {
        let trimmedCode = circleCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmedCode.isEmpty else {
            throw RallyHubError.invalidInput("招待コードを入力してください")
        }

        let circleSnapshot = try await db.collection(FirestoreCollections.circles)
            .whereField("circleCode", isEqualTo: trimmedCode)
            .limit(to: 1)
            .getDocuments()

        guard let circleDoc = circleSnapshot.documents.first,
              let circle = Circle.from(circleDoc) else {
            throw RallyHubError.notFound("招待コードが見つかりません")
        }

        let memberId = CircleMember.documentId(circleId: circle.circleId, userId: userId)
        let memberRef = db.collection(FirestoreCollections.circleMembers).document(memberId)
        let circleRef = db.collection(FirestoreCollections.circles).document(circle.circleId)

        let existing = try await memberRef.getDocument()
        if existing.exists {
            throw RallyHubError.alreadyJoined
        }

        let member = CircleMember(
            circleId: circle.circleId,
            userId: userId,
            role: .member,
            userName: userName,
            rating: RatingDefaults.initialRating,
            joinedAt: Date()
        )

        try await db.runTransaction { transaction, errorPointer in
            transaction.setData(member.toDictionary(), forDocument: memberRef)
            transaction.updateData([
                "memberIds": FieldValue.arrayUnion([userId])
            ], forDocument: circleRef)
            return nil
        }

        let updatedCircle = try await circleRef.getDocument()
        return Circle.from(updatedCircle) ?? circle
    }

    func updateCircle(
        circleId: String,
        name: String,
        sportName: String,
        description: String,
        location: String
    ) async throws {
        try await db.collection(FirestoreCollections.circles).document(circleId).updateData([
            "name": name,
            "sportName": sportName,
            "description": description,
            "location": location
        ])
    }

    func deleteCircle(circleId: String) async throws {
        let events = try await db.collection(FirestoreCollections.events)
            .whereField("circleId", isEqualTo: circleId)
            .getDocuments()

        let members = try await db.collection(FirestoreCollections.circleMembers)
            .whereField("circleId", isEqualTo: circleId)
            .getDocuments()

        let announcements = try await db.collection(FirestoreCollections.announcements)
            .whereField("circleId", isEqualTo: circleId)
            .getDocuments()

        let batch = db.batch()

        for doc in events.documents {
            batch.deleteDocument(doc.reference)
        }
        for doc in members.documents {
            batch.deleteDocument(doc.reference)
        }
        for doc in announcements.documents {
            batch.deleteDocument(doc.reference)
        }
        batch.deleteDocument(db.collection(FirestoreCollections.circles).document(circleId))

        try await batch.commit()
    }

    func updateMemberRole(circleId: String, userId: String, role: CircleRole) async throws {
        try await db.collection(FirestoreCollections.circleMembers)
            .document(CircleMember.documentId(circleId: circleId, userId: userId))
            .updateData(["role": role.firestoreValue])
    }
}
