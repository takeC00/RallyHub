import SwiftUI

struct CircleListView: View {
    @Bindable private var auth = AuthService.shared
    @State private var viewModel = CircleListViewModel()
    @State private var showAccountSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.memberships.isEmpty {
                    ProgressView("読み込み中...")
                } else if viewModel.memberships.isEmpty {
                    EmptyStateView(
                        icon: "person.3",
                        title: "サークルがありません",
                        message: "サークルを作成するか、招待コードで参加してください"
                    )
                } else {
                    List(viewModel.memberships) { item in
                        NavigationLink {
                            CircleHomeView(membership: item) {
                                Task { await viewModel.load() }
                            }
                        } label: {
                            CircleRowView(membership: item)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("サークル")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AccountToolbarMenu(showAccountSettings: $showAccountSettings)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        CircleJoinView(onJoined: {
                            Task { await viewModel.load() }
                        })
                    } label: {
                        Image(systemName: "ticket")
                    }

                    NavigationLink {
                        CircleCreateView(onCreated: {
                            Task { await viewModel.load() }
                        })
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if viewModel.isLoading && !viewModel.memberships.isEmpty {
                    LoadingOverlay(message: "更新中...")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                        .padding()
                }
            }
            .refreshable {
                await viewModel.load()
            }
            .task {
                await viewModel.load()
            }
            .navigationDestination(isPresented: $showAccountSettings) {
                AccountSettingsView()
            }
            .rallyDarkScreenBackground()
            .rallyDarkNavigationBar()
        }
    }
}

struct CircleRowView: View {
    let membership: CircleMembership

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(membership.circle.name)
                    .font(.headline)
                Spacer()
                RoleBadge(role: membership.membership.role)
            }

            Label(membership.circle.sportName, systemImage: "sportscourt")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !membership.circle.location.isEmpty {
                Label(membership.circle.location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("\(membership.circle.memberCount) 人")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct CircleHomeView: View {
    let membership: CircleMembership
    var onCircleDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            EventListView(membership: membership)
                .tabItem {
                    Label("イベント", systemImage: "calendar")
                }

            AnnouncementListView(membership: membership)
                .tabItem {
                    Label("お知らせ", systemImage: "megaphone")
                }

            CircleSettingsView(membership: membership, onDeleted: {
                onCircleDeleted()
                dismiss()
            })
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
    }
}
