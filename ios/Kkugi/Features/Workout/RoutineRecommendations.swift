import SwiftUI

struct RoutineRecommendations: View {
    let session: AuthSession
    let weeklyCount: Int
    let saved: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [RecommendedRoutineResponse] = []
    @State private var usage: AiRoutineRecommendationUsageResponse?
    @State private var selected: Set<String> = []
    @State private var busy = false
    @State private var message = ""
    private let path = "api/v1/routine-recommendations"

    var body: some View {
        VStack(spacing: G.gap) {
            ScrollView {
                VStack(alignment: .leading, spacing: G.gap) {
                    NavigationLink {
                        RoutineSurvey(session: session, weeklyCount: weeklyCount, usage: usage, saved: saved)
                    } label: {
                        HStack {
                            GText(text: "AI로 추천받기", weight: 700)
                            Spacer()
                            if let usage { GText(text: "이번 주 \(usage.remainingCount)번 남음", color: GColor.muted) }
                            Image(systemName: "chevron.right")
                        }.padding(G.gap).background(.white, in: RoundedRectangle(cornerRadius: G.dp(14)))
                    }.accessibilityLabel("AI로 추천받기")
                    RecommendationCards(routines: groups, selected: $selected)
                    if !message.isEmpty { GText(text: message) }
                }
            }
            Button("루틴 \(selected.count)개 가져오기") { Task { await save() } }
                .buttonStyle(GButtonStyle(background: GColor.text, outline: false)).foregroundStyle(.white)
                .disabled(selected.isEmpty || busy)
        }.padding(G.gutter).background(Color(hex: 0xF5F7FA)).navigationTitle("루틴 추천")
            .navigationBarTitleDisplayMode(.inline).task { await load() }
    }

    @MainActor private func load() async {
        do {
            var result: [RecommendedRoutineResponse] = []
            for style in ["FULL_BODY", "SPLIT"] {
                let data = try await session.protectedRequest(path, method: "GET", query: [
                    URLQueryItem(name: "timesPerWeek", value: String(weeklyCount)), URLQueryItem(name: "style", value: style)])
                let envelope = try JSONDecoder().decode(ApiResponseRoutineRecommendationResponse.self, from: data)
                guard envelope.success == true, let group = envelope.data else { throw URLError(.badServerResponse) }
                result.append(contentsOf: group.routines)
            }
            groups = result
            if selected.isEmpty, let first = groups.first { selected = [first.key] }
            message = groups.isEmpty ? "추천할 루틴이 없어요" : ""
        } catch { message = "추천 루틴을 불러오지 못했어요" }
        if let data = try? await session.protectedRequest(path + "/ai", method: "GET"),
           let reply = try? JSONDecoder().decode(ApiResponseAiRoutineRecommendationUsageResponse.self, from: data),
           reply.success == true { usage = reply.data }
    }

    @MainActor private func save() async {
        guard !busy, !selected.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            try await RecommendationCards.save(selected, from: groups, path: path + "/routines", session: session)
            await saved()
            dismiss()
        } catch { message = "저장 결과를 확인할 수 없어요. 내 루틴을 확인해 주세요." }
    }
}

private struct RecommendationCards: View {
    let routines: [RecommendedRoutineResponse]
    @Binding var selected: Set<String>

    var body: some View {
        GText(text: "가져올 루틴을 골라요", size: 18, weight: 700)
        ForEach(routines, id: \.key) { routine in
            Button {
                if selected.contains(routine.key) { selected.remove(routine.key) } else { selected.insert(routine.key) }
            } label: {
                VStack(alignment: .leading, spacing: G.small) {
                    HStack {
                        Image(systemName: selected.contains(routine.key) ? "checkmark.square.fill" : "square")
                        GText(text: routine.name, weight: 700)
                        GText(text: "\(routine.exercises.count)종목", size: 11, color: GColor.muted)
                    }
                    GText(text: routine.exercises.map(\.nameKo).joined(separator: " · "), size: 12)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(G.gap)
                    .background(.white, in: RoundedRectangle(cornerRadius: G.dp(16)))
                    .overlay { if selected.contains(routine.key) { RoundedRectangle(cornerRadius: G.dp(16)).strokeBorder(GColor.text, lineWidth: 2) } }
            }.buttonStyle(.plain).accessibilityAddTraits(selected.contains(routine.key) ? .isSelected : [])
        }
    }

    static func save(_ selected: Set<String>, from routines: [RecommendedRoutineResponse], path: String, session: AuthSession) async throws {
        let payload = routines.filter { selected.contains($0.key) }.map { routine in
            RecommendedRoutineSaveRequest(key: routine.key, exercises: routine.exercises.map {
                RecommendedExerciseSaveRequest(slot: $0.slot, exerciseId: $0.exerciseId)
            })
        }
        guard !payload.isEmpty else { throw CocoaError(.coderInvalidValue) }
        let body = try JSONEncoder().encode(RoutineRecommendationSaveRequest(routines: payload))
        let bytes = try await session.protectedRequest(path, method: "POST", body: body)
        let response = try JSONDecoder().decode(ApiResponseRoutineListResponse.self, from: bytes)
        guard response.success == true, response.data != nil else { throw URLError(.badServerResponse) }
    }
}

private struct RoutineSurvey: View {
    let session: AuthSession
    let weeklyCount: Int
    let usage: AiRoutineRecommendationUsageResponse?
    let saved: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var goal = ""
    @State private var style = "ANY"
    @State private var duration = ""
    @State private var experience = ""
    @State private var goalNote = ""
    @State private var discomfortNote = ""
    @State private var freeText = ""
    @State private var weight = ""
    @State private var focus: Set<String> = []
    @State private var excluded: Set<String> = []
    @State private var discomfort: Set<String> = []
    @State private var result: AiRoutineRecommendationResponse?
    @State private var selected: Set<String> = []
    @State private var busy = false
    @State private var message = ""
    private let path = "api/v1/routine-recommendations/ai"
    private let parts = [("LOWER_BODY","하체"),("BACK","등"),("CHEST","가슴"),("SHOULDER","어깨"),("ARM","팔"),("CORE","코어"),("CARDIO","유산소")]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: G.gap) {
                if let result {
                    if result.needsMedicalNotice { GText(text: "불편한 곳이 있다면 운동하기 전에 의료진의 지시를 먼저 따라 주세요.") }
                    if let comment = result.comment { GText(text: comment) }
                    RecommendationCards(routines: result.routines, selected: $selected)
                    GText(text: "이번 주 AI 추천 \(result.remainingCount)번 남음", color: GColor.muted)
                    Button("루틴 \(selected.count)개 가져오기") { Task { await save(result) } }.disabled(selected.isEmpty)
                } else {
                    if let usage {
                        GText(text: "이번 주 \(usage.remainingCount)번 남음", color: GColor.muted)
                        ForEach(usage.recommendations, id: \.recommendationId) { previous in
                            Button("받은 추천 · " + String(previous.createdAt.prefix(10))) { Task { await fetch(previous.recommendationId) } }
                        }
                    }
                    menu("운동 목표", $goal, [("STRENGTH","근력"),("WEIGHT_LOSS","체중 감량"),("ENDURANCE","지구력"),("HEALTH","건강 관리"),("CUSTOM","직접 입력")])
                    if goal == "CUSTOM" { TextField("운동 목표 입력", text: $goalNote) }
                    menu("운동 방식", $style, [("ANY","상관없어요"),("FULL_BODY","전신"),("SPLIT","분할")])
                    menu("운동 시간", $duration, [("UP_TO_30","30분 이하"),("FROM_30_TO_45","30~45분"),("FROM_45_TO_60","45~60분"),("OVER_60","60분 초과")])
                    menu("운동 경험", $experience, [("NONE","없음"),("UNDER_6_MONTHS","6개월 미만"),("FROM_6_MONTHS_TO_2_YEARS","6개월~2년"),("OVER_2_YEARS","2년 초과")])
                    GText(text: "더 자세히 알려 주기", size: 18, weight: 700)
                    choices("집중할 부위", $focus, parts, blocked: excluded)
                    choices("빼고 싶은 부위", $excluded, parts, blocked: focus)
                    choices("통증이나 불편한 곳", $discomfort, [("NECK","목"),("SHOULDER","어깨"),("ELBOW","팔꿈치"),("WRIST","손목"),("LOWER_BACK","허리"),("KNEE","무릎"),("ANKLE","발목"),("CUSTOM","직접 입력")])
                    if discomfort.contains("CUSTOM") { TextField("불편한 곳 입력", text: $discomfortNote) }
                    TextField("자유 입력", text: $freeText, axis: .vertical)
                    TextField("현재 체중 (kg)", text: $weight).keyboardType(.decimalPad)
                    Button("추천받기") { Task { await fetch(nil) } }
                        .disabled(!valid || usage?.remainingCount == 0)
                }
                if busy { ProgressView() }
                if !message.isEmpty { GText(text: message) }
            }.padding(G.gutter)
        }.disabled(busy).background(Color(hex: 0xF5F7FA))
            .navigationTitle(result == nil ? "AI 추천" : "AI 추천 루틴").navigationBarTitleDisplayMode(.inline)
    }

    private var valid: Bool {
        !goal.isEmpty && !duration.isEmpty && !experience.isEmpty && freeText.count <= 200 &&
        (goal != "CUSTOM" || (1...30).contains(goalNote.trimmingCharacters(in: .whitespacesAndNewlines).count)) &&
        (!discomfort.contains("CUSTOM") || (1...30).contains(discomfortNote.trimmingCharacters(in: .whitespacesAndNewlines).count)) &&
        (weight.isEmpty || Double(weight).map { (20...300).contains($0) } == true)
    }

    private func menu(_ title: String, _ value: Binding<String>, _ options: [(String,String)]) -> some View {
        HStack {
            GText(text: title, weight: 700)
            Spacer()
            Picker(title, selection: value) {
                Text("선택").tag("")
                ForEach(options.indices, id: \.self) { i in Text(options[i].1).tag(options[i].0) }
            }
        }.padding(G.small).background(.white, in: RoundedRectangle(cornerRadius: G.dp(12)))
    }

    private func choices(_ title: String, _ selected: Binding<Set<String>>, _ options: [(String,String)], blocked: Set<String> = []) -> some View {
        DisclosureGroup(title) {
            ForEach(options.indices, id: \.self) { i in
                Toggle(options[i].1, isOn: Binding(get: { selected.wrappedValue.contains(options[i].0) }, set: { on in
                    if on { selected.wrappedValue.insert(options[i].0) } else { selected.wrappedValue.remove(options[i].0) }
                })).disabled(blocked.contains(options[i].0))
            }
        }
    }

    @MainActor private func fetch(_ id: Int?) async {
        guard !busy else { return }
        busy = true
        message = ""
        defer { busy = false }
        do {
            let bytes: Data
            if let id { bytes = try await session.protectedRequest(path + "/\(id)", method: "GET") }
            else {
                guard valid else { return }
                let form = AiRoutineRecommendationRequest(timesPerWeek: weeklyCount, style: style, goal: goal,
                    goalNote: goal == "CUSTOM" ? goalNote : nil, focusBodyParts: focus.sorted(), excludedBodyParts: excluded.sorted(),
                    discomfortAreas: discomfort.sorted(), discomfortNote: discomfort.contains("CUSTOM") ? discomfortNote : nil,
                    sessionLength: duration, experience: experience, freeText: freeText.isEmpty ? nil : freeText, weightKg: Double(weight))
                bytes = try await session.protectedRequest(path, method: "POST", body: JSONEncoder().encode(form))
            }
            let response = try JSONDecoder().decode(ApiResponseAiRoutineRecommendationResponse.self, from: bytes)
            guard response.success == true, let value = response.data else { throw URLError(.badServerResponse) }
            result = value
            selected = Set(value.routines.prefix(1).map(\.key))
        } catch { message = "추천 결과를 확인하지 못했어요. 받은 추천 목록을 확인해 주세요." }
    }

    @MainActor private func save(_ value: AiRoutineRecommendationResponse) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await RecommendationCards.save(selected, from: value.routines, path: path + "/\(value.recommendationId)/routines", session: session)
            await saved()
            dismiss()
        } catch { message = "저장 결과를 확인할 수 없어요. 내 루틴을 확인해 주세요." }
    }
}
