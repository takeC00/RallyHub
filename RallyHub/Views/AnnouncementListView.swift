import SwiftUI

struct AnnouncementListView: View {
    let membership: CircleMembership

    @State private var viewModel: AnnouncementViewModel

    init(membership: CircleMembership) {
        self.membership = membership
        _viewModel = State(initialValue: AnnouncementViewModel(membership: membership))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.announcements.isEmpty {
                    ProgressView("読み込み中...")
                } else if viewModel.announcements.isEmpty {
                    EmptyStateView(
                        icon: "megaphone",
                        title: "お知らせがありません",
                        message: viewModel.canPost
                            ? "お知らせを投稿してください"
                            : "投稿をお待ちください"
                    )
                } else {
                    List(viewModel.announcements) { announcement in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(announcement.title)
                                .font(.headline)
                            Text(announcement.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(announcement.createdAt.formattedEventDateTime())
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("お知らせ")
            .toolbar {
                if viewModel.canPost {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            AnnouncementCreateView(membership: membership) {
                                Task { await viewModel.load() }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.load()
            }
            .task {
                await viewModel.load()
            }
            .safeAreaInset(edge: .bottom) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error).padding()
                }
            }
            .rallyDarkScreenBackground()
            .rallyDarkNavigationBar()
        }
    }
}

struct AnnouncementCreateView: View {
    @Environment(\.dismiss) private var dismiss

    let membership: CircleMembership
    let onCreated: () -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    private var isEnabled: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isLoading
    }

    var body: some View {
        Form {
            Section {
                TextField("タイトル", text: $title)
                TextField("本文", text: $bodyText, axis: .vertical)
                    .lineLimit(5...12)
            }

            if !errorMessage.isEmpty {
                Section { ErrorBanner(message: errorMessage) }
            }
        }
        .navigationTitle("お知らせ投稿")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isLoading ? "投稿中..." : "投稿") {
                    Task { await create() }
                }
                .disabled(!isEnabled)
            }
        }
        .overlay {
            if isLoading {
                LoadingOverlay(message: "投稿中...")
            }
        }
        .rallyDarkFormScreen()
    }

    private func create() async {
        guard let uid = AuthService.shared.uid else { return }

        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            _ = try await AnnouncementRepository.shared.createAnnouncement(
                circleId: membership.circle.circleId,
                title: title,
                body: bodyText,
                createdBy: uid
            )
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
