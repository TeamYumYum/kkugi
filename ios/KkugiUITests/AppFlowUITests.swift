import XCTest

extension XCTestCase {
    @MainActor func attachButtonBounds(_ app: XCUIApplication, screen: String) throws {
        let scale = XCUIScreen.main.screenshot().image.scale
        let root = try app.snapshot()
        var controls: [[String: Any]] = []
        func visit(_ element: XCUIElementSnapshot) {
            let frame = element.frame
            if [.button, .switch, .link].contains(element.elementType), !frame.isEmpty,
               frame.intersects(root.frame) {
                let edges = [frame.minX, frame.minY, frame.maxX, frame.maxY]
                controls.append(["label": element.label, "bounds": edges.map { Int(($0 * scale).rounded()) }])
            }
            element.children.forEach(visit)
        }
        visit(root)
        let payload: [String: Any] = ["screen": screen, "origin": "screen", "scale": scale, "controls": controls]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: payload), uniformTypeIdentifier: "public.json")
        attachment.name = screen + "-buttons.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

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

    @MainActor func testRecognizingPhotoCloseLayout() throws {
        let app = launch("meal-recognizing")
        let viewport = app.descendants(matching: .any).matching(identifier: "reference-viewport").firstMatch
        XCTAssertTrue(viewport.waitForExistence(timeout: 10))
        let close = app.buttons["닫기"]
        XCTAssertTrue(close.exists)
        let frame = close.frame.offsetBy(dx: -viewport.frame.minX, dy: -viewport.frame.minY)
        let scale = XCUIScreen.main.screenshot().image.scale
        let bounds = [frame.minX, frame.minY, frame.maxX, frame.maxY].map { Int(($0 * scale).rounded()) }
        let payload: [String: Any] = ["case": "meal-recognizing", "viewport": [1080,2160], "buttons": ["닫기": bounds]]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: payload), uniformTypeIdentifier: "public.json")
        attachment.name = "meal-recognizing-buttons.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(bounds, [65,40,144,119])
    }

    @MainActor func testAnimatedHomeOverlayLayout() throws {
        let app = XCUIApplication()
        app.launchEnvironment["KKUGI_UI_FIXTURE"] = "home"
        app.launchEnvironment["KKUGI_LAYOUT_REFERENCE"] = "1"
        app.launch()
        let labels = ["profile": "내 프로필", "streak": "연속 기록", "inbox": "알림", "chat": "꾸기에게 묻기"]
        let viewport = app.descendants(matching: .any).matching(identifier: "reference-viewport").firstMatch
        XCTAssertTrue(viewport.waitForExistence(timeout: 10))
        let frame = viewport.frame
        XCTAssertEqual(frame.width, 360)
        XCTAssertEqual(frame.height, 720)
        let scale = XCUIScreen.main.screenshot().image.scale
        XCTAssertEqual(scale, 3)
        var buttons: [String: [Int]] = [:]
        for (key, label) in labels {
            let button = app.buttons[label]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            let rect = button.frame.offsetBy(dx: -frame.minX, dy: -frame.minY)
            buttons[key] = [rect.minX, rect.minY, rect.maxX, rect.maxY].map { Int(($0 * scale).rounded()) }
        }
        let payload: [String: Any] = ["case": "home-overlay", "viewport": [1080, 2160], "buttons": buttons]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "home-overlay.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testMealAndWorkoutFromHome() throws {
        let app = launch("home")
        let meal = app.buttons["식사 기록"]
        XCTAssertTrue(meal.waitForExistence(timeout: 10))
        meal.tap()
        XCTAssertTrue(app.buttons["아직 기록 전이에요"].waitForExistence(timeout: 5))
        capture("meal-day-full.png")
        try attachButtonBounds(app, screen: "meal-day")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["운동"].tap()
        let routine = app.buttons["아침 루틴"]
        XCTAssertTrue(routine.waitForExistence(timeout: 5))
        capture("workout-full.png")
        routine.tap()
        XCTAssertTrue(app.navigationBars["아침 루틴"].waitForExistence(timeout: 5))
    }

    @MainActor func testCoachingAndGrowthFromHome() throws {
        let app = launch("home")
        XCTAssertTrue(app.buttons["코칭"].waitForExistence(timeout: 10))
        app.buttons["코칭"].tap()
        XCTAssertTrue(app.staticTexts["아직 표시할 코칭 내용이 없어요"].waitForExistence(timeout: 5))
        capture("coaching-full.png")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["성장"].tap()
        let badges = app.buttons["배지 모음"]
        XCTAssertTrue(badges.waitForExistence(timeout: 5))
        capture("growth-full.png")
        try attachButtonBounds(app, screen: "growth")
        badges.tap()
        XCTAssertTrue(app.staticTexts["첫 기록"].waitForExistence(timeout: 5))
    }
}
