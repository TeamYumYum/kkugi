import XCTest

final class AppFlowUITests: XCTestCase {
    @MainActor private func launch(_ fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KKUGI_UI_FIXTURE"] = fixture
        app.launch()
        return app
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testOnboardingKeepsNicknameWhenReturningFromGoal() {
        let app = launch("onboarding")
        let field = app.textFields["닉네임"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        capture("onboarding-nickname-full.png")
        app.buttons["다음"].tap()
        XCTAssertTrue(app.staticTexts["닉네임을 2자 이상 12자 이하로 입력해 주세요"].exists)
        field.tap()
        field.typeText("Kkugi")
        app.buttons["다음"].tap()
        XCTAssertTrue(app.buttons["체중 감량"].waitForExistence(timeout: 5))
        capture("onboarding-goal-full.png")
        app.buttons["뒤로"].tap()
        XCTAssertEqual(field.value as? String, "Kkugi")
    }

    @MainActor func testMealAndWorkoutFromHome() {
        let app = launch("home")
        let meal = app.buttons["식사 기록"]
        XCTAssertTrue(meal.waitForExistence(timeout: 10))
        meal.tap()
        XCTAssertTrue(app.staticTexts["기록한 식사가 없어요"].waitForExistence(timeout: 5))
        capture("meal-day-full.png")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["운동"].tap()
        let routine = app.buttons["아침 루틴"]
        XCTAssertTrue(routine.waitForExistence(timeout: 5))
        capture("workout-full.png")
        routine.tap()
        XCTAssertTrue(app.navigationBars["아침 루틴"].waitForExistence(timeout: 5))
    }

    @MainActor func testCoachingAndGrowthFromHome() {
        let app = launch("home")
        XCTAssertTrue(app.buttons["코칭"].waitForExistence(timeout: 10))
        app.buttons["코칭"].tap()
        XCTAssertTrue(app.staticTexts["하루 섭취 목표"].waitForExistence(timeout: 5))
        capture("coaching-full.png")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["성장"].tap()
        let badges = app.buttons["배지 모음"]
        XCTAssertTrue(badges.waitForExistence(timeout: 5))
        capture("growth-full.png")
        badges.tap()
        XCTAssertTrue(app.staticTexts["첫 기록"].waitForExistence(timeout: 5))
    }
}
