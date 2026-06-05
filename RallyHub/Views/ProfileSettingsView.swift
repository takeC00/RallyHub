import SwiftUI

struct ProfileSettingsView: View {
    @Bindable private var auth = AuthService.shared

    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var didSave = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        Form {
            Section {
                TextField("表示名", text: $name)
                    .textInputAutocapitalization(.words)

                if let email = auth.currentUser?.email {
                    LabeledContent("メール", value: email)
                }
            } header: {
                Text("プロフィール")
            } footer: {
                Text("表示名はサークルメンバー一覧などに表示されます。RallyMate・RallyMatch と共通です。")
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if didSave {
                Section {
                    Text("保存しました")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!canSave)
            }
        }
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = auth.name
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = ""
        didSave = false
        defer { isSaving = false }

        do {
            try await auth.updateDisplayName(name)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
