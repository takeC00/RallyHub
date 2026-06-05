import SwiftUI

struct CircleCreateView: View {
    @Environment(\.dismiss) private var dismiss

    let onCreated: () -> Void

    @State private var name = ""
    @State private var sportName = RallySportOptions.defaultSport
    @State private var description = ""
    @State private var location = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    private var isEnabled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        RallyCircleCreateFormView(
            name: $name,
            sportName: $sportName,
            description: $description,
            location: $location,
            errorMessage: $errorMessage,
            isLoading: isLoading,
            isEnabled: isEnabled,
            onSubmit: { Task { await create() } }
        )
        .overlay {
            if isLoading {
                LoadingOverlay(message: "作成中...")
            }
        }
    }

    private func create() async {
        guard let uid = AuthService.shared.uid else { return }

        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            _ = try await CircleRepository.shared.createCircle(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                sportName: sportName,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                ownerId: uid,
                ownerName: AuthService.shared.name
            )
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
