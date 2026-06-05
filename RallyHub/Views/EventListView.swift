import SwiftUI

struct EventListView: View {
    let membership: CircleMembership

    @State private var viewModel: EventListViewModel

    init(membership: CircleMembership) {
        self.membership = membership
        _viewModel = State(initialValue: EventListViewModel(membership: membership))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("フィルター", selection: $viewModel.filter) {
                    ForEach(EventListFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Group {
                    if viewModel.isLoading && viewModel.events.isEmpty {
                        ProgressView("読み込み中...")
                            .frame(maxHeight: .infinity)
                    } else if viewModel.filteredEvents.isEmpty {
                        VStack(spacing: 20) {
                            EmptyStateView(
                                icon: "calendar",
                                title: "イベントがありません",
                                message: viewModel.filter == .upcoming
                                    ? "イベントを作成してください"
                                    : "過去のイベントはありません"
                            )

                            if viewModel.filter == .upcoming && viewModel.canManageEvents {
                                NavigationLink {
                                    EventCreateView(membership: membership) {
                                        Task { await viewModel.load() }
                                    }
                                } label: {
                                    Label("イベントを作成", systemImage: "plus.circle.fill")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .padding(.horizontal, 32)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        List(viewModel.filteredEvents) { event in
                            NavigationLink {
                                EventDetailView(
                                    membership: membership,
                                    eventId: event.eventId
                                )
                            } label: {
                                EventRowView(event: event)
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle(membership.circle.name)
            .toolbar {
                if viewModel.canManageEvents {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        NavigationLink {
                            RecurringEventCreateView(membership: membership) {
                                Task { await viewModel.load() }
                            }
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                        }

                        NavigationLink {
                            EventCreateView(membership: membership) {
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
        }
    }
}

struct EventRowView: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.title)
                    .font(.headline)
                Spacer()
                if event.isFull {
                    FullBadge()
                }
            }

            Text(event.startAt.formattedEventDateTime())
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Label(event.location, systemImage: "mappin")
                Spacer()
                Text(event.capacityDisplay)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
