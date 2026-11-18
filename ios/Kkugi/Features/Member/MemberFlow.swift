import SwiftUI

@MainActor
final class MemberFlow: ObservableObject {
    enum Route { case login, onboarding, home, profile }
    @Published private(set) var route: Route = .login
    @Published var profile: MemberProfileResponse?
    let session: AuthSession?

    init(session: AuthSession) { self.session = session }

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

    func social(_ provider: LoginProvider) async throws {
        guard let session, let identity = SocialProvider(rawValue: provider.rawValue) else { throw URLError(.badURL) }
        let token = try await SocialSignIn.token(for: provider)
        let member = try await session.social(provider: identity, token: token)
        route = member.onboarded ? .home : .onboarding
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

    func dailyTarget() async throws -> Double {
        guard let session else { throw URLError(.userAuthenticationRequired) }
        let data = try await session.protectedRequest("api/v1/coaching-plan/me", method: "GET")
        let response = try JSONDecoder().decode(ApiResponseCoachingPlanResponse.self, from: data)
        guard response.success == true, let plan = response.data else { throw URLError(.badServerResponse) }
        return plan.targetKcal
    }

    func loadProfile() async throws {
        guard let session else { throw URLError(.userAuthenticationRequired) }
        let data = try await session.protectedRequest("api/v1/members/me/profile", method: "GET")
        profile = try decodeProfile(data)
    }

    func updateProfile(_ request: ProfileUpdateRequest) async throws {
        guard let session else { throw URLError(.userAuthenticationRequired) }
        let data = try await session.protectedRequest("api/v1/members/me/profile", method: "PUT",
                                                      body: JSONEncoder().encode(request))
        profile = try decodeProfile(data)
    }

    private func decodeProfile(_ data: Data) throws -> MemberProfileResponse {
        let envelope = try JSONDecoder().decode(ApiResponseMemberProfileResponse.self, from: data)
        guard envelope.success == true, let profile = envelope.data else { throw URLError(.badServerResponse) }
        return profile
    }

    func withdraw() async throws {
        guard let session else { throw URLError(.userAuthenticationRequired) }
        try await session.withdraw()
        profile = nil
        route = .login
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
    @State private var editing = false
    @State private var confirmingWithdrawal = false
    @State private var withdrawing = false
    var body: some View {
        List {
            Button("홈으로", action: flow.showHome)
            if let profile = flow.profile {
                Button("프로필 수정") { editing = true }
                Text(profile.nickname)
                LabeledContent("생년월일", value: profile.birthDate)
                LabeledContent("키", value: "\(profile.heightCm) cm")
            }
            if !message.isEmpty { Text(message) }
            Button("다시 불러오기") { Task { await load() } }
            Button("로그아웃") {
                Task { do { try await flow.logout() } catch { message = "로그아웃하지 못했어요" } }
            }
            Button("회원 탈퇴", role: .destructive) { confirmingWithdrawal = true }
        }.disabled(withdrawing)
        .alert("꾸기를 탈퇴할까요?", isPresented: $confirmingWithdrawal) {
            Button("취소", role: .cancel) {}
            Button("탈퇴", role: .destructive) {
                Task {
                    guard !withdrawing else { return }
                    withdrawing = true
                    defer { withdrawing = false }
                    do { try await flow.withdraw() } catch { message = "탈퇴하지 못했어요. 다시 시도해 주세요" }
                }
            }
        } message: {
            Text("개인 데이터가 삭제되며, 같은 계정으로 다시 로그인하면 새 회원으로 시작합니다.")
        }
        .task { await load() }
        .sheet(isPresented: $editing) {
            if let profile = flow.profile { ProfileEditor(profile: profile, save: flow.updateProfile) }
        }
    }

    private func load() async {
        do { try await flow.loadProfile(); message = "" } catch { message = "프로필을 불러오지 못했어요" }
    }
}

private struct ProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: OnboardingDraft
    @State private var saving = false
    @State private var message = ""
    let save: (ProfileUpdateRequest) async throws -> Void

    init(profile: MemberProfileResponse, save: @escaping (ProfileUpdateRequest) async throws -> Void) {
        _draft = State(initialValue: OnboardingDraft(
            nickname: profile.nickname, goal: profile.healthGoal, gender: profile.gender,
            birthday: profile.birthDate.replacingOccurrences(of: "-", with: ""),
            height: NSDecimalNumber(decimal: profile.heightCm).stringValue, activity: profile.activityLevel))
        self.save = save
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("닉네임", text: $draft.nickname)
                TextField("생년월일 (YYYYMMDD)", text: $draft.birthday).keyboardType(.numberPad)
                TextField("키 (cm)", text: $draft.height).keyboardType(.decimalPad)
                Picker("건강 목표", selection: $draft.goal) {
                    Text("체중 감량").tag("LOSE")
                    Text("지금 체중 유지").tag("MAINTAIN")
                    Text("근력 키우기").tag("GAIN")
                }
                Picker("성별", selection: $draft.gender) {
                    Text("남성").tag("MALE")
                    Text("여성").tag("FEMALE")
                }
                Picker("활동량", selection: $draft.activity) {
                    Text("거의 앉아 있어요").tag("SEDENTARY")
                    Text("가볍게 움직여요").tag("LIGHT")
                    Text("보통이에요").tag("MODERATE")
                    Text("활동적이에요").tag("ACTIVE")
                    Text("매우 활동적이에요").tag("VERY_ACTIVE")
                }
                if !message.isEmpty { Text(message) }
            }
            .navigationTitle("프로필 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { Task { await submit() } } }
            }
            .disabled(saving)
        }.interactiveDismissDisabled(saving)
    }

    @MainActor private func submit() async {
        guard !saving else { return }
        guard let nickname = draft.normalizedNickname else { message = "닉네임을 2자 이상 12자 이하로 입력해 주세요"; return }
        guard let date = draft.birthDate(today: Date()) else { message = "생년월일과 만 14세 이상 여부를 확인해 주세요"; return }
        guard let height = OnboardingDraft.measure(draft.height, range: 100...250) else {
            message = "키는 100~250cm로 입력해 주세요"
            return
        }
        saving = true
        defer { saving = false }
        do {
            try await save(ProfileUpdateRequest(nickname: nickname, healthGoal: draft.goal, gender: draft.gender,
                                                birthDate: date, heightCm: height, activityLevel: draft.activity))
            dismiss()
        } catch { message = "저장하지 못했어요. 다시 시도해 주세요" }
    }
}
