import SwiftUI

struct VisitorAddView: View {
    @Environment(\.dismiss) private var dismiss

    let membership: CircleMembership
    let event: Event
    let onAdded: () -> Void

    @State private var name = ""
    @State private var level = ""
    @State private var memo = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    private var isEnabled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        Form {
            Section("参加者情報") {
                TextField("名前", text: $name)
                TextField("レベル（任意）", text: $level)
                TextField("メモ（任意）", text: $memo, axis: .vertical)
                    .lineLimit(2...4)
            }

            if !errorMessage.isEmpty {
                Section { ErrorBanner(message: errorMessage) }
            }
        }
        .navigationTitle("今日だけ参加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isLoading ? "追加中..." : "追加") {
                    Task { await addVisitor() }
                }
                .disabled(!isEnabled)
            }
        }
        .overlay {
            if isLoading {
                LoadingOverlay(message: "追加中...")
            }
        }
    }

    private func addVisitor() async {
        guard let uid = AuthService.shared.uid else { return }

        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            _ = try await VisitorRepository.shared.addVisitor(
                event: event,
                name: name,
                level: level,
                memo: memo,
                createdBy: uid
            )
            onAdded()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
