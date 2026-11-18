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
        VStack {
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
            TextField("질문을 입력해 주세요", text: $model.question, axis: .vertical)
                .lineLimit(1...5).textFieldStyle(.roundedBorder)
            if model.active == nil {
                Button("질문 보내기") { model.send(using: session) }
                    .disabled(!(1...1000).contains(model.question.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count))
            } else { Button("답변 중단") { model.cancel() } }
        }.padding(G.gutter).navigationTitle("꾸기에게 묻기").onDisappear { model.cancel() }
    }
}
