import SwiftUI

struct MealDiary: View {
    let session: AuthSession
    @State private var date = Date()
    @State private var day: DailyMealsResponse?
    @State private var failure = false
    @State private var adding = false
    @State private var selectedForRemoval: Int?
    @State private var showRemoval = false
    @State private var mutationError = ""

    private var dateKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var body: some View {
        List {
            DatePicker("날짜", selection: $date, displayedComponents: .date)
                .environment(\.timeZone, TimeZone(identifier: "Asia/Seoul")!)
            if !mutationError.isEmpty { Text(mutationError).foregroundStyle(.red) }
            if failure {
                Text("식사 기록을 불러오지 못했어요")
                Button("다시 시도") { Task { await load(dateKey) } }
            } else if let day {
                LabeledContent("총 섭취 열량", value: "\(day.totalNutrition.kcal.formatted()) kcal")
                if day.meals.isEmpty { Text("기록한 식사가 없어요") }
                ForEach(day.meals, id: \.id) { meal in
                    Section(["BREAKFAST":"아침", "LUNCH":"점심", "DINNER":"저녁", "SNACK":"간식"][meal.mealType] ?? meal.mealType) {
                        ForEach(meal.items.indices, id: \.self) { index in
                            let item = meal.items[index]
                            Text(item.foodName)
                        }
                        LabeledContent("열량", value: "\(meal.totalNutrition.kcal.formatted()) kcal")
                        Button("식사 삭제", role: .destructive) {
                            selectedForRemoval = meal.id
                            showRemoval = true
                        }
                    }
                }
            } else { ProgressView() }
        }
        .navigationTitle("식사 기록")
        .toolbar { Button("식사 추가") { adding = true } }
        .alert("이 식사 기록을 삭제할까요?", isPresented: $showRemoval) {
            Button("취소", role: .cancel) { selectedForRemoval = nil }
            Button("삭제", role: .destructive) {
                guard let id = selectedForRemoval else { return }
                selectedForRemoval = nil
                Task {
                    do {
                        _ = try await session.protectedRequest("api/v1/meals/\(id)", method: "DELETE")
                        mutationError = ""
                        await load(dateKey)
                    } catch { mutationError = "식사를 삭제하지 못했어요. 다시 시도해 주세요" }
                }
            }
        }
        .sheet(isPresented: $adding) {
            ManualMealForm(session: session, date: date) {
                adding = false
                Task { await load(dateKey) }
            }
        }
        .task(id: dateKey) { await load(dateKey) }
        .refreshable { await load(dateKey) }
    }

    @MainActor private func load(_ key: String) async {
        failure = false
        if day?.date != key { day = nil }
        do {
            let bytes = try await session.protectedRequest("api/v1/meals", method: "GET", query: [URLQueryItem(name: "date", value: key)])
            let envelope = try JSONDecoder().decode(ApiResponseDailyMealsResponse.self, from: bytes)
            guard envelope.success == true, let loaded = envelope.data, loaded.date == key else { throw URLError(.badServerResponse) }
            if !Task.isCancelled && dateKey == key { day = loaded }
        } catch {
            if !Task.isCancelled && dateKey == key { failure = true }
        }
    }
}

private struct ManualMealForm: View {
    let session: AuthSession
    let saved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var kind = "LUNCH"
    @State private var names = ""
    @State private var id = UUID()
    @State private var revision = 1
    @State private var previousBody: Data?
    @State private var busy = false
    @State private var error = ""

    init(session: AuthSession, date: Date, saved: @escaping () -> Void) {
        self.session = session
        self.saved = saved
        _date = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("식사 시각", selection: $date, in: ...Date())
                Picker("식사 구분", selection: $kind) {
                    Text("아침").tag("BREAKFAST"); Text("점심").tag("LUNCH")
                    Text("저녁").tag("DINNER"); Text("간식").tag("SNACK")
                }
                Section("음식 이름 (한 줄에 하나)") { TextEditor(text: $names) }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
                Button("저장") { Task { await save() } }
                    .disabled(names.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.disabled(busy)
            .navigationTitle("직접 입력")
            .toolbar { Button("취소") { dismiss() }.disabled(busy) }
        }.interactiveDismissDisabled(busy)
    }

    @MainActor private func save() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let items = names.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.map { MealItemRequest(candidateRegionNo: nil, candidateRank: nil, foodId: nil, grams: nil, foodName: $0) }
        guard !items.isEmpty else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            func body(_ rev: Int) throws -> Data {
                try encoder.encode(MealSaveRequest(clientUuid: id.uuidString, clientRevision: rev,
                    eatenAt: ISO8601DateFormatter().string(from: date), mealType: kind, photoRecognitionId: nil,
                    items: items, fromLastMealCard: false))
            }
            let signature = try body(0)
            if let previousBody, signature != previousBody { revision += 1 }
            previousBody = signature
            _ = try await session.protectedRequest("api/v1/meals", method: "POST", body: body(revision))
            saved()
        } catch { self.error = "식사를 저장하지 못했어요. 다시 시도해 주세요" }
    }
}
