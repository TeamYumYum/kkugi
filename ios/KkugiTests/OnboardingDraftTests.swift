import XCTest
@testable import Kkugi

final class OnboardingDraftTests: XCTestCase {
    func testNicknameCountsScalarsAndNormalizesSpaces() {
        var draft = OnboardingDraft()
        draft.nickname = "  꾸기   왕 "
        XCTAssertEqual(draft.normalizedNickname, "꾸기 왕")
        draft.nickname = "👍🏻"
        XCTAssertEqual(draft.normalizedNickname, "👍🏻")
        draft.nickname = "꾸기\t왕"
        XCTAssertNil(draft.normalizedNickname)
    }

    func testDateMustExistAndMemberMustBeFourteenInKorea() throws {
        let today = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-17T15:00:00Z"))
        var draft = OnboardingDraft()
        draft.birthday = "20121118"
        XCTAssertEqual(draft.birthDate(today: today), "2012-11-18")
        draft.birthday = "20121119"
        XCTAssertNil(draft.birthDate(today: today))
        draft.birthday = "20110229"
        XCTAssertNil(draft.birthDate(today: today))
    }

    func testMeasurementChecksRangeBeforeRounding() {
        XCTAssertNil(OnboardingDraft.measure("19.995", range: 20...300))
        XCTAssertNil(OnboardingDraft.measure("51 kg", range: 20...300))
        XCTAssertEqual(OnboardingDraft.measure("51.125", range: 20...300), Decimal(string: "51.13"))
    }
}
