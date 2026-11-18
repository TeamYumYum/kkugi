import SwiftUI

@main
struct KkugiApp: App {
    var body: some Scene {
        WindowGroup {
            LoginRoot()
                .preferredColorScheme(.light)
        }
    }
}

struct LoginRoot: View {
    @StateObject private var model: LoginModel

    init() {
        var initialState = LoginState()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--kkugi-login-busy") {
            initialState.signingIn = .kakao
        }
        #endif
        _model = StateObject(wrappedValue: LoginModel(initialState: initialState))
    }

    var body: some View {
        LoginScreen(
            state: model.state,
            onSocialLogin: model.signIn,
            onReviewLogin: model.signInForReview,
            onDismissError: model.dismissError
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("login-content")
        .background(GColor.loginSky.ignoresSafeArea())
    }
}
