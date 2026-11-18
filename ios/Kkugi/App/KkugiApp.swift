import SwiftUI

@main
struct KkugiApp: App {
    @UIApplicationDelegateAdaptor(PushRegistration.self) private var push
    var body: some Scene {
        WindowGroup {
            LoginRoot()
                .environmentObject(push)
                .preferredColorScheme(.light)
        }
    }
}

struct LoginRoot: View {
    @EnvironmentObject private var push: PushRegistration
    @State private var inboxShown = false
    @State private var homeIdentity = UUID()
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
        let flow: MemberFlow
        #if DEBUG
        if let fixture = ProcessInfo.processInfo.environment["KKUGI_UI_FIXTURE"],
           ["home", "onboarding"].contains(fixture) {
            do { flow = try AppUIFixture.flow(onboarded: fixture == "home") }
            catch { preconditionFailure("UI fixture setup failed") }
        } else { flow = MemberFlow(baseURL: url) }
        #else
        flow = MemberFlow(baseURL: url)
        #endif
        _flow = StateObject(wrappedValue: flow)
        let model: LoginModel
        if url != nil {
            model = LoginModel(initialState: initialState, social: flow.social, review: { login, password in
                try await flow.review(login, password)
            })
        } else {
            model = LoginModel(initialState: initialState)
        }
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        Group {
            switch flow.route {
            case .login: login
            case .onboarding: OnboardingScreen(submit: flow.submit, openHome: flow.showHome, dailyTarget: flow.dailyTarget)
            case .home:
                if let session = flow.session { HomeScreen(session: session, profile: flow.showProfile).id(homeIdentity) }
            case .profile: MemberProfileScreen(flow: flow)
            }
        }.task { await flow.restore() }
        .task { await flow.observeExpiry() }
        .task(id: flow.route) {
            await push.attach(flow.session)
            openPendingNotification()
        }
        .onChange(of: push.openedInbox) { _, _ in openPendingNotification() }
        .sheet(isPresented: $inboxShown) {
            if let session = flow.session { NavigationStack { NotificationInbox(session: session) } }
        }
        .onOpenURL { url in
            if url.scheme == "kkugi", url.host == "home" {
                Task {
                    guard let member = try? await flow.session?.current(), member.onboarded else { return }
                    homeIdentity = UUID()
                    flow.showHome()
                }
            } else { SocialSignIn.handle(url) }
        }
    }

    private func openPendingNotification() {
        guard push.openedInbox != nil else { return }
        if flow.route == .home || flow.route == .profile {
            inboxShown = true
            push.consumeInbox()
        }
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
