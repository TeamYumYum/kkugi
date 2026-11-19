import XCTest

@MainActor
final class ScreenGalleryUITests: XCTestCase {
    private func home(populated: Bool = false) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KKUGI_UI_FIXTURE"] = "home"
        app.launchEnvironment["KKUGI_MEAL_TIME"] = "2026-10-27T12:30:00+09:00"
        if populated { app.launchEnvironment["KKUGI_GALLERY_DATA"] = "recorded" }
        app.launch()
        try ready(app.buttons["내 프로필"])
        return app
    }

    private func ready(_ element: XCUIElement) throws {
        guard element.exists || element.waitForExistence(timeout: 8) else {
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
        let animated = ["home", "growth", "meal-day", "meal-recognizing", "workout-recorder"]
        let frame = animated.contains(name) ? XCUIScreen.main.screenshot() : try settledFrame(name)
        let attachment = XCTAttachment(screenshot: frame)
        attachment.name = name + "-full.png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func settledFrame(_ name: String) throws -> XCUIScreenshot {
        let deadline = ProcessInfo.processInfo.systemUptime + 6
        var previous: Data?
        repeat {
            let frame = XCUIScreen.main.screenshot()
            guard let cgImage = frame.image.cgImage, let pixels = cgImage.dataProvider?.data else {
                throw NSError(domain: "Gallery", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot read pixels for " + name])
            }
            let data = pixels as Data
            if previous == data { return frame }
            previous = data
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        } while ProcessInfo.processInfo.systemUptime < deadline
        throw NSError(domain: "Gallery", code: 3, userInfo: [NSLocalizedDescriptionKey: "Screen did not settle: " + name])
    }

    private func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func testHomeAndProfileScreens() throws {
        let app = try home()
        try capture("home", when: app.buttons["연속 기록"])
        try tap(app, "알림")
        try capture("inbox-empty", when: app.staticTexts["아직 받은 알림이 없어요"])
        try tap(app, "뒤로")
        try tap(app, "꾸기에게 묻기")
        try capture("chat", when: app.navigationBars["꾸기에게 묻기"])
        back(app)
        try tap(app, "내 프로필")
        try capture("profile", when: app.buttons["프로필 수정"])
        try tap(app, "프로필 수정")
        try capture("profile-edit", when: app.navigationBars["프로필 수정"])
        try tap(app, "몸 정보")
        try capture("body-edit", when: app.textFields["키 (cm)"])
        try tap(app, "취소")
        try tap(app, "회원 탈퇴")
        try capture("withdrawal", when: app.staticTexts["탈퇴하기 전에 확인해 주세요"])
        XCTAssertFalse(app.buttons["탈퇴하기"].isEnabled)
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
        try tap(app, "사진 보관함에서 선택")
        let cancelPicker = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "취소"])).firstMatch
        try capture("system-photo-picker", when: cancelPicker)
        cancelPicker.tap()
        try ready(app.buttons["사진 보관함에서 선택"])
    }

    func testRecordedMealAndNotifications() throws {
        let app = try home(populated: true)
        try tap(app, "알림")
        let unread = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "제목 2", "안 읽음")).firstMatch
        try capture("inbox", when: unread)
        unread.tap()
        let read = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND NOT (label CONTAINS %@)", "제목 2", "안 읽음")).firstMatch
        try ready(read)
        try tap(app, "뒤로")
        try tap(app, "식사 기록")
        try tap(app, "식사 상세")
        try capture("meal-detail", when: app.navigationBars["식사 상세"])
        back(app)
        try tap(app, "식사 수정")
        try capture("meal-edit", when: app.navigationBars["식사 수정"])
    }

    func testWorkoutScreens() throws {
        let app = try home()
        try tap(app, "운동")
        for (label, title, shot) in [("운동 일정", "운동 일정", "schedule"), ("날짜별 운동 기록", "운동 기록", "workout-history"),
                                    ("종목별 기록", "종목별 기록", "exercise-records"), ("운동 수행", "운동 수행", "workout-recorder"),
                                    ("아침 루틴", "아침 루틴", "routine-detail")] {
            try tap(app, label)
            try capture(shot, when: app.navigationBars[title])
            if shot == "workout-recorder" { try attachButtonBounds(app, screen: shot) }
            back(app)
        }
        try tap(app, "루틴 만들기")
        try capture("routine-editor", when: app.textFields["루틴 이름"])
        try tap(app, "종목 추가")
        try capture("exercise-search", when: app.textFields["운동 이름"])
    }

    func testCoachingAndGrowthDetails() throws {
        let app = try home(populated: true)
        try tap(app, "내 프로필")
        try tap(app, "목표 칼로리")
        try capture("target-calorie", when: app.staticTexts["하루 섭취 목표"])
        back(app)
        try tap(app, "체중 기록")
        try capture("weight", when: app.navigationBars["체중 기록"])
        back(app)
        try tap(app, "홈으로")
        try tap(app, "성장")
        for (label, shot) in [("날짜별 식단 기록", "diet-streak"), ("주간 목표 달성 기록", "workout-streak"),
                              ("배지 모음", "badges"), ("주간 리포트", "weekly-report")] {
            try tap(app, label)
            try capture(shot, when: app.navigationBars[label])
            back(app)
        }
    }

    func testRoutineRecommendations() throws {
        let app = try home(populated: true)
        try tap(app, "운동")
        try tap(app, "날짜별 운동 기록")
        try tap(app, "기록한 루틴")
        try capture("workout-detail", when: app.navigationBars["기록한 루틴"])
        back(app)
        back(app)
        try tap(app, "루틴 목록")
        try capture("routine-list", when: app.buttons["아침 루틴"])
        try tap(app, "루틴 추천")
        try capture("routine-recommend", when: app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "전신 A")).firstMatch)
        try tap(app, "AI로 추천받기")
        try capture("ai-survey-full", when: app.navigationBars["AI 추천"])
        try tap(app, "집중할 부위")
        try capture("ai-survey", when: app.switches["하체"])
        try tap(app, "받은 추천 · 2026-11-18")
        try capture("ai-result", when: app.navigationBars["AI 추천 루틴"])
    }

    func testExercisePicker() throws {
        let app = try home()
        try tap(app, "운동")
        try tap(app, "종목별 기록")
        try tap(app, "종목 선택")
        try capture("exercise-pick", when: app.buttons["스쿼트"])
    }
}
