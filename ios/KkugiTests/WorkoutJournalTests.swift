import XCTest
@testable import Kkugi

final class WorkoutJournalTests: XCTestCase {
    func testRestoresCompletedSetsAndKeepsOneStableUploadPerMember() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = WorkoutJournalStore(directory: root)
        try await first.start(7)
        let started = try await first.read(7)
        let id = try XCTUnwrap(started.active?.id)
        let exercise = ExerciseResponse(id: 21, nameKo: "팔굽혀펴기", nameEn: "Push-up", bodyPart: "CHEST",
            equipment: "BODYWEIGHT", recordType: "REPS", weightType: "NONE", startImageUrl: nil, endImageUrl: nil)
        let values = WorkoutSessionValuesRequest(weightKg: nil, reps: 12, durationSeconds: nil)
        try await first.record(member: 7, activeID: id, exercise: exercise, rowID: nil, values: values)
        let restored = WorkoutJournalStore(directory: root)
        let journal = try await restored.read(7)
        XCTAssertEqual(journal.active?.exercises.first?.sets.first?.actual?.reps, 12)
        let other = try await restored.read(8)
        XCTAssertNil(other.active)
        XCTAssertTrue(other.queue.isEmpty)
        try await restored.finish(member: 7, id: id)
        let ended = try await restored.read(7)
        XCTAssertNil(ended.active)
        XCTAssertEqual(ended.queue.count, 1)
        XCTAssertEqual(ended.queue.first?.request.clientUuid, id.uuidString)
        let afterRestart = try await first.read(7)
        XCTAssertEqual(afterRestart.queue.first?.request.endedAt, ended.queue.first?.request.endedAt)
    }
}
