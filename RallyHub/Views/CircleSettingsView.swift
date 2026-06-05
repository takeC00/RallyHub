import SwiftUI

struct CircleSettingsView: View {
    let membership: CircleMembership
    var onDeleted: (() -> Void)? = nil

    @Bindable private var auth = AuthService.shared

    @State private var name: String
    @State private var sportName: String
    @State private var description: String
    @State private var location: String
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var showDeleteConfirm = false

    init(membership: CircleMembership, onDeleted: (() -> Void)? = nil) {
        self.membership = membership
        self.onDeleted = onDeleted
        _name = State(initialValue: membership.circle.name)
        _sportName = State(initialValue: membership.circle.sportName)
        _description = State(initialValue: membership.circle.description)
        _location = State(initialValue: membership.circle.location)
    }

    private var canEdit: Bool {
        membership.membership.role.canEditCircle
    }

    private var canDelete: Bool {
        auth.uid == membership.circle.ownerId
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("招待コード") {
                    HStack {
                        Text(membership.circle.circleCode)
                            .font(.title3.monospaced().bold())
                        Spacer()
                        ShareLink(item: "Rally 招待コード: \(membership.circle.circleCode)") {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }

                Section {
                    NavigationLink {
                        CircleMembersView(membership: membership)
                    } label: {
                        LabeledContent("サークルメンバー", value: "\(membership.circle.memberCount) 人")
                    }
                }

                Section("サークル情報") {
                    if canEdit {
                        TextField("サークル名", text: $name)
                        Picker("競技", selection: $sportName) {
                            ForEach(RallySportOptions.all, id: \.self) { sport in
                                Text(sport).tag(sport)
                            }
                        }
                        TextField("説明", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                        TextField("主な活動場所", text: $location)
                    } else {
                        LabeledContent("名前", value: membership.circle.name)
                        LabeledContent("競技", value: membership.circle.sportName)
                        LabeledContent("説明", value: membership.circle.description.isEmpty ? "—" : membership.circle.description)
                        LabeledContent("場所", value: membership.circle.location.isEmpty ? "—" : membership.circle.location)
                    }

                    LabeledContent("メンバー数", value: "\(membership.circle.memberCount) 人")
                    LabeledContent("自分の権限", value: membership.membership.role.displayName)
                }

                if canEdit {
                    Section {
                        Button("変更を保存") {
                            Task { await save() }
                        }
                        .disabled(isLoading)
                    }
                }

                if canDelete {
                    Section {
                        Button("サークルを削除", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    } footer: {
                        Text("オーナーのみ削除できます。イベント・お知らせ・試合データもすべて削除されます。")
                    }
                }

                if !errorMessage.isEmpty {
                    Section { ErrorBanner(message: errorMessage) }
                }

                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage).foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("サークル設定")
            .overlay {
                if isLoading {
                    LoadingOverlay(message: "処理中...")
                }
            }
            .confirmationDialog(
                "サークルを削除しますか？",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    Task { await deleteCircle() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("「\(membership.circle.name)」と関連データがすべて削除されます。この操作は取り消せません。")
            }
        }
    }

    private func save() async {
        isLoading = true
        errorMessage = ""
        successMessage = ""
        defer { isLoading = false }

        do {
            try await CircleRepository.shared.updateCircle(
                circleId: membership.circle.circleId,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                sportName: sportName,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            successMessage = "保存しました"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteCircle() async {
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            guard let ownerId = auth.uid else {
                throw RallyHubError.invalidInput("ログイン情報が取得できません")
            }
            try await CircleRepository.shared.deleteCircle(
                circleId: membership.circle.circleId,
                ownerId: ownerId
            )
            onDeleted?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
