import Foundation

struct ActiveWorkout: Codable {
    let id: UUID
    let startedAt: Date
    var exercises: [PerformedExercise] = []
}

struct PerformedExercise: Codable, Identifiable {
    let id: UUID
    let catalog: ExerciseResponse
    var sets: [WorkoutSessionSetRequest]
}

struct QueuedWorkout: Codable {
    let request: WorkoutSessionUploadRequest
    var rejection: Int?
}

struct WorkoutJournal: Codable {
    var active: ActiveWorkout?
    var queue: [QueuedWorkout] = []
}

actor WorkoutJournalStore {
    static let shared = WorkoutJournalStore()
    private let directory: URL
    private var sending = Set<Int64>()

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WorkoutJournal", isDirectory: true)
    }

    private func url(_ member: Int64) -> URL { directory.appendingPathComponent("\(member).json") }

    func read(_ member: Int64) throws -> WorkoutJournal {
        do { return try JSONDecoder().decode(WorkoutJournal.self, from: Data(contentsOf: url(member))) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return WorkoutJournal() }
    }

    private func save(_ journal: WorkoutJournal, member: Int64) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var location = directory
        var attributes = URLResourceValues()
        attributes.isExcludedFromBackup = true
        try location.setResourceValues(attributes)
        try JSONEncoder().encode(journal).write(to: url(member), options: [.atomic, .completeFileProtection])
    }

    func start(_ member: Int64) throws {
        var journal = try read(member)
        if journal.active != nil { return }
        journal.active = ActiveWorkout(id: UUID(), startedAt: Date())
        try save(journal, member: member)
    }

    func record(member: Int64, activeID: UUID, exercise: ExerciseResponse, rowID: UUID?, values: WorkoutSessionValuesRequest) throws {
        var journal = try read(member)
        guard var active = journal.active, active.id == activeID else { throw CancellationError() }
        let row: Int
        if let rowID {
            guard let i = active.exercises.firstIndex(where: { $0.id == rowID && $0.catalog.id == exercise.id }) else {
                throw CancellationError()
            }
            row = i
        } else {
            row = active.exercises.count
            active.exercises.append(PerformedExercise(id: UUID(), catalog: exercise, sets: []))
        }
        let ordinal = active.exercises[row].sets.count + 1
        let set = WorkoutSessionSetRequest(setNo: ordinal, originStartSetNo: nil, target: values, actual: values,
            status: "COMPLETED", completedAt: ISO8601DateFormatter().string(from: Date()))
        active.exercises[row].sets.append(set)
        journal.active = active
        try save(journal, member: member)
    }

    func finish(member: Int64, id: UUID) throws {
        var journal = try read(member)
        guard let active = journal.active, active.id == id, !active.exercises.isEmpty else { throw CancellationError() }
        let exercises = active.exercises.enumerated().map { i, row in
            WorkoutSessionExerciseRequest(sortOrder: i + 1, originStartOrder: nil, exerciseId: row.catalog.id,
                exerciseName: row.catalog.nameKo, recordType: row.catalog.recordType, weightType: row.catalog.weightType,
                restSeconds: 90, skipped: false, sets: row.sets)
        }
        let formatter = ISO8601DateFormatter()
        let body = WorkoutSessionUploadRequest(clientUuid: id.uuidString, routineId: nil, scheduleId: nil,
            scheduledDate: nil, routineName: nil, startedAt: formatter.string(from: active.startedAt),
            endedAt: formatter.string(from: Date()), startExercises: [], performedExercises: exercises)
        journal.queue.append(QueuedWorkout(request: body))
        journal.active = nil
        try save(journal, member: member)
    }

    func flush(member: Int64, session: AuthSession) async throws {
        guard sending.insert(member).inserted else { return }
        defer { sending.remove(member) }
        let pending = try read(member).queue.filter { $0.rejection == nil }
        for item in pending {
            do {
                let data = try await session.protectedRequest("api/v1/workout-sessions", method: "POST",
                    body: JSONEncoder().encode(item.request), memberID: member)
                let response = try JSONDecoder().decode(ApiResponseWorkoutSessionUploadResponse.self, from: data)
                guard response.success == true, let uploaded = response.data,
                      UUID(uuidString: uploaded.clientUuid) == UUID(uuidString: item.request.clientUuid) else {
                    throw URLError(.badServerResponse)
                }
                var journal = try read(member)
                journal.queue.removeAll { $0.request.clientUuid == item.request.clientUuid }
                try save(journal, member: member)
            } catch let error as AuthClient.RequestFailure {
                guard (400..<500).contains(error.status), error.status != 429, error.status != 401 else { throw error }
                var journal = try read(member)
                if let i = journal.queue.firstIndex(where: { $0.request.clientUuid == item.request.clientUuid }) {
                    journal.queue[i].rejection = error.status
                    try save(journal, member: member)
                }
            }
        }
    }
}
