import SwiftUI

struct WorkoutScreen: View {
    let session: AuthSession
    @State private var editorOpen = false
    @State private var editing: RoutineResponse?
    @State private var routines: [RoutineResponse] = []
    @State private var goal: WeeklyWorkoutGoalResponse?
    @State private var count = 3
    @State private var loading = true
    @State private var saving = false
    @State private var message = ""

    var body: some View {
        List {
            NavigationLink("운동 수행") { WorkoutRecorder(session: session) }
            NavigationLink("날짜별 운동 기록") { WorkoutHistory(session: session) }
            if loading { ProgressView() }
            if !message.isEmpty { Text(message); Button("다시 불러오기") { Task { await load() } } }
            if let goal {
                Section("주간 운동 목표") {
                    if let week = goal.thisWeek { Text("이번 주 목표 \(week.targetCount)회") }
                    if let week = goal.nextWeek { Text("다음 주 목표 \(week.targetCount)회") }
                    Stepper("목표 \(count)회", value: $count, in: 1...7)
                    Button("목표 저장") { Task { await saveGoal() } }
                }.disabled(saving)
            }
            Section("내 루틴") {
                Button("루틴 만들기") { editing = nil; editorOpen = true }
                if routines.isEmpty && !loading && message.isEmpty { Text("등록한 루틴이 없어요") }
                ForEach(routines, id: \.id) { routine in
                    NavigationLink(routine.name) {
                        List {
                            Button("루틴 수정") { editing = routine; editorOpen = true }
                            ForEach(routine.exercises, id: \.routineExerciseId) { exercise in
                                Section("운동 \(exercise.sortOrder) · 휴식 \(exercise.restSeconds)초") {
                                    ForEach(exercise.targets, id: \.setNo) { target in
                                        HStack {
                                            Text("\(target.setNo)세트")
                                            Spacer()
                                            if let kg = target.targetWeightKg { Text("\(kg.formatted()) kg") }
                                            if let reps = target.targetReps { Text("\(reps)회") }
                                            if let seconds = target.targetDurationSeconds { Text("\(seconds)초") }
                                        }
                                    }
                                }
                            }
                        }.navigationTitle(routine.name)
                    }
                }
            }
        }.navigationTitle("운동").task { await load() }
        .sheet(isPresented: $editorOpen, onDismiss: { Task { await load() } }) {
            RoutineEditor(session: session, routine: editing) { editorOpen = false }
        }
    }

    @MainActor private func load() async {
        loading = true
        defer { loading = false }
        message = ""
        do {
            let data = try await session.protectedRequest("api/v1/routines", method: "GET")
            let response = try JSONDecoder().decode(ApiResponseRoutineListResponse.self, from: data)
            guard response.success == true, let list = response.data else { throw URLError(.badServerResponse) }
            routines = list.items
        } catch { message = "루틴을 불러오지 못했어요" }
        do {
            let data = try await session.protectedRequest("api/v1/weekly-workout-goal/me", method: "GET")
            try applyGoal(data)
        } catch { message += (message.isEmpty ? "" : "\n") + "주간 목표를 불러오지 못했어요" }
    }

    private func applyGoal(_ data: Data) throws {
        let response = try JSONDecoder().decode(ApiResponseWeeklyWorkoutGoalResponse.self, from: data)
        guard response.success == true, let updated = response.data else { throw URLError(.badServerResponse) }
        goal = updated
        count = updated.nextWeek?.targetCount ?? updated.thisWeek?.targetCount ?? 3
    }

    @MainActor private func saveGoal() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        do {
            let data = try await session.protectedRequest("api/v1/weekly-workout-goal/me", method: "PUT",
                body: JSONEncoder().encode(WeeklyWorkoutGoalPutRequest(targetCount: count)))
            try applyGoal(data)
        } catch { message = "주간 운동 목표를 저장하지 못했어요" }
    }
}

private struct WorkoutHistory: View {
    let session: AuthSession
    @State private var date = Date()
    @State private var records: [WorkoutRecordSummaryResponse]?
    @State private var failed = false

    private var key: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var body: some View {
        List {
            DatePicker("운동 날짜", selection: $date, displayedComponents: .date)
                .environment(\.timeZone, TimeZone(identifier: "Asia/Seoul")!)
            if failed { Button("운동 기록 다시 불러오기") { Task { await load(key) } } }
            else if let records {
                if records.isEmpty { Text("이날 기록한 운동이 없어요") }
                ForEach(records, id: \.id) { record in
                    NavigationLink(record.routineName ?? "자유 운동") {
                        WorkoutDetail(session: session, id: record.id)
                    }
                }
            } else { ProgressView() }
        }.navigationTitle("운동 기록").task(id: key) { await load(key) }
    }

    @MainActor private func load(_ day: String) async {
        records = nil
        failed = false
        do {
            let data = try await session.protectedRequest("api/v1/workout-sessions", method: "GET",
                query: ["from", "to"].map { URLQueryItem(name: $0, value: day) })
            let response = try JSONDecoder().decode(ApiResponseWorkoutRecordListResponse.self, from: data)
            guard response.success == true, let list = response.data else { throw URLError(.badServerResponse) }
            if key == day && !Task.isCancelled { records = list.items }
        } catch { if key == day && !Task.isCancelled { failed = true } }
    }
}

private struct WorkoutDetail: View {
    let session: AuthSession
    let id: Int
    @State private var detail: WorkoutRecordDetailResponse?
    @State private var failed = false

    var body: some View {
        List {
            if let detail {
                LabeledContent("총 운동량", value: "\(detail.totalVolumeKg) kg")
                ForEach(detail.performedExercises, id: \.sortOrder) { exercise in
                    Section(exercise.exerciseName) {
                        if exercise.skipped { Text("건너뛴 운동") }
                        ForEach(exercise.sets, id: \.setNo) { set in
                            HStack {
                                Text("\(set.setNo)세트")
                                Spacer()
                                if let kg = set.actual?.weightKg { Text("\(kg.formatted()) kg") }
                                if let reps = set.actual?.reps { Text("\(reps)회") }
                                if let seconds = set.actual?.durationSeconds { Text("\(seconds)초") }
                            }
                        }
                    }
                }
            } else if failed { Button("운동 상세 다시 불러오기") { Task { await load() } } }
            else { ProgressView() }
        }.navigationTitle(detail?.routineName ?? "운동 상세").task { await load() }
    }

    @MainActor private func load() async {
        failed = false
        do {
            let data = try await session.protectedRequest("api/v1/workout-sessions/\(id)", method: "GET")
            let response = try JSONDecoder().decode(ApiResponseWorkoutRecordDetailResponse.self, from: data)
            guard response.success == true, let record = response.data, record.id == id else { throw URLError(.badServerResponse) }
            detail = record
        } catch { failed = true }
    }
}
