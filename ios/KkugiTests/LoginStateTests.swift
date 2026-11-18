import XCTest
@testable import Kkugi

final class LoginStateTests: XCTestCase {
    func testInitialStateIsSignedOutAndOffersBothProviders() {
        let state = LoginState()
        XCTAssertFalse(state.isBusy)
        XCTAssertNil(state.recentTitle)
        XCTAssertEqual(state.title(for: .kakao), "카카오로 시작하기")
        XCTAssertEqual(state.title(for: .google), "Google로 시작하기")
    }

    func testEachProviderMarksTheWholeScreenBusy() {
        for provider in LoginProvider.allCases {
            let state = LoginState(signingIn: provider)
            XCTAssertTrue(state.isBusy)
            XCTAssertEqual(state.title(for: provider), provider == .review ? "심사용 계정으로 로그인하는 중" : "로그인하는 중")
        }
    }

    func testRecentProviderUsesExistingAndroidLabels() {
        XCTAssertEqual(LoginState(recentProvider: .kakao).recentTitle, "카카오 · 최근 로그인")
        XCTAssertEqual(LoginState(recentProvider: .google).recentTitle, "Google · 최근 로그인")
        XCTAssertNil(LoginState(recentProvider: .review).recentTitle)
    }

    @MainActor
    func testUnavailableAuthenticationNeverProducesASession() {
        let model = LoginModel()
        model.signIn(.kakao)
        XCTAssertNotNil(model.state.error)
        XCTAssertNil(model.state.signingIn)
        XCTAssertNil(model.state.recentProvider)
        model.dismissError()
        XCTAssertNil(model.state.error)
        model.signInForReview("", "password")
        XCTAssertNil(model.state.error)
        model.signInForReview("review", "password")
        XCTAssertNotNil(model.state.error)
    }
}
