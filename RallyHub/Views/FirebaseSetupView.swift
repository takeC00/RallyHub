import SwiftUI

struct FirebaseSetupView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Firebase 設定が必要です", systemImage: "exclamationmark.triangle.fill")
                        .font(.title2.bold())
                        .foregroundStyle(.orange)

                    Text("RallyHub を起動するには、Firebase Console から取得した GoogleService-Info.plist を配置してください。")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        setupStep(number: 1, text: "Firebase Console でプロジェクト rallyos を開く")
                        setupStep(number: 2, text: "iOS アプリを追加（Bundle ID: com.take.RallyHub）")
                        setupStep(number: 3, text: "GoogleService-Info.plist をダウンロード")
                        setupStep(number: 4, text: "RallyHub/RallyHub/GoogleService-Info.plist を上書き")
                        setupStep(number: 5, text: "Xcode でクリーンビルドして再起動")
                    }

                    if let bundleId = AppFirebaseConfig.bundleId {
                        Text("現在の plist BUNDLE_ID: \(bundleId)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://console.firebase.google.com/")!) {
                        Label("Firebase Console を開く", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(24)
            }
            .navigationTitle("RallyHub")
        }
    }

    private func setupStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.orange, in: SwiftUI.Circle())
            Text(text)
                .font(.subheadline)
        }
    }
}
