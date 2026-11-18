import SwiftUI

struct MealDiary: View {
    let session: AuthSession
    @State private var date = Date()
    @State private var day: DailyMealsResponse?
    @State private var failure = false

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
                    }
                }
            } else { ProgressView() }
        }
        .navigationTitle("식사 기록")
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
