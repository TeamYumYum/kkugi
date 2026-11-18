import SwiftUI

struct ExerciseRecords: View {
    let session: AuthSession
    @State private var selected: ExerciseResponse?
    @State private var choosing = false
    @State private var records: [PersonalRecordResponse] = []
    @State private var recent: [WorkoutRecentSetResponse] = []
    @State private var loading = false
    @State private var failed = false

    var body: some View {
        List {
            Button(selected?.nameKo ?? "종목 선택") { choosing = true }
            if let selected {
                if loading { ProgressView() }
                else if failed { Button("기록 다시 불러오기") { Task { await load(selected) } } }
                else {
                    if selected.recordType == "WEIGHT_REPS" {
                        Section("횟수별 최고 중량") {
                            if records.isEmpty { Text("아직 중량 기록이 없어요") }
                            ForEach(records, id: \.reps) { row in
                                NavigationLink {
                                    WorkoutDetail(session: session, id: row.sessionId)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text("\(row.reps)회 · \(row.weightKg.formatted()) kg")
                                        Text(row.kind == "BASELINE" ? "첫 기록" : "최고 기록").foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    Section("최근 세트") {
                        if recent.isEmpty { Text("아직 수행한 세트가 없어요") }
                        ForEach(recent, id: \.sessionId) { row in
                            NavigationLink {
                                WorkoutDetail(session: session, id: row.sessionId)
                            } label: {
                                Text("\(row.startedAt.prefix(10)) · \(row.exercise.sets.count)세트")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("종목별 기록")
        .sheet(isPresented: $choosing) {
            ExerciseCatalog(session: session) { row in selected = row; choosing = false }
        }
        .task(id: selected?.id) { if let selected { await load(selected) } }
    }

    @MainActor private func load(_ exercise: ExerciseResponse) async {
        loading = true
        failed = false
        defer { if selected?.id == exercise.id && !Task.isCancelled { loading = false } }
        do {
            let id = String(exercise.id)
            let bytes = try await session.protectedRequest("api/v1/workout-sessions/recent-sets", method: "GET",
                query: [URLQueryItem(name: "exerciseIds", value: id)])
            let history = try JSONDecoder().decode(ApiResponseWorkoutRecentSetListResponse.self, from: bytes)
            guard history.success == true, let items = history.data?.items else { throw URLError(.badServerResponse) }
            var best: [PersonalRecordResponse] = []
            if exercise.recordType == "WEIGHT_REPS" {
                let data = try await session.protectedRequest("api/v1/personal-records", method: "GET",
                    query: [URLQueryItem(name: "exerciseId", value: id)])
                let result = try JSONDecoder().decode(ApiResponsePersonalRecordListResponse.self, from: data)
                guard result.success == true, let value = result.data, value.exerciseId == exercise.id else {
                    throw URLError(.badServerResponse)
                }
                best = value.records.sorted { $0.reps < $1.reps }
            }
            guard !Task.isCancelled, selected?.id == exercise.id else { return }
            recent = items.filter { $0.exercise.exerciseId == exercise.id }
            records = best
        } catch { if !Task.isCancelled && selected?.id == exercise.id { failed = true } }
    }
}
