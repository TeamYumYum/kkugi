import Combine
import Foundation

enum LoginProvider: String, CaseIterable {
    case kakao, google, review
}

struct LoginState: Equatable {
    var recentProvider: LoginProvider?
    var signingIn: LoginProvider?
    var error: String?

    var isBusy: Bool { signingIn != nil }

    func title(for provider: LoginProvider) -> String {
        if signingIn == provider {
            return provider == .review ? "심사용 계정으로 로그인하는 중" : "로그인하는 중"
        }
        switch provider {
        case .kakao: return "카카오로 시작하기"
        case .google: return "Google로 시작하기"
        case .review: return "심사용 계정으로 로그인"
        }
    }

    var recentTitle: String? {
        guard let recentProvider, recentProvider != .review else { return nil }
        return "\(recentProvider == .kakao ? "카카오" : "Google") · 최근 로그인"
    }
}

enum LoginText {
    static let name = "꾸기"
    static let tagline = "꾸준히 기록하는 뻐꾸기"
    static let headline = "찍기만 하면 꾸기가 기록해 둘게요"
    static let terms = "시작하면 서비스 이용약관과 개인정보 처리방침에\n동의하는 것으로 봐요"
    static let reviewTitle = "테스트 계정으로 로그인"
    static let reviewDescription = "앱 심사용 계정이에요. 안내받은 아이디와 비밀번호를 넣어 주세요"
}

@MainActor
final class LoginModel: ObservableObject {
    @Published private(set) var state: LoginState

    private let review: ((String, String) async throws -> Void)?

    init(initialState: LoginState = LoginState(), review: ((String, String) async throws -> Void)? = nil) {
        self.review = review
        state = initialState
    }

    func signIn(_ provider: LoginProvider) {
        guard !state.isBusy else { return }
        // S15P31E101-714: wire the iOS identity provider in the authentication work item.
        // This foundation must never grant a session without server authentication.
        state.error = "지금은 로그인할 수 없어요. 잠시 후 다시 시도해 주세요"
    }

    func signInForReview(_ identifier: String, _ password: String) {
        guard !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty, !state.isBusy else { return }
        guard let review else { state.error = "지금은 테스트 계정으로 로그인할 수 없어요"; return }
        state.error = nil
        state.signingIn = .review
        Task {
            defer { state.signingIn = nil }
            do { try await review(identifier, password) }
            catch { state.error = "로그인하지 못했어요. 계정 정보를 확인해 주세요" }
        }
    }

    func dismissError() { state.error = nil }
}
