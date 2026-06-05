import Foundation
import FirebaseCore

enum AppFirebaseConfig {
    static var isPlistConfigured: Bool {
        loadPlistValues() != nil
    }

    static var projectId: String? {
        loadPlistValues()?.projectID
    }

    static var bundleId: String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let value = dict["BUNDLE_ID"] as? String,
              !value.isEmpty
        else { return nil }
        return value
    }

    static func configureIfNeeded() -> Bool {
        guard loadPlistValues() != nil else { return false }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return true
    }

    private struct PlistValues {
        let googleAppID: String
        let gcmSenderID: String
        let apiKey: String
        let projectID: String
    }

    private static func loadPlistValues() -> PlistValues? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let googleAppID = dict["GOOGLE_APP_ID"] as? String,
              let gcmSenderID = dict["GCM_SENDER_ID"] as? String,
              let apiKey = dict["API_KEY"] as? String,
              let projectID = dict["PROJECT_ID"] as? String,
              !googleAppID.contains("YOUR_"),
              !apiKey.contains("YOUR_"),
              !projectID.contains("YOUR_")
        else {
            return nil
        }

        return PlistValues(
            googleAppID: googleAppID,
            gcmSenderID: gcmSenderID,
            apiKey: apiKey,
            projectID: projectID
        )
    }
}
