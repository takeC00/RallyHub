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
            documentId: CircleMember.documentId(circleId: circle.circleId, userId: ownerId),
            circleId: circle.circleId,
            userId: ownerId,
            role: .admin,
            userName: ownerName,
            rating: RatingDefaults.initialRating,
            memberType: .registered,
            level: nil,
            notes: nil,
            isActive: true,
            createdBy: ownerId,
            joinedAt: now,
            updatedAt: now
        )

        let memberRef = db.collection(FirestoreCollections.circleMembers)
            .document(CircleMember.documentId(circleId: circle.circleId, userId: ownerId))
        let userRef = db.collection(FirestoreCollections.users).document(ownerId)

        try await db.runTransaction { transaction, errorPointer in
            transaction.setData(circle.toDictionary(), forDocument: circleRef)
            transaction.setData(member.toDictionary(), forDocument: memberRef)
            transaction.setData([
                "currentCircleId": circleId,
                "updatedAt": Timestamp(date: now)
            ], forDocument: userRef, merge: true)
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
            documentId: memberId,
            circleId: circle.circleId,
            userId: userId,
            role: .member,
            userName: userName,
            rating: RatingDefaults.initialRating,
            memberType: .registered,
            level: nil,
            notes: nil,
            isActive: true,
            createdBy: userId,
            joinedAt: Date(),
            updatedAt: Date()
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

    func fetchCircleMembers(circleId: String) async throws -> [CircleMember] {
        let snapshot = try await db.collection(FirestoreCollections.circleMembers)
            .whereField("circleId", isEqualTo: circleId)
            .getDocuments()

        return snapshot.documents
            .compactMap { CircleMember.from($0) }
            .sorted { $0.userName.localizedCaseInsensitiveCompare($1.userName) == .orderedAscending }
    }

    func createManualMember(
        circleId: String,
        displayName: String,
        rating: Int = RatingDefaults.initialRating,
        level: String?,
        notes: String?,
        createdBy: String
    ) async throws -> CircleMember {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RallyHubError.invalidInput("表示名を入力してください")
        }

        let existing = try await fetchCircleMembers(circleId: circleId)
        if existing.contains(where: { $0.userName.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw RallyHubError.invalidInput("同じ名前のメンバーが既にいます")
        }

        let memberId = UUID().uuidString.lowercased()
        let documentId = CircleMember.manualDocumentId(circleId: circleId, memberId: memberId)
        let now = Date()

        let member = CircleMember(
            documentId: documentId,
            circleId: circleId,
            userId: nil,
            role: .member,
            userName: trimmed,
            rating: rating,
            memberType: .manual,
            level: level,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            isActive: true,
            createdBy: createdBy,
            joinedAt: now,
            updatedAt: now
        )

        try await db.collection(FirestoreCollections.circleMembers)
            .document(documentId)
            .setData(member.toDictionary(createdByUid: createdBy))

        return member
    }

    func updateManualMember(
        _ member: CircleMember,
        displayName: String,
        rating: Int,
        level: String?,
        notes: String?
    ) async throws {
        guard member.isManual else {
            throw RallyHubError.invalidInput("手動登録メンバーのみ編集できます")
        }

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RallyHubError.invalidInput("表示名を入力してください")
        }

        try await db.collection(FirestoreCollections.circleMembers)
            .document(member.documentId)
            .updateData([
                "userName": trimmed,
                "displayName": trimmed,
                "rating": rating,
                "level": level ?? NSNull(),
                "notes": notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? NSNull(),
                "updatedAt": Timestamp(date: .now),
            ])
    }

    func deactivateManualMember(_ member: CircleMember) async throws {
        guard member.isManual else {
            throw RallyHubError.invalidInput("手動登録メンバーのみ削除できます")
        }

        try await db.collection(FirestoreCollections.circleMembers)
            .document(member.documentId)
            .updateData([
                "isActive": false,
                "updatedAt": Timestamp(date: .now),
            ])
    }

    func deleteCircle(circleId: String, ownerId: String) async throws {
        try await deleteDocuments(
            matching: db.collection(FirestoreCollections.eventParticipants)
                .whereField("circleId", isEqualTo: circleId)
        )
        try await deleteDocuments(
            matching: db.collection(FirestoreCollections.eventVisitors)
                .whereField("circleId", isEqualTo: circleId)
        )
        try await deleteDocuments(
            matching: db.collection(FirestoreCollections.events)
                .whereField("circleId", isEqualTo: circleId)
        )
        try await deleteDocuments(
            matching: db.collection(FirestoreCollections.announcements)
                .whereField("circleId", isEqualTo: circleId)
        )
        try await deleteDocuments(
            matching: db.collection("circleDayParticipants").whereField("circleId", isEqualTo: circleId)
        )
        try await deleteDocuments(
            matching: db.collection("circleRoster").whereField("circleId", isEqualTo: circleId)
        )
        try await deleteDocuments(
            matching: db.collection("matches").whereField("circleId", isEqualTo: circleId)
        )
        try await deleteDocuments(
            matching: db.collection("ratingSnapshots").whereField("circleId", isEqualTo: circleId)
        )

        await deleteSessions(for: circleId)

        try await deleteDocuments(
            matching: db.collection(FirestoreCollections.circleMembers)
                .whereField("circleId", isEqualTo: circleId)
        )

        try await db.collection(FirestoreCollections.circles).document(circleId).delete()

        let userRef = db.collection(FirestoreCollections.users).document(ownerId)
        let userDoc = try await userRef.getDocument()
        if userDoc.data()?["currentCircleId"] as? String == circleId {
            try await userRef.updateData([
                "currentCircleId": FieldValue.delete(),
                "updatedAt": Timestamp(date: Date())
            ])
        }
    }

    private func deleteSessions(for circleId: String) async {
        let stableSessionId = circleId.lowercased()
        try? await deleteSession(stableSessionId)

        do {
            let sessions = try await db.collection("sessions")
                .whereField("circleId", isEqualTo: circleId)
                .getDocuments()
            for document in sessions.documents where document.documentID != stableSessionId {
                try await deleteSession(document.documentID)
            }
        } catch {
            // stableSessionId の削除だけでも通常は十分
        }
    }

    private func deleteDocuments(matching query: Query) async throws {
        while true {
            let snapshot = try await query.limit(to: 300).getDocuments()
            if snapshot.isEmpty { return }

            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }
    }

    private func deleteSession(_ sessionId: String) async throws {
        let sessionRef = db.collection("sessions").document(sessionId)
        try await deleteCollection(sessionRef.collection("matches"))
        try await deleteCollection(sessionRef.collection("sessionPlayers"))
        try await sessionRef.delete()
    }

    private func deleteCollection(_ collection: CollectionReference) async throws {
        while true {
            let snapshot = try await collection.limit(to: 300).getDocuments()
            if snapshot.isEmpty { return }

            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }
    }

    func updateMemberRole(circleId: String, userId: String, role: CircleRole) async throws {
        try await db.collection(FirestoreCollections.circleMembers)
            .document(CircleMember.documentId(circleId: circleId, userId: userId))
            .updateData(["role": role.firestoreValue])
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
