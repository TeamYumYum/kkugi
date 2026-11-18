import XCTest
@testable import Kkugi

private final class MemberFixtureProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else { return }
        let authorized = request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-access"
        let profile = #"{"nickname":"꾸기회원","healthGoal":"MAINTAIN","gender":"FEMALE","birthDate":"2000-01-01","heightCm":167,"startWeightKg":60,"activityLevel":"MODERATE","avatar":"FRONT","onboardedAt":"2026-11-18T00:00:00+09:00"}"#
        let data: String
        let status: Int
        switch (url.path, request.httpMethod, authorized) {
        case ("/api/v1/auth/login/review", "POST", false):
            data = #"{"memberId":7,"onboarded":false,"accessToken":"fixture-access","refreshToken":"fixture-refresh"}"#
            status = 200
        case ("/api/v1/members/me/onboarding", "POST", true),
             ("/api/v1/members/me/profile", "GET", true):
            data = profile
            status = 200
        case ("/api/v1/members/me/profile", "PUT", true):
            data = profile.replacingOccurrences(of: "꾸기회원", with: "새닉네임")
            status = 200
        default:
            data = "null"
            status = 404
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"success\":\(status == 200),\"data\":\(data)}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class MemberFlowTests: XCTestCase {
    @MainActor func testReviewLoginOnboardingRestoreAndProfileUpdate() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MemberFixtureProtocol.self]
        let transport = URLSession(configuration: configuration)
        defer { transport.invalidateAndCancel() }
        let vault = SessionVault(service: "com.kkugi.member.tests." + UUID().uuidString)
        defer { try? vault.clear() }
        let api = AuthClient(baseURL: URL(string: "https://member.fixture.invalid")!, session: transport)
        let session = AuthSession(api: api, vault: vault)
        let flow = MemberFlow(session: session)
        try await flow.review("fixture", "fixture")
        XCTAssertEqual(flow.route, .onboarding)
        let draft = OnboardingDraft(nickname: "꾸기회원", goal: "MAINTAIN", gender: "FEMALE",
                                    birthday: "20000101", height: "167", weight: "60", activity: "MODERATE")
        try await flow.submit(draft)
        XCTAssertEqual(try vault.read()?.onboarded, true)
        let restored = MemberFlow(session: session)
        await restored.restore()
        XCTAssertNotEqual(restored.route, .onboarding)
        XCTAssertNotEqual(restored.route, .login)
        try await restored.loadProfile()
        XCTAssertEqual(restored.profile?.nickname, "꾸기회원")
        try await restored.updateProfile(ProfileUpdateRequest(nickname: "새닉네임", healthGoal: draft.goal,
            gender: draft.gender, birthDate: "2000-01-01", heightCm: 167, activityLevel: draft.activity))
        XCTAssertEqual(restored.profile?.nickname, "새닉네임")
    }
}
