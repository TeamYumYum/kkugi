import XCTest

final class LoginUITests: XCTestCase {
    @MainActor
    func testInitialFullScreenEvidence() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--capture-layout"]
        app.launch()
        XCTAssertTrue(app.buttons["카카오로 시작하기"].waitForExistence(timeout: 10))
        let content = app.otherElements["login-content"]
        XCTAssertTrue(content.exists)
        let bounds = NSCoder.cgRect(for: try XCTUnwrap(content.value as? String))
        let screen = XCUIScreen.main.screenshot()
        let image = screen.image
        let full = app.frame
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
        let png = XCTAttachment(data: screen.pngRepresentation, uniformTypeIdentifier: "public.png")
        png.name = "login-initial-full.png"
        png.lifetime = .keepAlways
        add(png)
        let metadata: [String: Any] = [
            "coordinateSpace": "screen points; multiply by scale for pixels",
            "scale": image.scale,
            "screen": ["x": full.minX, "y": full.minY, "width": full.width, "height": full.height],
            "content": ["x": bounds.minX, "y": bounds.minY, "width": bounds.width, "height": bounds.height],
            "excludedRegions": [
                ["x": full.minX, "y": full.minY, "width": full.width, "height": bounds.minY - full.minY, "reason": "top safe area"],
                ["x": full.minX, "y": bounds.maxY, "width": full.width, "height": full.maxY - bounds.maxY, "reason": "bottom safe area"]
            ],
            "androidParity": "not-yet-compared"
        ]
        let details = XCTAttachment(data: try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        details.name = "login-initial-full.json"
        details.lifetime = .keepAlways
        add(details)
        XCTAssertTrue(full.contains(bounds), "Content bounds \(bounds) exceed screen \(full)")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSocialLoginDoesNotPretendToSucceedAndCanRetry() {
        let app = XCUIApplication()
        app.launch()
        let kakao = app.buttons["카카오로 시작하기"]
        XCTAssertTrue(kakao.waitForExistence(timeout: 10))
        kakao.tap()
        let failure = app.buttons["지금은 로그인할 수 없어요. 잠시 후 다시 시도해 주세요"]
        XCTAssertTrue(failure.waitForExistence(timeout: 3))
        failure.tap()
        XCTAssertTrue(kakao.isEnabled)
        app.buttons["Google로 시작하기"].tap()
        XCTAssertTrue(failure.waitForExistence(timeout: 3))
    }

    @MainActor
    func testInProgressLoginDisablesEveryEntryPoint() {
        let app = XCUIApplication()
        app.launchArguments = ["--kkugi-login-busy"]
        app.launch()
        let busy = app.buttons["로그인하는 중"]
        XCTAssertTrue(busy.waitForExistence(timeout: 10))
        XCTAssertFalse(busy.isEnabled)
        XCTAssertFalse(app.buttons["Google로 시작하기"].isEnabled)
        XCTAssertFalse(app.buttons["심사용 계정으로 로그인"].isEnabled)
    }

    @MainActor
    func testReviewLoginValidatesInputAndCancelReturnsToLogin() {
        let app = XCUIApplication()
        app.launch()
        let entry = app.buttons["심사용 계정으로 로그인"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.staticTexts["테스트 계정으로 로그인"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["로그인"].isEnabled)
        app.textFields["아이디"].tap()
        app.textFields["아이디"].typeText("fixture-review")
        XCTAssertFalse(app.buttons["로그인"].isEnabled)
        app.secureTextFields["비밀번호"].tap()
        app.secureTextFields["비밀번호"].typeText("fixture-password")
        XCTAssertTrue(app.buttons["로그인"].isEnabled)
        app.buttons["취소"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
    }
}
