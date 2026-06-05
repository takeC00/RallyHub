import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Observation

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var uid: String?
    private(set) var currentUser: AppUser?
    private(set) var isReady = false
    var lastError: String?

    private var authListener: AuthStateDidChangeListenerHandle?

    private var db: Firestore { Firestore.firestore() }

    var isLoggedIn: Bool { uid != nil }

    var name: String { currentUser?.name ?? "" }

    /// 後方互換の別名
    var nickname: String { name }

    private init() {}

    func configureIfNeeded() -> Bool {
        guard AppFirebaseConfig.isPlistConfigured else {
            lastError = """
            GoogleService-Info.plist が未設定です。
            Firebase Console からダウンロードし RallyHub/RallyHub/ に配置して再ビルドしてください。
            """
            isReady = false
            return false
        }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return true
    }

    func startAuthListener() {
        guard configureIfNeeded() else { return }
        guard authListener == nil else { return }

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                await self?.applyAuthUser(user)
            }
        }
    }

    func bootstrapSession() async {
        guard configureIfNeeded() else { return }
        await applyAuthUser(Auth.auth().currentUser)
    }

    func signUp(name: String, email: String, password: String) async throws {
        guard configureIfNeeded() else { throw Self.configurationError }

        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let now = Date()
        let user = AppUser(
            uid: result.user.uid,
            name: name,
            email: email,
            currentCircleId: nil,
            createdAt: now,
            updatedAt: now,
            fcmTokens: []
        )

        try await db.collection(FirestoreCollections.users)
            .document(result.user.uid)
            .setData(user.toDictionary())

        await applyAuthUser(result.user)
    }

    func login(email: String, password: String) async throws {
        guard configureIfNeeded() else { throw Self.configurationError }

        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        await applyAuthUser(result.user)
    }

    func logout() throws {
        try Auth.auth().signOut()
        uid = nil
        currentUser = nil
        isReady = false
    }

    func updateDisplayName(_ name: String) async throws {
        guard configureIfNeeded() else { throw Self.configurationError }
        guard let uid else {
            throw NSError(
                domain: "RallyHub",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "ログイン情報が取得できません"]
            )
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(
                domain: "RallyHub",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "表示名を入力してください"]
            )
        }

        let now = Date()
        try await db.collection(FirestoreCollections.users).document(uid).updateData([
            "name": trimmed,
            "updatedAt": Timestamp(date: now)
        ])

        let memberships = try await db.collection(FirestoreCollections.circleMembers)
            .whereField("userId", isEqualTo: uid)
            .getDocuments()

        for document in memberships.documents {
            try await document.reference.updateData(["userName": trimmed])
        }

        await fetchUserProfile(uid: uid)
    }

    func saveFCMToken(_ token: String) async throws {
        guard let uid else { return }

        let ref = db.collection(FirestoreCollections.users).document(uid)
        try await ref.updateData([
            "fcmTokens": FieldValue.arrayUnion([token]),
            "updatedAt": Timestamp(date: Date())
        ])
        await fetchUserProfile(uid: uid)
    }

    private func applyAuthUser(_ user: User?) async {
        if let user, !user.isAnonymous {
            uid = user.uid
            isReady = true
            lastError = nil
            await fetchUserProfile(uid: user.uid)
        } else {
            uid = nil
            currentUser = nil
            isReady = false
        }
    }

    private func fetchUserProfile(uid: String) async {
        do {
            let snapshot = try await db.collection(FirestoreCollections.users).document(uid).getDocument()
            if let user = AppUser.from(snapshot) {
                currentUser = user
            } else if let data = snapshot.data(),
                      let email = data["email"] as? String {
                let fallbackName = (data["name"] as? String) ?? (data["nickname"] as? String) ?? ""
                if !fallbackName.isEmpty {
                    currentUser = AppUser(
                        uid: uid,
                        name: fallbackName,
                        email: email,
                        currentCircleId: data["currentCircleId"] as? String,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                        fcmTokens: data["fcmTokens"] as? [String] ?? []
                    )
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    static func authErrorMessage(for error: Error, fallback: String) -> String {
        guard let errorCode = AuthErrorCode(rawValue: (error as NSError).code) else {
            return fallback
        }

        switch errorCode.code {
        case .invalidEmail:
            return "メールアドレスの形式が正しくありません"
        case .wrongPassword:
            return "パスワードが違います"
        case .userNotFound:
            return "アカウントが存在しません"
        case .emailAlreadyInUse:
            return "このメールアドレスは既に使用されています"
        case .weakPassword:
            return "パスワードは6文字以上で入力してください"
        case .networkError:
            return "通信エラーが発生しました"
        case .tooManyRequests:
            return "試行回数が多すぎます。少し待ってください"
        default:
            return fallback
        }
    }

    private static var configurationError: NSError {
        NSError(
            domain: "RallyHub",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Firebase が設定されていません"]
        )
    }
}
