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
    private enum BodyField: String, Identifiable, CaseIterable {
        case birthday = "생년월일", height = "키", weight = "몸무게", activity = "평소 활동량"
        var id: Self { self }
    }
    @State private var editing: BodyField?
    private let activities = [
        ("SEDENTARY", "거의 앉아 있어요", "사무직, 운동은 거의 안 해요"),
        ("LIGHT", "가볍게 움직여요", "주 1~3회 가벼운 운동"),
        ("MODERATE", "보통이에요", "주 3~5회 중강도 운동"),
        ("ACTIVE", "활동적이에요", "주 6~7회 고강도 운동"),
        ("VERY_ACTIVE", "매우 활동적이에요", "하루 2회 운동이나 육체 노동")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: G.gap) {
                    if step < 4 {
                        HStack {
                            if step > 1 {
                                Button { step -= 1; error = "" } label: {
                                    Image(systemName: "chevron.left")
                                        .frame(width: G.dp(48), height: G.dp(48))
                                }.accessibilityLabel("뒤로")
                            }
                            Spacer()
                            GText(text: "\(step) / 3")
                        }
                        .frame(minHeight: G.dp(32))
                        .padding(.top, G.dp(6))
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(hex: 0xE3E8EE))
                                Capsule().fill(Color(hex: 0x5AA5F0))
                                    .frame(width: geometry.size.width * CGFloat(step) / 3)
                            }
                        }.frame(height: G.dp(4))
                    }
                    switch step {
                    case 1:
                        HStack(spacing: G.gap) {
                            ArtImage(asset: .idle).scaledToFit()
                                .frame(width: G.dp(64), height: G.dp(64)).accessibilityHidden(true)
                            GText(text: "만나서 반가워요!\n뭐라고 부를까요?", size: 24, weight: 700)
                        }
                        VStack(alignment: .leading, spacing: G.small) {
                            GText(text: "닉네임", size: 12, weight: 500, color: GColor.muted)
                            HStack {
                                TextField("", text: $draft.nickname)
                                    .accessibilityLabel("닉네임").textFieldStyle(.plain)
                                GText(text: "\(draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count)/12", color: GColor.muted)
                            }
                            .padding(.horizontal, G.dp(14)).padding(.vertical, G.dp(12))
                            .background(.white, in: RoundedRectangle(cornerRadius: G.dp(14)))
                            .overlay { RoundedRectangle(cornerRadius: G.dp(14)).strokeBorder(Color(hex: 0xE9ECEF), lineWidth: G.dp(1.5)) }
                            GText(text: "2자 이상 12자 이하로 적어 주세요", size: 12, color: GColor.muted)
                        }
                        GText(text: "나중에 마이에서 바꿀 수 있어요.", color: GColor.muted)
                    case 2:
                        GText(text: "어떤 목표로\n시작할까요?", size: 24, weight: 700)
                        choice("LOSE", "체중 감량", "천천히, 일주일에 0.5kg씩", $draft.goal)
                        choice("MAINTAIN", "지금 체중 유지", "먹은 만큼 움직이기", $draft.goal)
                        choice("GAIN", "근력 키우기", "단백질을 넉넉히, 루틴은 점진적으로", $draft.goal)
                        GText(text: "주 몇 번 운동할지는 운동 탭에서 정해요", color: GColor.muted)
                    case 3:
                        GText(text: "몸 정보를 알려 주세요", size: 24, weight: 700)
                        bodyCard
                        GText(text: "목표 칼로리를 계산하는 데만 써요", color: GColor.muted)
                    default:
                        ZStack {
                            EllipticalGradient(colors: [Color(hex: 0x26292E).opacity(0.14), .clear],
                                               startRadiusFraction: 0, endRadiusFraction: 0.5)
                                .frame(width: G.dp(240 * 0.68), height: G.dp(28))
                                .padding(.bottom, G.dp(30))
                                .frame(maxHeight: .infinity, alignment: .bottom)
                            ArtImage(asset: .heart).scaledToFit().padding(.bottom, G.dp(12))
                                .frame(width: G.dp(240), height: G.dp(240))
                        }.frame(maxWidth: .infinity).frame(height: G.dp(280)).accessibilityHidden(true)
                        GText(text: "\(draft.normalizedNickname ?? draft.nickname)님, 꾸기를 만났어요!", size: 24, weight: 700)
                        VStack(alignment: .leading, spacing: G.small) {
                            GText(text: "하루 목표", color: GColor.muted)
                            if let kcal { GText(text: "\(kcal.formatted())kcal", size: 24, weight: 800) }
                            else if targetFailed {
                                Button("하루 목표 다시 불러오기") { Task { await loadTarget() } }
                            } else { GText(text: "계산 중", size: 24, weight: 800) }
                            if let goal = ["LOSE": "체중 감량", "MAINTAIN": "지금 체중 유지", "GAIN": "근력 키우기"][draft.goal] {
                                GText(text: goal, color: Color(hex: 0x2E6DB4))
                            }
                        }
                        .padding(G.dp(14)).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: G.dp(16)))
                        .shadow(color: .black.opacity(0.05), radius: G.dp(1.5), y: G.dp(1))
                        .task { await loadTarget() }
                    }
                    if !error.isEmpty { Text(error).foregroundStyle(.red) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(G.gutter)
            }
            Button { Task { await next() } } label: {
                GText(text: busy ? "저장하는 중" : step == 4 ? "홈으로" : step == 3 ? "완료" : "다음", size: 15, weight: 700, color: .white)
            }.buttonStyle(GButtonStyle(background: Color(hex: 0x26292E), outline: false))
                .padding(.horizontal, G.gutter).padding(.vertical, G.small)
        }
        .disabled(busy)
        .textFieldStyle(.roundedBorder)
        .foregroundStyle(GColor.text)
        .background(Color(hex: 0xF5F7FA))
        .sheet(item: $editing) { field in
            VStack(alignment: .leading, spacing: G.gap) {
                GText(text: field.rawValue, size: 18, weight: 700)
                switch field {
                case .activity:
                    ScrollView {
                        ForEach(activities.indices, id: \.self) { index in
                            let item = activities[index]
                            choice(item.0, item.1, item.2, Binding(get: { draft.activity }, set: { draft.activity = $0; editing = nil }))
                        }
                    }
                case .birthday: TextField("생년월일 (YYYYMMDD)", text: $draft.birthday).keyboardType(.numberPad)
                case .height: TextField("키 (cm)", text: $draft.height).keyboardType(.decimalPad)
                case .weight: TextField("몸무게 (kg)", text: $draft.weight).keyboardType(.decimalPad)
                }
                if field != .activity { Button("확인") { editing = nil } }
            }.padding(G.gutter).textFieldStyle(.roundedBorder)
                .presentationDetents(field == .activity ? [.large] : [.medium])
        }
    }

    @MainActor private func loadTarget() async {
        targetFailed = false
        do { kcal = try await dailyTarget() } catch { targetFailed = true }
    }

    private func choice(_ value: String, _ title: String, _ description: String, _ selection: Binding<String>) -> some View {
        let selected = selection.wrappedValue == value
        let shape = RoundedRectangle(cornerRadius: G.dp(14), style: .circular)
        return Button { selection.wrappedValue = value } label: {
            HStack(spacing: G.dp(10)) {
                VStack(alignment: .leading, spacing: 0) {
                    GText(text: title, size: 14, weight: 700)
                    GText(text: description, size: 12, color: GColor.muted)
                }
                Spacer()
                ZStack {
                    if selected {
                        Circle().fill(Color(hex: 0x5AA5F0))
                        Image(systemName: "checkmark").foregroundStyle(.white)
                    } else {
                        Circle().strokeBorder(Color(hex: 0xCED4DA), lineWidth: G.dp(2))
                    }
                }.frame(width: G.dp(24), height: G.dp(24))
            }
            .padding(.horizontal, G.dp(14)).padding(.vertical, G.dp(13))
            .background(selected ? Color(hex: 0xE7F2FE) : Color(hex: 0xF0F2F5), in: shape)
            .overlay { if selected { shape.strokeBorder(Color(hex: 0x5AA5F0), lineWidth: G.dp(1.5)) } }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(description)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: G.gap) {
            GText(text: "성별", size: 12, weight: 700)
            HStack(spacing: G.small) {
                ForEach(["MALE", "FEMALE"], id: \.self) { value in
                    Button { draft.gender = value } label: {
                        GText(text: value == "MALE" ? "남성" : "여성", size: 12, weight: 700)
                            .padding(.horizontal, G.dp(12)).padding(.vertical, G.dp(7))
                            .background(Color(hex: value == draft.gender ? 0xE7F2FE : 0xF0F2F5), in: Capsule())
                    }.accessibilityAddTraits(value == draft.gender ? .isSelected : [])
                }
            }
            ForEach(BodyField.allCases) { field in
                Button { editing = field } label: {
                    HStack {
                        GText(text: field.rawValue, size: 12, weight: 700)
                        Spacer()
                        GText(text: bodyValue(field), color: GColor.muted)
                        Image(systemName: "chevron.right").foregroundStyle(GColor.muted)
                    }.frame(minHeight: G.dp(44)).contentShape(Rectangle())
                }
            }
        }.buttonStyle(.plain).padding(G.dp(14))
            .background(.white, in: RoundedRectangle(cornerRadius: G.dp(16)))
            .shadow(color: .black.opacity(0.05), radius: G.dp(1.5), y: G.dp(1))
    }

    private func bodyValue(_ field: BodyField) -> String {
        switch field {
        case .birthday: return draft.birthday.isEmpty ? "입력해 주세요" : draft.birthday
        case .height: return draft.height.isEmpty ? "입력해 주세요" : draft.height + "cm"
        case .weight: return draft.weight.isEmpty ? "입력해 주세요" : draft.weight + "kg"
        case .activity: return activities.first { $0.0 == draft.activity }?.1 ?? "골라 주세요"
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

#if DEBUG
extension OnboardingScreen {
    static func reference(step: Int) -> Self {
        var screen = Self(submit: { _ in }, openHome: {}, dailyTarget: { 1800 })
        screen._step = State(initialValue: step)
        if step == 4 {
            screen._draft = State(initialValue: OnboardingDraft(nickname: "꾸기", goal: "MAINTAIN"))
            screen._kcal = State(initialValue: 1800)
        }
        return screen
    }
}
#endif
