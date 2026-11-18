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

struct ManualMealForm: View {
    let session: AuthSession
    let saved: () -> Void
    let fromRecommendation: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var kind = "LUNCH"
    @State private var names = ""
    @State private var foods: [Portion] = []
    @State private var searching = false
    @State private var scanning = false
    @State private var recognition: MealPhotoRecognitionResponse?
    @State private var ranks: [Int: Int] = [:]
    @State private var id = UUID()
    @State private var revision = 1
    @State private var previousBody: Data?
    @State private var busy = false
    @State private var error = ""

    init(session: AuthSession, date: Date, recommendation: [LastMealFood] = [], saved: @escaping () -> Void) {
        self.session = session
        self.saved = saved
        fromRecommendation = !recommendation.isEmpty
        _foods = State(initialValue: recommendation.map { item in
            Portion(food: FoodResponse(id: item.foodId, name: item.foodName, nutritionPer100g: item.nutritionPer100g,
                                      servingGrams: item.grams, owned: false), grams: String(item.grams))
        })
        _kind = State(initialValue: recommendation.isEmpty ? "LUNCH" : "DINNER")
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
                Section("식사 사진") {
                    Button(recognition == nil ? "사진으로 음식 인식" : "사진 다시 선택") { scanning = true }
                    if let recognition {
                        if recognition.regions.isEmpty { Text("사진에 나온 음식을 직접 추가해 주세요") }
                        ForEach(recognition.regions, id: \.regionNo) { region in
                            Picker("영역 \(region.regionNo)", selection: Binding(
                                get: { ranks[region.regionNo] ?? 0 },
                                set: { ranks[region.regionNo] = $0 }
                            )) {
                                Text("선택하지 않음").tag(0)
                                ForEach(region.candidates, id: \.rank) { candidate in
                                    Text("\(candidate.foodName) · \(candidate.grams)g").tag(candidate.rank)
                                }
                            }
                        }
                    }
                }
                Section("음식 목록") {
                    Button("음식 검색") { searching = true }
                    ForEach($foods) { $portion in
                        VStack(alignment: .leading) {
                            Text(portion.food.name)
                            TextField("섭취량 (g)", text: $portion.grams).keyboardType(.numberPad)
                            Button("목록에서 빼기") { foods.removeAll { $0.id == portion.id } }
                        }
                    }
                }
                Section("목록에 없는 음식 (한 줄에 하나)") { TextEditor(text: $names) }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
                Button("저장") { Task { await save() } }
                    .disabled(!ranks.values.contains(where: { $0 > 0 }) && foods.isEmpty && names.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.disabled(busy)
            .navigationTitle("직접 입력")
            .toolbar { Button("취소") { dismiss() }.disabled(busy) }
        }.interactiveDismissDisabled(busy)
        .sheet(isPresented: $scanning) {
            MealPhotoPicker(session: session) { result in
                recognition = result
                ranks = Dictionary(uniqueKeysWithValues: result.regions.map { ($0.regionNo, $0.candidates.first?.rank ?? 0) })
                scanning = false
            }
        }
        .sheet(isPresented: $searching) {
            FoodSearch(session: session) { food in
                foods.append(Portion(food: food, grams: String(food.servingGrams ?? 100)))
                searching = false
            }
        }
    }

    @MainActor private func save() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let unlisted = names.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard unlisted.allSatisfy({ $0.count <= 50 }) else { error = "음식 이름은 50자 이하로 입력해 주세요"; return }
        var items = unlisted.map { MealItemRequest(candidateRegionNo: nil, candidateRank: nil, foodId: nil, grams: nil, foodName: $0) }
        for food in foods {
            guard let grams = Int(food.grams), (1...5000).contains(grams) else {
                error = "섭취량은 1~5000g 사이 정수로 입력해 주세요"
                return
            }
            items.append(MealItemRequest(candidateRegionNo: nil, candidateRank: nil, foodId: food.food.id, grams: grams, foodName: nil))
        }
        for region in recognition?.regions ?? [] {
            guard let candidate = region.candidates.first(where: { $0.rank == ranks[region.regionNo] }) else { continue }
            items.append(MealItemRequest(candidateRegionNo: region.regionNo, candidateRank: candidate.rank,
                foodId: candidate.foodId, grams: candidate.foodId == nil ? nil : candidate.grams,
                foodName: candidate.foodId == nil ? candidate.foodName : nil))
        }
        guard !items.isEmpty else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            func body(_ rev: Int) throws -> Data {
                try encoder.encode(MealSaveRequest(clientUuid: id.uuidString, clientRevision: rev,
                    eatenAt: ISO8601DateFormatter().string(from: date), mealType: kind, photoRecognitionId: recognition?.recognitionId,
                    items: items, fromLastMealCard: fromRecommendation))
            }
            let signature = try body(0)
            if let previousBody, signature != previousBody { revision += 1 }
            previousBody = signature
            _ = try await session.protectedRequest("api/v1/meals", method: "POST", body: body(revision))
            saved()
        } catch { self.error = "식사를 저장하지 못했어요. 다시 시도해 주세요" }
    }
}

private struct Portion: Identifiable {
    let id = UUID()
    let food: FoodResponse
    var grams: String
}

private struct FoodSearch: View {
    let session: AuthSession
    let select: (FoodResponse) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var results: [FoodResponse] = []
    @State private var nextPage: Int?
    @State private var message = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            List {
                TextField("음식 이름이나 업체명", text: $keyword)
                    .onChange(of: keyword) { _, _ in results = []; nextPage = nil; message = "" }
                Button("검색") { Task { await search(0) } }.disabled(busy || keyword.trimmingCharacters(in: .whitespaces).isEmpty)
                if busy { ProgressView() }
                if !message.isEmpty { Text(message) }
                ForEach(results, id: \.id) { food in
                    Button { select(food) } label: {
                        LabeledContent(food.name, value: "\(food.nutritionPer100g.kcal.formatted()) kcal / 100g")
                    }
                }
                if let nextPage { Button("더 보기") { Task { await search(nextPage) } }.disabled(busy) }
            }
            .navigationTitle("음식 검색")
            .toolbar { Button("닫기") { dismiss() } }
        }
    }

    @MainActor private func search(_ page: Int) async {
        guard !busy else { return }
        let input = keyword
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...50).contains(query.count) else { message = "검색어를 1~50자로 입력해 주세요"; return }
        busy = true
        defer { busy = false }
        do {
            let bytes = try await session.protectedRequest("api/v1/foods", method: "GET", query: [
                URLQueryItem(name: "keyword", value: query), URLQueryItem(name: "page", value: String(page))
            ])
            let response = try JSONDecoder().decode(ApiResponseFoodSearchResponse.self, from: bytes)
            guard response.success == true, let data = response.data else { throw URLError(.badServerResponse) }
            guard keyword == input else { return }
            let existing = Set(page == 0 ? [] : results.map(\.id))
            results = (page == 0 ? [] : results) + data.items.filter { !existing.contains($0.id) }
            nextPage = (data.page + 1) * data.size < data.totalElements ? data.page + 1 : nil
            message = results.isEmpty ? "검색 결과가 없어요" : ""
        } catch {
            if keyword == input { message = "음식을 검색하지 못했어요. 다시 시도해 주세요" }
        }
    }
}
