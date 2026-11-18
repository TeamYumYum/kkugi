import XCTest
@testable import Kkugi

private final class AuthFixtureProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        let success = request.httpMethod == "POST" && url.path == "/api/v1/auth/login/review"
        let body = success
            ? #"{"success":true,"data":{"memberId":42,"onboarded":false,"accessToken":"fixture-a","refreshToken":"fixture-r"}}"#
            : #"{"success":false,"error":{"code":"AUTH_REFRESH_INVALID"}}"#
        let response = HTTPURLResponse(url: url, statusCode: success ? 200 : 401,
                                       httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class AuthClientTests: XCTestCase {
    func testReviewResponseAndExpiredRefresh() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthFixtureProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let api = AuthClient(baseURL: URL(string: "https://fixture.invalid")!, session: session)
        let result = try await api.review(loginID: "fixture", password: "fixture")
        XCTAssertEqual(result.memberId, 42)
        XCTAssertFalse(result.onboarded)
        do {
            _ = try await api.refresh(token: result.refreshToken)
            XCTFail("Expected expired refresh token to fail")
        } catch let failure as AuthClient.RequestFailure {
            XCTAssertEqual(failure.status, 401)
            XCTAssertEqual(failure.code, "AUTH_REFRESH_INVALID")
        }
    }
}
