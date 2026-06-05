import SwiftUI

struct EventFormFields: View {
    @Binding var title: String
    @Binding var eventDate: Date
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var location: String
    @Binding var capacityText: String
    @Binding var isCapacityLimited: Bool
    @Binding var note: String

    var body: some View {
        Section("イベント情報") {
            TextField("タイトル", text: $title)
            DatePicker("開催日", selection: $eventDate, displayedComponents: .date)
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
    }

    func buildDraft(calendar: Calendar = .current) throws -> EventRepository.EventDraft {
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

        let startAt = RecurringEventPlanner.combine(date: eventDate, time: startTime, calendar: calendar)
        let endAt = RecurringEventPlanner.combine(date: eventDate, time: endTime, calendar: calendar)

        guard endAt > startAt else {
            throw RallyHubError.invalidInput("終了時間は開始時間より後にしてください")
        }

        return EventRepository.EventDraft(
            title: trimmedTitle,
            startAt: startAt,
            endAt: endAt,
            location: trimmedLocation,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            capacity: capacity,
            isCapacityLimited: isCapacityLimited
        )
    }
}

struct EventCreateView: View {
    @Environment(\.dismiss) private var dismiss

    let membership: CircleMembership
    let onCreated: () -> Void

    @State private var title = ""
    @State private var eventDate = Date()
    @State private var startTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var location = ""
    @State private var capacityText = "20"
    @State private var isCapacityLimited = true
    @State private var note = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            EventFormFields(
                title: $title,
                eventDate: $eventDate,
                startTime: $startTime,
                endTime: $endTime,
                location: $location,
                capacityText: $capacityText,
                isCapacityLimited: $isCapacityLimited,
                note: $note
            )

            if !errorMessage.isEmpty {
                Section { ErrorBanner(message: errorMessage) }
            }
        }
        .navigationTitle("イベント作成")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isLoading ? "作成中..." : "作成") {
                    Task { await create() }
                }
                .disabled(isLoading)
            }
        }
        .onAppear {
            if location.isEmpty {
                location = membership.circle.location
            }
        }
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
            let draft = try EventFormFields(
                title: $title,
                eventDate: $eventDate,
                startTime: $startTime,
                endTime: $endTime,
                location: $location,
                capacityText: $capacityText,
                isCapacityLimited: $isCapacityLimited,
                note: $note
            ).buildDraft()

            _ = try await EventRepository.shared.createEvent(
                circleId: membership.circle.circleId,
                draft: draft,
                createdBy: uid
            )
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
