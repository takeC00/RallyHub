import SwiftUI

struct CircleJoinView: View {
    @Environment(\.dismiss) private var dismiss

    let onJoined: () -> Void

    @State private var circleCode = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    private var isEnabled: Bool {
        !circleCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        Form {
            Section {
                TextField("招待コード（例：ABC123）", text: $circleCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
            } footer: {
                Text("サークル主催者から共有された招待コードを入力してください")
            }

            if !errorMessage.isEmpty {
                Section { ErrorBanner(message: errorMessage) }
            }

            if !successMessage.isEmpty {
                Section {
                    Text(successMessage).foregroundStyle(.green)
                }
            }

            Section {
                Button(isLoading ? "参加中..." : "参加する") {
                    Task { await join() }
                }
                .disabled(!isEnabled)
            }
        }
        .navigationTitle("サークル参加")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                LoadingOverlay(message: "参加中...")
            }
        }
    }

    private func join() async {
        guard let uid = AuthService.shared.uid else { return }

        isLoading = true
        errorMessage = ""
        successMessage = ""
        defer { isLoading = false }

        do {
            let circle = try await CircleRepository.shared.joinCircle(
                circleCode: circleCode,
                userId: uid,
                userName: AuthService.shared.name
            )
            successMessage = "「\(circle.name)」に参加しました"
            onJoined()
            try? await Task.sleep(for: .milliseconds(600))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
