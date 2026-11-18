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
    @StateObject private var flow: MemberFlow
    @StateObject private var model: LoginModel

    init() {
        var initialState = LoginState()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--kkugi-login-busy") {
            initialState.signingIn = .kakao
        }
        #endif
        let configured = Bundle.main.object(forInfoDictionaryKey: "KkugiAPIBaseURL") as? String
        let url = configured.flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil }
        let flow = MemberFlow(baseURL: url)
        _flow = StateObject(wrappedValue: flow)
        _model = StateObject(wrappedValue: LoginModel(initialState: initialState, review: url == nil ? nil : flow.review))
    }

    var body: some View {
        Group {
            switch flow.route {
            case .login: login
            case .onboarding: OnboardingScreen(submit: flow.submit, openHome: flow.showProfile)
            case .profile: MemberProfileScreen(flow: flow)
            }
        }.task { await flow.restore() }
    }

    private var login: some View {
        GeometryReader { geometry in
            let bounds = geometry.frame(in: .global)
            LoginScreen(
                state: model.state,
                onSocialLogin: model.signIn,
                onReviewLogin: model.signInForReview,
                onDismissError: model.dismissError
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("login-content")
            #if DEBUG
            .accessibilityValue(ProcessInfo.processInfo.arguments.contains("--capture-layout")
                ? NSCoder.string(for: bounds) : "")
            #endif
        }
        .background(GColor.loginSky.ignoresSafeArea())
    }
}
