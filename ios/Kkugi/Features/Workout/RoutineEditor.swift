import SwiftUI

struct SetDraft: Identifiable {
    let id = UUID()
    var kg = "0"
    var reps = "10"
    var seconds = "30"

    func target(type: String) throws -> RoutineTargetRequest {
        let weight = Double(kg), repetitions = Int(reps), duration = Int(seconds)
        switch type {
        case "WEIGHT_REPS":
            guard let weight, (0...1000).contains(weight),
                  let decimal = Decimal(string: kg, locale: Locale(identifier: "en_US_POSIX")),
                  decimal.exponent >= -2, let repetitions, (1...999).contains(repetitions) else { throw DraftError.invalid }
            return RoutineTargetRequest(targetWeightKg: weight, targetReps: repetitions, targetDurationSeconds: nil)
        case "REPS":
            guard let repetitions, (1...999).contains(repetitions) else { throw DraftError.invalid }
            return RoutineTargetRequest(targetWeightKg: nil, targetReps: repetitions, targetDurationSeconds: nil)
        case "DURATION":
            guard let duration, (1...86400).contains(duration) else { throw DraftError.invalid }
            return RoutineTargetRequest(targetWeightKg: nil, targetReps: nil, targetDurationSeconds: duration)
        default: throw DraftError.invalid
        }
    }
}

private enum DraftError: Error { case invalid }

private struct ExerciseDraft: Identifiable {
    let id = UUID()
    let existingID: Int?
    let exerciseID: Int
    let name: String
    let type: String
    var rest: String
    var sets: [SetDraft]

    func request() throws -> RoutineExerciseRequest {
        guard let pause = Int(rest), (0...3600).contains(pause), !sets.isEmpty else { throw DraftError.invalid }
        return RoutineExerciseRequest(routineExerciseId: existingID, exerciseId: exerciseID,
                                     restSeconds: pause, targets: try sets.map { try $0.target(type: type) })
    }
}

struct RoutineEditor: View {
    let session: AuthSession
    let original: RoutineResponse?
    let saved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var exercises: [ExerciseDraft]
    @State private var searching = false
    @State private var saving = false
    @State private var message = ""

    init(session: AuthSession, routine: RoutineResponse?, saved: @escaping () -> Void) {
        self.session = session
        original = routine
        self.saved = saved
        _name = State(initialValue: routine?.name ?? "")
        let drafts = (routine?.exercises ?? []).map { row in
            ExerciseDraft(existingID: row.routineExerciseId, exerciseID: row.exerciseId, name: "운동 \(row.sortOrder)",
                          type: row.recordType, rest: String(row.restSeconds), sets: row.targets.map {
                SetDraft(kg: String($0.targetWeightKg ?? 0), reps: String($0.targetReps ?? 10),
                         seconds: String($0.targetDurationSeconds ?? 30))
            })
        }
        _exercises = State(initialValue: drafts)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("루틴 이름", text: $name)
                ForEach($exercises) { $exercise in
                    Section(exercise.name) {
                        HStack { Text("휴식(초)"); TextField("초", text: $exercise.rest).keyboardType(.numberPad) }
                        ForEach($exercise.sets) { $set in
                            HStack {
                                if exercise.type == "WEIGHT_REPS" {
                                    TextField("kg", text: $set.kg).keyboardType(.decimalPad)
                                    Text("kg")
                                }
                                if exercise.type == "DURATION" {
                                    TextField("초", text: $set.seconds).keyboardType(.numberPad)
                                    Text("초")
                                } else {
                                    TextField("횟수", text: $set.reps).keyboardType(.numberPad)
                                    Text("회")
                                }
                            }
                        }.onDelete { exercise.sets.remove(atOffsets: $0) }
                        Button("세트 추가") {
                            let previous = exercise.sets.last ?? SetDraft()
                            exercise.sets.append(SetDraft(kg: previous.kg, reps: previous.reps, seconds: previous.seconds))
                        }
                        Button("종목 빼기") { exercises.removeAll { $0.id == exercise.id } }
                    }
                }.onMove { exercises.move(fromOffsets: $0, toOffset: $1) }
                Button("종목 추가") { searching = true }
                if !message.isEmpty { Text(message) }
                Button("저장") { Task { await save() } }
            }
            .gListCanvas().navigationTitle(original == nil ? "루틴 만들기" : "루틴 수정")
            .toolbar { Button("닫기") { dismiss() }; EditButton() }
            .disabled(saving)
            .sheet(isPresented: $searching) {
                ExerciseCatalog(session: session) { item in
                    exercises.append(ExerciseDraft(existingID: nil, exerciseID: item.id, name: item.nameKo,
                        type: item.recordType, rest: "90", sets: [SetDraft()]))
                    searching = false
                }
            }
        }.interactiveDismissDisabled(saving)
    }

    @MainActor private func save() async {
        guard !saving else { return }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...50).contains(title.unicodeScalars.count), !exercises.isEmpty else {
            message = "루틴 이름은 1~50자로 입력하고 종목을 하나 이상 골라 주세요"
            return
        }
        saving = true
        defer { saving = false }
        do {
            let request = RoutineSaveRequest(name: title, exercises: try exercises.map { try $0.request() })
            let path = original.map { "api/v1/routines/\($0.id)" } ?? "api/v1/routines"
            let data = try await session.protectedRequest(path, method: original == nil ? "POST" : "PUT",
                                                         body: JSONEncoder().encode(request))
            let response = try JSONDecoder().decode(ApiResponseRoutineResponse.self, from: data)
            guard response.success == true, response.data != nil else { throw URLError(.badServerResponse) }
            saved()
        } catch is DraftError { message = "세트별 중량·횟수·시간과 휴식 시간을 확인해 주세요" }
        catch { message = "저장 결과를 확인하지 못했어요. 다시 만들기 전에 목록을 확인해 주세요" }
    }
}

struct ExerciseCatalog: View {
    let session: AuthSession
    let select: (ExerciseResponse) -> Void
    @State private var keyword = ""
    @State private var items: [ExerciseResponse] = []
    @State private var page = 0
    @State private var hasNext = false
    @State private var message = ""
    @State private var requestID = UUID()

    var body: some View {
        NavigationStack {
            List {
                TextField("운동 이름", text: $keyword)
                if !message.isEmpty { Text(message); Button("다시 시도") { Task { await load(0) } } }
                ForEach(items, id: \.id) { item in Button(item.nameKo) { select(item) } }
                if hasNext { Button("더 보기") { Task { await load(page + 1) } } }
            }.gListCanvas().navigationTitle("운동 검색").task(id: keyword) {
                items = []
                hasNext = false
                if !keyword.isEmpty { try? await Task.sleep(for: .milliseconds(250)) }
                if !Task.isCancelled { await load(0) }
            }
        }
    }

    @MainActor private func load(_ requested: Int) async {
        let token = UUID()
        requestID = token
        do {
            let data = try await session.protectedRequest("api/v1/exercises", method: "GET", query: [
                URLQueryItem(name: "keyword", value: keyword), URLQueryItem(name: "page", value: String(requested))
            ])
            let response = try JSONDecoder().decode(ApiResponseExercisePageResponse.self, from: data)
            guard response.success == true, let result = response.data else { throw URLError(.badServerResponse) }
            guard requestID == token, !Task.isCancelled else { return }
            let known = Set(requested == 0 ? [] : items.map(\.id))
            items = (requested == 0 ? [] : items) + result.items.filter { !known.contains($0.id) }
            page = result.page
            hasNext = (page + 1) * result.size < result.totalElements
            message = items.isEmpty ? "검색 결과가 없어요" : ""
        } catch { if requestID == token && !Task.isCancelled { message = "종목을 불러오지 못했어요" } }
    }
}
