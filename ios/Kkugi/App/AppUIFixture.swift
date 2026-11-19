#if DEBUG
import Foundation

enum AppUIFixture {
    @MainActor static func flow(onboarded: Bool) throws -> MemberFlow {
        let transport = URLSessionConfiguration.ephemeral
        transport.protocolClasses = [FixtureProtocol.self]
        let vault = SessionVault(service: "com.kkugi.ios.uitest.fixture")
        try vault.save(StoredSession(sessionID: UUID(), memberID: 123, onboarded: onboarded,
                                     accessToken: "fixture-access", refreshToken: "fixture-refresh"))
        let api = AuthClient(baseURL: URL(string: "https://ui.fixture.invalid")!, session: URLSession(configuration: transport))
        return MemberFlow(session: AuthSession(api: api, vault: vault))
    }
}

private final class FixtureProtocol: URLProtocol {
    private static let notificationLock = NSLock()
    private static var hasReadNotification = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else { return }
        let payload = fixture(url)
        let code = payload == nil ? 404 : 200
        let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let json = "{\"success\":\(code == 200),\"data\":\(payload ?? "null")}"
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    private func fixture(_ url: URL) -> String? {
        guard url.host == "ui.fixture.invalid",
              request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-access" else { return nil }
        let populated = ProcessInfo.processInfo.environment["KKUGI_GALLERY_DATA"] == "recorded"
        switch url.path {
        case "/api/v1/members/me/profile":
            return #"{"nickname":"꾸기회원","healthGoal":"MAINTAIN","gender":"FEMALE","birthDate":"2000-01-01","heightCm":167,"startWeightKg":60,"activityLevel":"MODERATE","avatar":"FRONT","onboardedAt":"2026-11-18T00:00:00+09:00"}"#
        case "/api/v1/workout-schedules": return #"{"items":[]}"#
        case "/api/v1/growth/me":
            if populated {
                let badges = [3, 7, 30, 100].map { days in
                    let earned = days == 3 ? "\"2026-10-17\"" : days == 7 ? "\"2026-10-21\"" : "null"
                    return #"{"code":"DIET_STREAK_\#(days)_DAYS","name":"식단 \#(days)일","description":"식단 목표를 \#(days)일 연속 달성했어요","category":"DIET","conditionKind":"STREAK_DAYS","threshold":\#(days),"earnedAt":\#(earned)}"#
                }.joined(separator: ",")
                return #"{"started":true,"startedOn":"2026-09-28","today":"2026-10-21","diet":{"currentDays":7,"longestDays":7,"thisWeek":[]},"workout":{"currentWeeks":2,"longestWeeks":2},"badges":[\#(badges)],"path":{"days":[{"date":"2026-10-19","dietAchieved":true},{"date":"2026-10-20","dietAchieved":true},{"date":"2026-10-21","dietAchieved":null}],"weeklyGoals":[]}}"#
            }
            return #"{"started":true,"startedOn":"2026-01-01","today":"2026-01-08","diet":{"currentDays":2,"longestDays":3,"thisWeek":[]},"workout":{"currentWeeks":1,"longestWeeks":2},"badges":[{"code":"FIRST","name":"첫 기록","description":"첫 기록을 남겼어요","category":"DIET","conditionKind":"COUNT","threshold":1,"earnedAt":"2026-01-01"}],"path":{"days":[],"weeklyGoals":[]}}"#
        case "/api/v1/weekly-workout-goal/me":
            return #"{"configured":true,"thisWeek":{"weekStartDate":"2026-01-05","targetCount":3,"firstWeek":false},"progress":{"countedCount":1,"achieved":false}}"#
        case "/api/v1/members/me/notifications/2/read":
            guard populated, request.httpMethod == "POST" else { return nil }
            Self.notificationLock.withLock { Self.hasReadNotification = true }
            return "null"
        case "/api/v1/members/me/notifications/unread-count":
            let count = populated && !Self.notificationLock.withLock { Self.hasReadNotification } ? 1 : 0
            return #"{"unreadCount":\#(count)}"#
        case "/api/v1/members/me/notifications":
            if populated {
                let read = Self.notificationLock.withLock { Self.hasReadNotification }
                let meal = #"{"id":2,"type":"LAST_MEAL","title":"제목 2","body":"본문 2","data":{},"sentAt":"2026-11-11T17:05:00+09:00","read":\#(read)}"#
                let report = #"{"id":1,"type":"WEEKLY_REPORT","title":"제목 1","body":"본문 1","data":{"weekStartDate":"2026-11-09"},"sentAt":"2026-11-09T09:00:00+09:00","read":true}"#
                if ProcessInfo.processInfo.environment["KKUGI_NOTIFICATION_PAGES"] == "1" {
                    let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "page" }?.value
                    guard page == "0" || page == "1" else { return nil }
                    return #"{"items":[\#(page == "0" ? meal : report)],"page":\#(page ?? "0"),"size":1,"totalElements":2}"#
                }
                return #"{"items":[\#(meal),\#(report)],"page":0,"size":20,"totalElements":2}"#
            }
            return #"{"items":[],"page":0,"size":20,"totalElements":0}"#
        case "/api/v1/routines": return #"{"items":[{"id":1,"name":"아침 루틴","exercises":[]}]}"#
        case "/api/v1/routine-recommendations":
            let split = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "style" }?.value == "SPLIT"
            let style = split ? "SPLIT" : "FULL_BODY"
            let title = split ? "상체 A" : "전신 A"
            return #"{"style":"\#(style)","healthGoal":"MAINTAIN","routines":[{"key":"\#(style)_1","name":"\#(title)","timesPerWeek":3,"exercises":[{"slot":1,"exerciseId":1,"nameKo":"스쿼트","bodyPart":"LOWER_BODY","recordType":"WEIGHT_REPS"}]}]}"#
        case "/api/v1/routine-recommendations/ai":
            if request.httpMethod == "GET" { return #"{"usedCount":1,"remainingCount":2,"resetsAt":"2026-11-23T00:00:00+09:00","recommendations":[{"recommendationId":7,"createdAt":"2026-11-18T12:00:00+09:00"}]}"# }
            fallthrough
        case "/api/v1/routine-recommendations/ai/7":
            return #"{"recommendationId":7,"needsMedicalNotice":true,"comment":"무릎 부담을 줄였어요.","remainingCount":2,"routines":[{"key":"AI_1","name":"상체 A","timesPerWeek":3,"exercises":[{"slot":1,"exerciseId":2,"nameKo":"벤치프레스","bodyPart":"CHEST","recordType":"WEIGHT_REPS"}]}]}"#
        case "/api/v1/workout-sessions":
            if populated {
                return #"{"items":[{"id":7,"clientUuid":"00000000-0000-4000-8000-000000000007","routineName":"기록한 루틴","startedAt":"2026-11-18T09:00:00+09:00","endedAt":"2026-11-18T09:10:00+09:00","exerciseCount":1,"newRecordExercises":[]}]}"#
            }
            return #"{"items":[]}"#
        case "/api/v1/weight-records": return #"{"items":[]}"#
        case "/api/v1/workout-sessions/7":
            return #"{"id":7,"clientUuid":"00000000-0000-4000-8000-000000000007","routineName":"기록한 루틴","startedAt":"2026-11-18T09:00:00+09:00","endedAt":"2026-11-18T09:10:00+09:00","startExercises":[],"performedExercises":[{"sortOrder":1,"exerciseId":1,"exerciseName":"스쿼트","recordType":"WEIGHT_REPS","weightType":"EXTERNAL","restSeconds":60,"skipped":false,"sets":[{"setNo":1,"target":{"weightKg":20,"reps":10},"actual":{"weightKg":20,"reps":10},"status":"COMPLETED"}]}],"totalVolumeKg":200}"#
        case "/api/v1/exercises":
            return #"{"items":[{"id":1,"nameKo":"스쿼트","nameEn":"Squat","bodyPart":"LOWER_BODY","equipment":"BARBELL","recordType":"WEIGHT_REPS","weightType":"EXTERNAL"}],"page":0,"size":20,"totalElements":1}"#
        case "/api/v1/weekly-reports/me/2026-11-09":
            return #"{"weekStartDate":"2026-11-09","periodStartDate":"2026-11-09","periodEndDate":"2026-11-15","diet":{"periodDays":7,"loggedDays":3,"achievedDays":2,"level":"GOOD"},"nutrients":{},"workout":{"level":"GOOD"},"weight":{"trend":"STABLE"},"comment":{"text":"11월 9일 주간 기록","source":"RULE"}}"#
        case "/api/v1/coaching-plan/me":
            return #"{"targetKcal":1800,"carbRatio":50,"proteinRatio":25,"fatRatio":25,"startedOn":"2026-01-01","recalcPending":false}"#
        case "/api/v1/meals":
            guard let day = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "date" })?.value,
                  day.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return nil }
            if populated {
                let nutrition = #"{"kcal":180,"carbohydrateG":12,"proteinG":24,"fatG":4}"#
                let row = #"{"id":7,"clientUuid":"00000000-0000-4000-8000-000000000007","eatenAt":"\#(day)T08:30:00+09:00","mealType":"BREAKFAST","items":[{"foodId":4,"foodName":"닭가슴살","grams":100,"listed":true,"nutrition":\#(nutrition)}],"totalNutrition":\#(nutrition)}"#
                return #"{"date":"\#(day)","asOf":"\#(day)","meals":[\#(row)],"totalNutrition":\#(nutrition)}"#
            }
            return "{\"date\":\"\(day)\",\"asOf\":\"2026-01-08\",\"meals\":[],\"totalNutrition\":{\"kcal\":0,\"carbohydrateG\":0,\"proteinG\":0,\"fatG\":0}}"
        default:
            if url.path.hasPrefix("/api/v1/daily-summaries/"),
               let date = url.pathComponents.last,
               date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
                return #"{"date":"\#(date)","goalReady":true,"targetKcal":1850,"intakeKcal":0,"remainingKcal":1850,"asOf":"\#(date)"}"#
            }
            return nil
        }
    }
}
#endif
