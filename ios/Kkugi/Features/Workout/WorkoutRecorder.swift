import SwiftUI

struct WorkoutRecorder: View {
    let session: AuthSession
    @State private var owner: Int64?
    @State private var journal = WorkoutJournal()
    @State private var selected: ExerciseResponse?
    @State private var selectedRow: UUID?
    @State private var values = SetDraft()
    @State private var catalog = false
    @State private var busy = false
    @State private var message = ""
    @Environment(\.scenePhase) private var phase
    private let store = WorkoutJournalStore.shared

    var body: some View {
        List {
            if let active = journal.active {
                Section("진행 중인 운동") {
                    Text(active.startedAt, style: .time)
                    ForEach(active.exercises) { row in
                        Button("\(row.catalog.nameKo) · \(row.sets.count)세트") {
                            selected = row.catalog
                            selectedRow = row.id
                            if let last = row.sets.last?.actual {
                                values = SetDraft(kg: String(last.weightKg ?? 0), reps: String(last.reps ?? 10),
                                                  seconds: String(last.durationSeconds ?? 30))
                            }
                        }
                    }
                    Button("종목 선택") { catalog = true }
                }
                if let selected {
                    Section(selected.nameKo) {
                        if selected.recordType == "WEIGHT_REPS" {
                            TextField("중량 (kg)", text: $values.kg).keyboardType(.decimalPad)
                        }
                        if selected.recordType == "DURATION" {
                            TextField("시간 (초)", text: $values.seconds).keyboardType(.numberPad)
                        } else {
                            TextField("횟수", text: $values.reps).keyboardType(.numberPad)
                        }
                        Button("세트 완료") { Task { await record(selected, id: active.id) } }
                    }
                }
                Button("운동 종료 및 저장") {
                    Task {
                        await change { try await store.finish(member: $0, id: active.id) }
                        if journal.active == nil {
                            selected = nil
                            selectedRow = nil
                            await sync()
                        }
                    }
                }.disabled(active.exercises.isEmpty)
            } else {
                Button("자유 운동 시작") { Task { await change { try await store.start($0) } } }.disabled(owner == nil)
            }
            if !journal.queue.isEmpty {
                Section("전송 대기 기록") {
                    ForEach(journal.queue, id: \.request.clientUuid) { item in
                        VStack(alignment: .leading) {
                            Text(item.request.startedAt)
                            if let code = item.rejection { Text("서버에서 거절한 기록 (\(code))") }
                            else { Text("기기에 저장됨") }
                        }
                    }
                    if journal.queue.contains(where: { $0.rejection == nil }) {
                        Button("지금 전송") { Task { await sync() } }
                    }
                }
            }
            if !message.isEmpty { Text(message) }
        }
        .navigationTitle("운동 수행")
        .disabled(busy)
        .task { await restore() }
        .onChange(of: phase) { _, phase in if phase == .active { Task { await restore() } } }
        .sheet(isPresented: $catalog) {
            ExerciseCatalog(session: session) { item in
                selected = item
                selectedRow = nil
                values = SetDraft()
                catalog = false
            }
        }
    }

    @MainActor private func restore() async {
        do {
            guard let current = try await session.current() else { throw URLError(.userAuthenticationRequired) }
            owner = current.memberID
            journal = try await store.read(current.memberID)
            if !journal.queue.isEmpty { await sync() }
        } catch { message = "기기에 저장된 운동 기록을 열지 못했어요" }
    }

    @MainActor private func change(_ work: (Int64) async throws -> Void) async {
        guard !busy, let owner else { return }
        busy = true
        defer { busy = false }
        do {
            guard try await session.current()?.memberID == owner else { throw CancellationError() }
            try await work(owner)
            journal = try await store.read(owner)
            message = ""
        } catch { message = "운동 기록을 저장하지 못했어요" }
    }

    @MainActor private func record(_ exercise: ExerciseResponse, id: UUID) async {
        guard let target = try? values.target(type: exercise.recordType) else {
            message = "중량·횟수·시간을 확인해 주세요"
            return
        }
        let actual = WorkoutSessionValuesRequest(weightKg: target.targetWeightKg, reps: target.targetReps,
                                                 durationSeconds: target.targetDurationSeconds)
        await change {
            try await store.record(member: $0, activeID: id, exercise: exercise, rowID: selectedRow, values: actual)
        }
        if selectedRow == nil { selectedRow = journal.active?.exercises.last(where: { $0.catalog.id == exercise.id })?.id }
    }

    @MainActor private func sync() async {
        guard !busy, let owner else { return }
        busy = true
        defer { busy = false }
        do {
            try await store.flush(member: owner, session: session)
            journal = try await store.read(owner)
            message = journal.queue.isEmpty ? "운동 기록을 전송했어요" : "전송 대기 기록을 확인해 주세요"
        } catch { message = "기기에 기록을 보관했어요. 연결 후 다시 전송해 주세요" }
    }
}
