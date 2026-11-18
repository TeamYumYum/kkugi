import SwiftUI

struct GrowthScreen: View {
    let session: AuthSession
    @State private var summary: GrowthSummaryResponse?
    @State private var failure = false

    var body: some View {
        List {
            NavigationLink("주간 리포트") { LatestWeeklyReport(session: session) }
            if failure { Button("성장 기록 다시 불러오기") { Task { await load() } } }
            if let summary {
                if !summary.started { Text("아직 성장 기록이 없어요") }
                if let start = summary.startedOn { LabeledContent("기록 시작일", value: start) }
                Section("식단 연속 기록") {
                    LabeledContent("현재", value: "\(summary.diet.currentDays)일")
                    LabeledContent("최장", value: "\(summary.diet.longestDays)일")
                    NavigationLink("날짜별 식단 기록") {
                        List(summary.path.days, id: \.date) { day in
                            LabeledContent(day.date, value: achievement(day.dietAchieved))
                        }.navigationTitle("날짜별 식단 기록")
                    }
                }
                Section("운동 연속 기록") {
                    LabeledContent("현재", value: "\(summary.workout.currentWeeks)주")
                    LabeledContent("최장", value: "\(summary.workout.longestWeeks)주")
                    NavigationLink("주간 목표 달성 기록") {
                        List(summary.path.weeklyGoals, id: \.weekStartDate) { week in
                            LabeledContent(week.weekStartDate, value: week.recovered ? "복구" : achievement(week.achieved))
                        }.navigationTitle("주간 목표 달성 기록")
                    }
                }
                NavigationLink("배지 모음") {
                    List(summary.badges, id: \.code) { badge in
                        VStack(alignment: .leading) {
                            Label(badge.name, systemImage: badge.earnedAt == nil ? "lock" : "medal")
                            Text(badge.description)
                            if let date = badge.earnedAt { Text(String(date.prefix(10)) + " 획득") }
                        }
                    }.navigationTitle("배지 모음")
                }
            } else if !failure { ProgressView() }
        }.navigationTitle("성장").task { await load() }.refreshable { await load() }
    }

    private func achievement(_ value: Bool?) -> String {
        value.map { $0 ? "달성" : "미달성" } ?? "집계 전"
    }

    @MainActor private func load() async {
        do {
            let data = try await session.protectedRequest("api/v1/growth/me", method: "GET")
            let response = try JSONDecoder().decode(ApiResponseGrowthSummaryResponse.self, from: data)
            guard response.success == true, let result = response.data else { throw URLError(.badServerResponse) }
            summary = result
            failure = false
        } catch { failure = true }
    }
}
