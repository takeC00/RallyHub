import SwiftUI

struct EventDetailView: View {
    let membership: CircleMembership
    let eventId: String

    @State private var viewModel: EventDetailViewModel

    init(membership: CircleMembership, eventId: String) {
        self.membership = membership
        self.eventId = eventId
        _viewModel = State(initialValue: EventDetailViewModel(membership: membership, eventId: eventId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.event == nil {
                ProgressView("読み込み中...")
            } else if let event = viewModel.event {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        eventHeader(event)
                        attendanceSection(event)
                        countsSection(event)
                        participantsSection
                        visitorsSection
                    }
                    .padding()
                }
            } else {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "イベントが見つかりません",
                    message: "削除された可能性があります"
                )
            }
        }
        .navigationTitle(viewModel.event?.title ?? "イベント詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canManageVisitors, let event = viewModel.event {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        VisitorAddView(membership: membership, event: event) {
                            Task { await viewModel.load() }
                        }
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }

            if !viewModel.participants.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ParticipantListView(participants: viewModel.participants)
                    } label: {
                        Image(systemName: "person.2")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error).padding()
            }
        }
        .overlay {
            if viewModel.isUpdating {
                LoadingOverlay(message: "更新中...")
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .task {
            viewModel.startListening()
            await viewModel.load()
        }
        .rallyDarkScreenBackground()
        .rallyDarkNavigationBar()
    }

    @ViewBuilder
    private func eventHeader(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title)
                    .font(.title2.bold())
                Spacer()
                if event.isFull {
                    FullBadge()
                }
            }

            Label(event.startAt.formattedEventDateTime(), systemImage: "calendar")
            Label(event.location, systemImage: "mappin.and.ellipse")

            if !event.note.isEmpty {
                Text(event.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func attendanceSection(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("出欠登録")
                .font(.headline)

            if let myStatus = viewModel.myParticipant?.status {
                Text("現在: \(myStatus.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(ParticipantStatus.allCases, id: \.self) { status in
                    Button {
                        Task { await viewModel.updateAttendance(status) }
                    } label: {
                        Text(status.displayName)
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                viewModel.myParticipant?.status == status
                                    ? Color.orange.opacity(0.2)
                                    : RallyScreenStyle.rowBackground,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                    }
                    .disabled(
                        status == .join && !viewModel.canJoin && viewModel.myParticipant?.status != .join
                    )
                    .buttonStyle(.plain)
                }
            }

            if event.isFull && viewModel.myParticipant?.status != .join {
                Text("定員に達しているため、新規参加はできません")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(RallyScreenStyle.rowBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func countsSection(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("集計")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    statCell("参加", value: event.participantCount)
                    statCell("不参加", value: event.absentCount)
                }
                GridRow {
                    statCell("保留", value: event.pendingCount)
                    statCell("今日だけ参加", value: event.visitorCount)
                }
            }

            if event.isCapacityLimited, let capacity = event.capacity {
                Text("募集人数: \(event.totalJoinedCount) / \(capacity) 人")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RallyScreenStyle.rowBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private func statCell(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value) 人")
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("参加者")
                    .font(.headline)
                Spacer()
                NavigationLink("すべて見る") {
                    ParticipantListView(participants: viewModel.participants)
                }
                .font(.subheadline)
            }

            if viewModel.participants.filter({ $0.status == .join }).isEmpty {
                Text("参加者はいません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.participants.filter { $0.status == .join }.prefix(5)) { participant in
                    Text(participant.nickname)
                        .font(.subheadline)
                }
            }
        }
    }

    @ViewBuilder
    private var visitorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日だけ参加")
                .font(.headline)

            if viewModel.visitors.isEmpty {
                Text("今日だけ参加の方はいません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.visitors) { visitor in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(visitor.name)
                            .font(.subheadline.bold())
                        if let level = visitor.level, !level.isEmpty {
                            Text("レベル: \(level)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let memo = visitor.memo, !memo.isEmpty {
                            Text(memo)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct ParticipantListView: View {
    let participants: [EventParticipant]

    var body: some View {
        List {
            ForEach(ParticipantStatus.allCases, id: \.self) { status in
                let group = participants.filter { $0.status == status }
                if !group.isEmpty {
                    Section(status.displayName) {
                        ForEach(group) { participant in
                            Text(participant.nickname)
                        }
                    }
                }
            }
        }
        .navigationTitle("参加者一覧")
        .navigationBarTitleDisplayMode(.inline)
        .rallyDarkFormScreen()
    }
}
