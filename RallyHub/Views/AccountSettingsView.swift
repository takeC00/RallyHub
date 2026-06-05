import SwiftUI

struct AccountSettingsView: View {
    @Bindable private var auth = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    var showsDismissButton = false

    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var didSave = false
    @State private var showLogoutConfirm = false

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

            Section {
                Button("ログアウト", role: .destructive) {
                    showLogoutConfirm = true
                }
            }

            Section {
                NavigationLink {
                    DeleteAccountView()
                } label: {
                    Text("アカウントを削除")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("アカウントを削除すると、Firebase Auth と Firestore 上の自分のデータが削除されます。この操作は元に戻せません。")
            }
        }
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
        .rallyDarkFormScreen()
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onAppear {
            name = auth.name
        }
        .confirmationDialog(
            "ログアウトしますか？",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("ログアウト", role: .destructive) {
                try? auth.logout()
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("現在のアカウントからログアウトします。")
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

struct AccountToolbarMenu: View {
    @Bindable private var auth = AuthService.shared
    @Binding var showAccountSettings: Bool

    var body: some View {
        Menu {
            if !auth.name.isEmpty {
                Text(auth.name)
            }
            if let email = auth.currentUser?.email {
                Text(email)
                    .font(.caption)
            }

            Button {
                showAccountSettings = true
            } label: {
                Label("アカウント", systemImage: "person.crop.circle")
            }
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("アカウント")
    }
}
