import SwiftUI

@MainActor
final class MemberFlow: ObservableObject {
    enum Route { case login, onboarding, home, profile }
    @Published private(set) var route: Route = .login
    @Published var profile: MemberProfileResponse?
    let session: AuthSession?

    init(baseURL: URL?) {
        session = baseURL.map {
            AuthSession(api: AuthClient(baseURL: $0, session: URLSession(configuration: .ephemeral)),
                        vault: SessionVault(service: "com.kkugi.ios.auth"))
        }
    }

    func restore() async {
        guard let item = try? await session?.current() else { return }
        route = item.onboarded ? .home : .onboarding
    }

    func review(_ login: String, _ password: String) async throws {
        guard let session else { throw URLError(.badURL) }
        let member = try await session.review(loginID: login, password: password)
        route = member.onboarded ? .home : .onboarding
    }

    func submit(_ draft: OnboardingDraft) async throws {
        guard let session, let item = try await session.current(),
              let nickname = draft.normalizedNickname, let birthday = draft.birthDate(today: Date()),
              let height = OnboardingDraft.measure(draft.height, range: 100...250),
              let weight = OnboardingDraft.measure(draft.weight, range: 20...300) else { throw URLError(.badURL) }
        let request = OnboardingRequest(nickname: nickname, healthGoal: draft.goal, gender: draft.gender,
                                       birthDate: birthday, heightCm: height, weightKg: weight, activityLevel: draft.activity)
        let data = try await session.protectedRequest("api/v1/members/me/onboarding", method: "POST",
                                                      body: JSONEncoder().encode(request))
        let saved = try decodeProfile(data)
        try await session.markOnboarded(for: item.sessionID)
        profile = saved
    }

    func showHome() { route = .home }

    func showProfile() { route = .profile }

    func loadProfile() async throws {
        guard let session else { throw URLError(.userAuthenticationRequired) }
        let data = try await session.protectedRequest("api/v1/members/me/profile", method: "GET")
        profile = try decodeProfile(data)
    }

    private func decodeProfile(_ data: Data) throws -> MemberProfileResponse {
        let envelope = try JSONDecoder().decode(ApiResponseMemberProfileResponse.self, from: data)
        guard envelope.success == true, let profile = envelope.data else { throw URLError(.badServerResponse) }
        return profile
    }

    func logout() async throws {
        try await session?.logout()
        profile = nil
        route = .login
    }
}

struct MemberProfileScreen: View {
    @ObservedObject var flow: MemberFlow
    @State private var message = ""
    var body: some View {
        List {
            Button("홈으로", action: flow.showHome)
            if let profile = flow.profile {
                Text(profile.nickname)
                LabeledContent("생년월일", value: profile.birthDate)
                LabeledContent("키", value: "\(profile.heightCm) cm")
            }
            if !message.isEmpty { Text(message) }
            Button("다시 불러오기") { Task { await load() } }
            Button("로그아웃") {
                Task { do { try await flow.logout() } catch { message = "로그아웃하지 못했어요" } }
            }
        }.task { await load() }
    }

    private func load() async {
        do { try await flow.loadProfile(); message = "" } catch { message = "프로필을 불러오지 못했어요" }
    }
}
