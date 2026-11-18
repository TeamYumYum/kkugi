import XCTest

@MainActor
final class ScreenGalleryUITests: XCTestCase {
    private func home() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KKUGI_UI_FIXTURE"] = "home"
        app.launch()
        try ready(app.buttons["내 프로필"])
        return app
    }

    private func ready(_ element: XCUIElement) throws {
        guard element.waitForExistence(timeout: 8) else {
            throw NSError(domain: "Gallery", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing element: \(element)"])
        }
    }

    private func tap(_ app: XCUIApplication, _ label: String) throws {
        let button = app.buttons[label].firstMatch
        try ready(button)
        button.tap()
    }

    private func capture(_ name: String, when element: XCUIElement) throws {
        try ready(element)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name + "-full.png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func testHomeAndProfileScreens() throws {
        let app = try home()
        try capture("home", when: app.buttons["연속 기록"])
        try tap(app, "알림")
        try capture("inbox", when: app.staticTexts["아직 알림이 없어요"])
        back(app)
        try tap(app, "꾸기에게 묻기")
        try capture("chat", when: app.navigationBars["꾸기에게 묻기"])
        back(app)
        try tap(app, "내 프로필")
        try capture("profile", when: app.buttons["프로필 수정"])
        try tap(app, "프로필 수정")
        try capture("profile-edit", when: app.navigationBars["프로필 수정"])
        try tap(app, "취소")
        try tap(app, "회원 탈퇴")
        try capture("withdrawal", when: app.alerts.firstMatch)
        try tap(app, "취소")
    }

    func testMealEntryScreens() throws {
        let app = try home()
        try tap(app, "식사 기록")
        try tap(app, "식사 추가")
        try capture("meal-add", when: app.buttons["음식 검색"])
        try tap(app, "음식 검색")
        try capture("food-search", when: app.textFields["음식 이름이나 업체명"])
        try tap(app, "닫기")
        try tap(app, "사진으로 음식 인식")
        try capture("meal-photo", when: app.navigationBars["사진으로 식사 기록"])
    }

    func testWorkoutScreens() throws {
        let app = try home()
        try tap(app, "운동")
        for (label, title, shot) in [("운동 일정", "운동 일정", "schedule"), ("날짜별 운동 기록", "운동 기록", "workout-history"),
                                    ("종목별 기록", "종목별 기록", "exercise-records"), ("운동 수행", "운동 수행", "workout-recorder"),
                                    ("아침 루틴", "아침 루틴", "routine-detail")] {
            try tap(app, label)
            try capture(shot, when: app.navigationBars[title])
            back(app)
        }
        try tap(app, "루틴 만들기")
        try capture("routine-editor", when: app.textFields["루틴 이름"])
        try tap(app, "종목 추가")
        try capture("exercise-search", when: app.textFields["운동 이름"])
    }

    func testCoachingAndGrowthDetails() throws {
        let app = try home()
        try tap(app, "코칭")
        try tap(app, "체중 기록")
        try capture("weight", when: app.navigationBars["체중 기록"])
        back(app)
        back(app)
        try tap(app, "성장")
        for (label, shot) in [("날짜별 식단 기록", "diet-streak"), ("주간 목표 달성 기록", "workout-streak"),
                              ("배지 모음", "badges"), ("주간 리포트", "weekly-report")] {
            try tap(app, label)
            try capture(shot, when: app.navigationBars[label])
            back(app)
        }
    }
}
