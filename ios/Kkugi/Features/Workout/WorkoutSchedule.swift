import SwiftUI

struct WorkoutSchedule: View {
    let session: AuthSession
    let routines: [RoutineResponse]
    @State private var date = Date()
    @State private var destination = Date()
    @State private var items: [WorkoutScheduleResponse] = []
    @State private var moving: Int?
    @State private var deleting: Int?
    @State private var confirming = false
    @State private var loading = true
    @State private var busy = false
    @State private var errorMessage = ""

    private var day: String { WorkoutDay.key(date) }

    var body: some View {
        List {
            DatePicker("예정일", selection: $date, displayedComponents: .date)
            if day >= WorkoutDay.key(Date()) && !routines.isEmpty {
                Menu("루틴 예약") {
                    ForEach(routines, id: \.id) { routine in
                        Button(routine.name) { Task { await create(routine.id) } }
                    }
                }
            }
            if !errorMessage.isEmpty { Text(errorMessage); Button("다시 조회") { Task { await load(day) } } }
            if loading { ProgressView() }
            else if items.isEmpty && errorMessage.isEmpty { Text("이날 예정된 운동이 없어요") }
            ForEach(items, id: \.id) { item in
                Section(routines.first(where: { $0.id == item.routineId })?.name ?? "운동 일정") {
                    if let record = item.completedSessionId {
                        NavigationLink("완료한 운동 보기") { WorkoutDetail(session: session, id: record) }
                    } else {
                        Button("다른 날로 이동") { destination = max(date, Date()); moving = item.id }
                        Button("일정 삭제", role: .destructive) { deleting = item.id; confirming = true }
                    }
                }
            }
            if let moving {
                Section("변경할 날짜") {
                    DatePicker("새 예정일", selection: $destination, in: Calendar.koreanLocal.startOfDay(for: Date())..., displayedComponents: .date)
                    Button("이동") { Task { await move(moving) } }
                    Button("취소") { self.moving = nil }
                }
            }
        }
        .environment(\.timeZone, Calendar.koreanLocal.timeZone)
        .disabled(busy)
        .gListCanvas().navigationTitle("운동 일정")
        .task(id: day) { moving = nil; await load(day) }
        .alert("운동 일정을 삭제할까요?", isPresented: $confirming) {
            Button("취소", role: .cancel) { deleting = nil }
            Button("삭제", role: .destructive) {
                if let deleting { Task { await remove(deleting) } }
            }
        }
    }

    @MainActor private func load(_ key: String) async {
        loading = true
        errorMessage = ""
        items = []
        defer { if key == day && !Task.isCancelled { loading = false } }
        do {
            let bytes = try await session.protectedRequest("api/v1/workout-schedules", method: "GET",
                query: ["from", "to"].map { URLQueryItem(name: $0, value: key) })
            let response = try JSONDecoder().decode(ApiResponseWorkoutScheduleListResponse.self, from: bytes)
            guard response.success == true, let result = response.data else { throw URLError(.badServerResponse) }
            if key == day && !Task.isCancelled { items = result.items }
        } catch { if key == day && !Task.isCancelled { errorMessage = "운동 일정을 불러오지 못했어요" } }
    }

    @MainActor private func create(_ routine: Int) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let body = WorkoutScheduleCreateRequest(routineId: routine, scheduledDate: day)
            _ = try await session.protectedRequest("api/v1/workout-schedules", method: "POST", body: JSONEncoder().encode(body))
            await load(day)
        } catch {
            await load(day)
            errorMessage = "예약 결과를 확인해 주세요. 다시 예약하기 전에 목록을 확인해 주세요"
        }
    }

    @MainActor private func move(_ id: Int) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let body = WorkoutScheduleMoveRequest(scheduledDate: WorkoutDay.key(destination))
            _ = try await session.protectedRequest("api/v1/workout-schedules/\(id)", method: "PATCH", body: JSONEncoder().encode(body))
            moving = nil
            if day == WorkoutDay.key(destination) { await load(day) } else { date = destination }
        } catch { errorMessage = "일정을 옮기지 못했어요" }
    }

    @MainActor private func remove(_ id: Int) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await session.protectedRequest("api/v1/workout-schedules/\(id)", method: "DELETE")
            deleting = nil
            await load(day)
        } catch { errorMessage = "일정을 삭제하지 못했어요" }
    }
}

private extension Calendar {
    static var koreanLocal: Self {
        var result = Self(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return result
    }
}

private enum WorkoutDay {
    static func key(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
