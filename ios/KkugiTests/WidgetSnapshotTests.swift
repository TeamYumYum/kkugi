import XCTest
@testable import Kkugi

final class WidgetSnapshotTests: XCTestCase {
    func testKoreaMidnightHidesPreviousDayCalories() {
        let instant = ISO8601DateFormatter().date(from: "2026-11-17T15:00:00Z")!
        XCTAssertEqual(GardenWidgetSnapshot.koreaDay(instant), "2026-11-18")
        let record = GardenWidgetSnapshot(memberID: 1, onboarded: true, day: "2026-11-17", targetKcal: 1800, intakeKcal: 1900)
        XCTAssertEqual(record.calories(on: "2026-11-17"), "목표보다 100 kcal 초과")
        XCTAssertEqual(record.calories(on: "2026-11-18"), "오늘 기록을 확인해 주세요")
        XCTAssertNil(GardenWidgetSnapshot.signedOut.memberID)
        XCTAssertNil(GardenWidgetSnapshot.signedOut.intakeKcal)
    }
}
