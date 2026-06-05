import SwiftUI

struct CircleMembersView: View {
    let membership: CircleMembership

    @Bindable private var auth = AuthService.shared
    @State private var members: [CircleMember] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showAddManual = false

    private var canManage: Bool {
        membership.membership.role.canManageManualMembers
    }

    private var registeredMembers: [CircleMember] {
        members.filter(\.isRegistered)
    }

    private var manualMembers: [CircleMember] {
        members.filter(\.isManual)
    }

    var body: some View {
        List {
            if !registeredMembers.isEmpty {
                Section("アカウントメンバー") {
                    ForEach(registeredMembers) { member in
                        memberRow(member, subtitle: roleLabel(member.role))
                    }
                } footer: {
                    Text("招待コードで参加した正式メンバーです。")
                }
            }

            if !manualMembers.isEmpty {
                Section("手動登録メンバー") {
                    ForEach(manualMembers) { member in
                        NavigationLink {
                            ManualMemberEditView(member: member) {
                                Task { await reload() }
                            }
                        } label: {
                            memberRow(member, subtitle: "手動登録")
                        }
                    }
                } footer: {
                    Text("アプリ未登録の常連メンバーです。出欠・レーティングの永続管理対象です。")
                }
            }

            if members.isEmpty && !isLoading {
                ContentUnavailableView(
                    "メンバーがいません",
                    systemImage: "person.3",
                    description: Text("招待コードで参加するか、手動登録メンバーを追加してください")
                )
            }
        }
        .navigationTitle("サークルメンバー")
        .toolbar {
            if canManage {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddManual = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("メンバーを追加")
                }
            }
        }
        .sheet(isPresented: $showAddManual) {
            if let uid = auth.uid {
                ManualMemberAddView(
                    circleId: membership.circle.circleId,
                    createdBy: uid
                ) {
                    Task { await reload() }
                }
            }
        }
        .overlay {
            if isLoading { LoadingOverlay(message: "読み込み中...") }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .alert("エラー", isPresented: .constant(!errorMessage.isEmpty)) {
            Button("OK") { errorMessage = "" }
        } message: {
            Text(errorMessage)
        }
    }

    private func memberRow(_ member: CircleMember, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(member.userName)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(member.rating)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func roleLabel(_ role: CircleRole) -> String {
        role.displayName
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }

        do {
            members = try await CircleRepository.shared.fetchCircleMembers(
                circleId: membership.circle.circleId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ManualMemberAddView: View {
    let circleId: String
    let createdBy: String
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var rating = "1500"
    @State private var level = "experienced"
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("表示名", text: $displayName)
                    TextField("初期レート", text: $rating)
                        .keyboardType(.numberPad)
                    Picker("レベル", selection: $level) {
                        Text("経験者").tag("experienced")
                        Text("初心者").tag("beginner")
                    }
                    TextField("備考（任意）", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("手動登録メンバー")
                } footer: {
                    Text("Android ユーザーなど、アプリアカウントを持たない常連を永続登録します。")
                }

                if !errorMessage.isEmpty {
                    Section { ErrorBanner(message: errorMessage) }
                }
            }
            .navigationTitle("メンバーとして追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving { LoadingOverlay(message: "保存中...") }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = ""
        defer { isSaving = false }

        do {
            _ = try await CircleRepository.shared.createManualMember(
                circleId: circleId,
                displayName: displayName,
                rating: Int(rating) ?? RatingDefaults.initialRating,
                level: level,
                notes: notes.isEmpty ? nil : notes,
                createdBy: createdBy
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ManualMemberEditView: View {
    let member: CircleMember
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var rating: String
    @State private var level: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirm = false

    init(member: CircleMember, onSaved: @escaping () -> Void) {
        self.member = member
        self.onSaved = onSaved
        _displayName = State(initialValue: member.userName)
        _rating = State(initialValue: "\(member.rating)")
        _level = State(initialValue: member.level ?? "experienced")
        _notes = State(initialValue: member.notes ?? "")
    }

    var body: some View {
        Form {
            Section {
                TextField("表示名", text: $displayName)
                TextField("レート", text: $rating)
                    .keyboardType(.numberPad)
                Picker("レベル", selection: $level) {
                    Text("経験者").tag("experienced")
                    Text("初心者").tag("beginner")
                }
                TextField("備考（任意）", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                Button("メンバーを削除", role: .destructive) {
                    showDeleteConfirm = true
                }
            }

            if !errorMessage.isEmpty {
                Section { ErrorBanner(message: errorMessage) }
            }
        }
        .navigationTitle("手動登録編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task { await save() }
                }
                .disabled(isSaving)
            }
        }
        .confirmationDialog("メンバーを削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) {
                Task { await deactivate() }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = ""
        defer { isSaving = false }

        do {
            try await CircleRepository.shared.updateManualMember(
                member,
                displayName: displayName,
                rating: Int(rating) ?? member.rating,
                level: level,
                notes: notes.isEmpty ? nil : notes
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deactivate() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await CircleRepository.shared.deactivateManualMember(member)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
