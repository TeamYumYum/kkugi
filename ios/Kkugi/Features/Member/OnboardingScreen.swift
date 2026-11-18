import SwiftUI

struct OnboardingScreen: View {
    let submit: (OnboardingDraft) async throws -> Void
    let openHome: () -> Void
    var dailyTarget: () async throws -> Double
    @State private var kcal: Double?
    @State private var targetFailed = false
    @State private var draft = OnboardingDraft()
    @State private var step = 1
    @State private var busy = false
    @State private var error = ""

    var body: some View {
        VStack(alignment: .leading, spacing: G.gap) {
            if step < 4 {
                HStack {
                    if step > 1 { Button("뒤로") { step -= 1; error = "" } }
                    Spacer()
                    GText(text: "\(step) / 3")
                }
                ProgressView(value: Double(step), total: 3)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: G.gap) {
                    switch step {
                    case 1:
                        HStack(spacing: G.gap) {
                            ArtImage(asset: .idle).scaledToFit()
                                .frame(width: G.dp(64), height: G.dp(64)).accessibilityHidden(true)
                            GText(text: "만나서 반가워요!\n뭐라고 부를까요?", size: 24, weight: 700)
                        }
                        TextField("닉네임", text: $draft.nickname)
                        GText(text: "2자 이상 12자 이하로 적어 주세요", color: GColor.muted)
                    case 2:
                        GText(text: "어떤 목표로\n시작할까요?", size: 24, weight: 700)
                        choices([("LOSE","체중 감량"),("MAINTAIN","지금 체중 유지"),("GAIN","근력 키우기")], $draft.goal)
                        GText(text: "주 몇 번 운동할지는 운동 탭에서 정해요", color: GColor.muted)
                    case 3:
                        GText(text: "몸 정보를 알려 주세요", size: 24, weight: 700)
                        choices([("MALE","남성"),("FEMALE","여성")], $draft.gender)
                        TextField("생년월일 (YYYYMMDD)", text: $draft.birthday).keyboardType(.numberPad)
                        TextField("키 (cm)", text: $draft.height).keyboardType(.decimalPad)
                        TextField("몸무게 (kg)", text: $draft.weight).keyboardType(.decimalPad)
                        GText(text: "평소 활동량", weight: 700)
                        choices([("SEDENTARY","거의 앉아 있어요"),("LIGHT","가볍게 움직여요"),("MODERATE","보통이에요"),("ACTIVE","활동적이에요"),("VERY_ACTIVE","매우 활동적이에요")], $draft.activity)
                        GText(text: "목표 칼로리를 계산하는 데만 써요", color: GColor.muted)
                    default:
                        ArtImage(asset: .heart).scaledToFit()
                            .frame(maxWidth: .infinity).frame(height: G.dp(240))
                            .accessibilityHidden(true)
                        GText(text: "\(draft.normalizedNickname ?? draft.nickname)님, 꾸기를 만났어요!", size: 24, weight: 700)
                        VStack(alignment: .leading, spacing: G.small) {
                            GText(text: "하루 목표", color: GColor.muted)
                            if let kcal { GText(text: "\(kcal.formatted())kcal", size: 24, weight: 700) }
                            else if targetFailed {
                                Button("하루 목표 다시 불러오기") { Task { await loadTarget() } }
                            } else { Text("계산 중") }
                        }.task { await loadTarget() }
                    }
                    if !error.isEmpty { Text(error).foregroundStyle(.red) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { Task { await next() } } label: {
                Text(busy ? "저장하는 중" : step == 4 ? "홈으로" : step == 3 ? "완료" : "다음").foregroundStyle(.white)
            }.buttonStyle(GButtonStyle(background: GColor.text, outline: false))
        }
        .disabled(busy)
        .textFieldStyle(.roundedBorder)
        .padding(G.gutter)
    }

    @MainActor private func loadTarget() async {
        targetFailed = false
        do { kcal = try await dailyTarget() } catch { targetFailed = true }
    }

    private func choices(_ options: [(String, String)], _ selection: Binding<String>) -> some View {
        ForEach(options.indices, id: \.self) { index in
            let option = options[index]
            Button { selection.wrappedValue = option.0 } label: {
                HStack { GText(text: option.1); Spacer(); Image(systemName: selection.wrappedValue == option.0 ? "checkmark.circle.fill" : "circle") }
                    .padding(G.small)
            }.accessibilityAddTraits(selection.wrappedValue == option.0 ? .isSelected : [])
        }
    }

    @MainActor private func next() async {
        guard !busy else { return }
        error = ""
        switch step {
        case 1:
            guard draft.normalizedNickname != nil else { error = "닉네임을 2자 이상 12자 이하로 입력해 주세요"; return }
        case 2:
            guard !draft.goal.isEmpty else { error = "건강 목표를 골라 주세요"; return }
        case 3:
            guard !draft.gender.isEmpty else { error = "성별을 골라 주세요"; return }
            guard draft.birthDate(today: Date()) != nil else { error = "생년월일과 만 14세 이상 여부를 확인해 주세요"; return }
            guard OnboardingDraft.measure(draft.height, range: 100...250) != nil else { error = "키는 100~250cm로 입력해 주세요"; return }
            guard OnboardingDraft.measure(draft.weight, range: 20...300) != nil else { error = "몸무게는 20~300kg으로 입력해 주세요"; return }
            guard !draft.activity.isEmpty else { error = "하루 활동량을 골라 주세요"; return }
            busy = true
            defer { busy = false }
            do { try await submit(draft) } catch { self.error = "저장하지 못했어요. 다시 시도해 주세요"; return }
        default: openHome(); return
        }
        step += 1
    }
}
