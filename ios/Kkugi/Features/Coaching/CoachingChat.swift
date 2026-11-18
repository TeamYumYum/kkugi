import SwiftUI

private struct ChatTurn: Identifiable {
    let id = UUID()
    let question: String
    var text = ""
    var citations: [NutritionChatCitation] = []
    var messageID: String?
    var complete = false
    var receivedAnswer = false
    var failure = ""
}

@MainActor
private final class CoachingConversation: ObservableObject {
    @Published var question = ""
    @Published var turns: [ChatTurn] = []
    @Published var active: UUID?
    private var task: Task<Void, Never>?

    func send(using session: AuthSession) {
        let input = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard active == nil, (1...1000).contains(input.unicodeScalars.count) else { return }
        let previous = turns.last(where: { $0.complete })?.question
        let turn = ChatTurn(question: input)
        active = turn.id
        turns.append(turn)
        question = ""
        task = Task {
            do {
                let body = try JSONEncoder().encode(PersonalChatRequest(question: input, previousQuestion: previous))
                try await session.readEvents("api/v2/coaching/chat/stream", body: body) { name, json in
                    try await self.apply(name: name, json: json, id: turn.id)
                }
            } catch {
                if active == turn.id, let i = turns.firstIndex(where: { $0.id == turn.id }) {
                    turns[i].failure = "답변을 받지 못했어요. 다시 질문해 주세요"
                }
            }
            if active == turn.id { active = nil; task = nil }
        }
    }

    private func apply(name: String, json: String, id: UUID) throws -> Bool {
        guard active == id, let index = turns.firstIndex(where: { $0.id == id }) else { throw CancellationError() }
        let event = try JSONDecoder().decode(PersonalChatEvent.self, from: Data(json.utf8))
        if let expected = turns[index].messageID, event.messageId != expected { throw URLError(.badServerResponse) }
        turns[index].messageID = event.messageId
        switch name {
        case "answer":
            guard !turns[index].receivedAnswer, event.seq == 1, let answer = event.text, let sources = event.citations else {
                throw URLError(.badServerResponse)
            }
            turns[index].receivedAnswer = true
            turns[index].text = answer
            var ids = Set<String>()
            turns[index].citations = sources.filter { ids.insert($0.evidenceId).inserted }
            return false
        case "done":
            guard let status = event.status, ["answered", "out_of_scope", "insufficient_evidence"].contains(status),
                  status != "answered" || turns[index].receivedAnswer else { throw URLError(.badServerResponse) }
            if let extra = event.clarification, !extra.isEmpty {
                turns[index].text += (turns[index].text.isEmpty ? "" : "\n") + extra
            }
            if turns[index].text.isEmpty { turns[index].text = "답변에 필요한 자료가 부족해요" }
            turns[index].complete = true
            return true
        case "error":
            turns[index].failure = event.message ?? "코칭 답변을 받지 못했어요"
            return true
        default: throw URLError(.cannotParseResponse)
        }
    }

    func cancel() {
        if let active, let i = turns.firstIndex(where: { $0.id == active }) { turns[i].failure = "응답을 중단했어요" }
        active = nil
        task?.cancel()
        task = nil
    }
}

struct CoachingChat: View {
    let session: AuthSession
    @StateObject private var model = CoachingConversation()

    var body: some View {
        VStack(spacing: G.small) {
            if model.turns.isEmpty {
                GeometryReader { bounds in
                    ScrollView {
                        VStack(spacing: G.small) {
                            ArtImage(asset: .wave).scaledToFit().frame(width: G.dp(104), height: G.dp(104))
                                .accessibilityHidden(true)
                            GText(text: "안녕하세요, 꾸기예요", size: 22, weight: 700)
                            GText(text: "식단과 운동 기록을 함께 살펴볼게요", color: GColor.muted)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: G.small), GridItem(.flexible())], spacing: G.small) {
                                ForEach(suggestions.indices, id: \.self) { i in
                                    let suggestion = suggestions[i]
                                    Button {
                                        model.question = suggestion.1
                                        model.send(using: session)
                                    } label: {
                                        VStack(alignment: .leading, spacing: G.dp(4)) {
                                            GText(text: suggestion.0, size: 11, color: Color(hex: 0x2E6DB4))
                                            GText(text: suggestion.1, weight: 700)
                                        }.frame(maxWidth: .infinity, minHeight: G.dp(56), alignment: .topLeading)
                                            .padding(G.gap).background(.white, in: RoundedRectangle(cornerRadius: G.dp(16)))
                                    }.buttonStyle(.plain).accessibilityLabel(suggestion.1)
                                }
                            }.padding(.top, G.dp(16))
                            GText(text: "이 화면을 닫으면 대화가 사라져요.", size: 11, color: GColor.muted)
                        }.padding(.vertical, G.gap).frame(minHeight: bounds.size.height)
                    }
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: G.gap) {
                            ForEach(model.turns) { turn in
                                VStack(alignment: .leading, spacing: G.small) {
                                    GText(text: turn.question, weight: 700)
                                    if !turn.text.isEmpty { Text(turn.text).textSelection(.enabled) }
                                    ForEach(turn.citations, id: \.evidenceId) { citation in
                                        DisclosureGroup(citation.title) {
                                            Text(citation.quote)
                                            if let url = URL(string: citation.sourceUrl), url.scheme == "https" {
                                                Link("출처 열기", destination: url)
                                            }
                                        }
                                    }
                                    if !turn.failure.isEmpty { Text(turn.failure) }
                                    if model.active == turn.id && !turn.receivedAnswer { ProgressView() }
                                }.id(turn.id)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.onChange(of: model.turns.count) { _, _ in
                        if let id = model.turns.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }
            HStack {
                TextField("무엇이든 물어보세요", text: $model.question, axis: .vertical)
                    .lineLimit(1...5).textFieldStyle(.plain)
                if model.active == nil {
                    Button { model.send(using: session) } label: {
                        Image(systemName: "paperplane").frame(width: G.dp(32), height: G.dp(32)).background(Color(hex: 0xF0F2F5), in: Circle())
                    }.accessibilityLabel("질문 보내기")
                        .disabled(!(1...1000).contains(model.question.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count))
                } else { Button("답변 중단") { model.cancel() } }
            }.padding(.leading, G.dp(16)).padding(.trailing, G.dp(6)).padding(.vertical, G.dp(5))
                .background(.white, in: Capsule()).overlay { Capsule().strokeBorder(GColor.outline) }
        }.padding(.horizontal, G.gutter).padding(.bottom, G.small).background(Color(hex: 0xF5F7FA))
            .navigationTitle("꾸기에게 묻기").navigationBarTitleDisplayMode(.inline).onDisappear { model.cancel() }
    }

    private let suggestions = [
        ("오늘 기록", "오늘 단백질 충분히 먹었어요?"), ("오늘 기록", "오늘 남은 칼로리 알려 줘요"),
        ("지난주", "지난주 식단은 어땠어요?"), ("영양 상식", "운동 뒤에는 뭘 먹으면 좋아요?")
    ]
}
