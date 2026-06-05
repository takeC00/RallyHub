import SwiftUI

struct RecurringEventCreateView: View {
    @Environment(\.dismiss) private var dismiss

    let membership: CircleMembership
    let onCreated: () -> Void

    @State private var title = ""
    @State private var rangeStart = Date()
    @State private var rangeEnd = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var weekday = Calendar.current.component(.weekday, from: Date())
    @State private var startTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var location = ""
    @State private var capacityText = "20"
    @State private var isCapacityLimited = true
    @State private var note = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var previewCount = 0

    private let weekdaySymbols = Calendar.current.weekdaySymbols

    var body: some View {
        Form {
            Section("イベント情報") {
                TextField("タイトル", text: $title)
                DatePicker("開始日", selection: $rangeStart, displayedComponents: .date)
                DatePicker("終了日", selection: $rangeEnd, displayedComponents: .date)

                Picker("曜日", selection: $weekday) {
                    ForEach(1...7, id: \.self) { index in
                        Text(weekdaySymbols[index - 1]).tag(index)
                    }
                }

                DatePicker("開始時間", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("終了時間", selection: $endTime, displayedComponents: .hourAndMinute)
                TextField("場所", text: $location)
            }

            Section("定員") {
                Toggle("人数制限あり", isOn: $isCapacityLimited)
                if isCapacityLimited {
                    TextField("募集人数", text: $capacityText)
                        .keyboardType(.numberPad)
                }
            }

            Section("備考") {
                TextField("備考", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Text("\(previewCount) 件のイベントを作成します")
                    .foregroundStyle(.secondary)
            }

            if !errorMessage.isEmpty {
                Section { ErrorBanner(message: errorMessage) }
            }
        }
        .navigationTitle("定期イベント作成")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isLoading ? "作成中..." : "一括作成") {
                    Task { await create() }
                }
                .disabled(isLoading || previewCount == 0)
            }
        }
        .onAppear {
            if location.isEmpty {
                location = membership.circle.location
            }
            updatePreviewCount()
        }
        .onChange(of: rangeStart) { _, _ in updatePreviewCount() }
        .onChange(of: rangeEnd) { _, _ in updatePreviewCount() }
        .onChange(of: weekday) { _, _ in updatePreviewCount() }
        .overlay {
            if isLoading {
                LoadingOverlay(message: "作成中...")
            }
        }
    }

    private func updatePreviewCount() {
        previewCount = RecurringEventPlanner.dates(
            from: rangeStart,
            to: rangeEnd,
            weekday: weekday
        ).count
    }

    private func create() async {
        guard let uid = AuthService.shared.uid else { return }

        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else {
                throw RallyHubError.invalidInput("タイトルを入力してください")
            }

            let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLocation.isEmpty else {
                throw RallyHubError.invalidInput("場所を入力してください")
            }

            var capacity: Int?
            if isCapacityLimited {
                guard let value = Int(capacityText.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else {
                    throw RallyHubError.invalidInput("募集人数を正しく入力してください")
                }
                capacity = value
            }

            let dates = RecurringEventPlanner.dates(from: rangeStart, to: rangeEnd, weekday: weekday)
            guard !dates.isEmpty else {
                throw RallyHubError.invalidInput("作成対象の日付がありません")
            }

            let draft = EventRepository.EventDraft(
                title: trimmedTitle,
                startAt: Date(),
                endAt: Date(),
                location: trimmedLocation,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                capacity: capacity,
                isCapacityLimited: isCapacityLimited
            )

            _ = try await EventRepository.shared.createRecurringEvents(
                circleId: membership.circle.circleId,
                draft: draft,
                dates: dates,
                startTime: startTime,
                endTime: endTime,
                createdBy: uid
            )

            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
