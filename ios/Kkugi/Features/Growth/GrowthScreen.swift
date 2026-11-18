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
                        }.gListCanvas().navigationTitle("날짜별 식단 기록")
                    }
                }
                Section("운동 연속 기록") {
                    LabeledContent("현재", value: "\(summary.workout.currentWeeks)주")
                    LabeledContent("최장", value: "\(summary.workout.longestWeeks)주")
                    NavigationLink("주간 목표 달성 기록") {
                        List(summary.path.weeklyGoals, id: \.weekStartDate) { week in
                            LabeledContent(week.weekStartDate, value: week.recovered ? "복구" : achievement(week.achieved))
                        }.gListCanvas().navigationTitle("주간 목표 달성 기록")
                    }
                }
                NavigationLink("배지 모음") {
                    BadgeCollection(badges: summary.badges)
                }
            } else if !failure { ProgressView() }
        }.gListCanvas().navigationTitle("성장").task { await load() }.refreshable { await load() }
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

private struct BadgeCollection: View {
    let badges: [GrowthBadgeResponse]
    private let order = ["FIRST_RECORD", "STREAK_DAYS", "STREAK_WEEKS", "VOLUME_KG", "PROTEIN_G"]
    private let titles = ["FIRST_RECORD":"첫 기록", "STREAK_DAYS":"식단 스트릭", "STREAK_WEEKS":"운동 스트릭",
                          "VOLUME_KG":"운동 볼륨", "PROTEIN_G":"단백질"]

    var body: some View {
        let groups = Dictionary(grouping: badges, by: \.conditionKind)
        let kinds = order.filter { groups[$0] != nil } + groups.keys.filter { !order.contains($0) }.sorted()
        let earned = badges.filter { $0.earnedAt != nil }.count
        ScrollView {
            VStack(alignment: .leading, spacing: G.gap) {
                GText(text: earned == 0 ? "배지" : "배지 \(earned)개 받았어요", size: 18, weight: 700)
                if badges.isEmpty { GText(text: "아직 받을 수 있는 배지가 없어요.") }
                ForEach(kinds, id: \.self) { kind in
                    if let items = groups[kind] {
                        HStack {
                            GText(text: titles[kind] ?? "기록 배지", size: 18, weight: 700)
                            Spacer()
                            GText(text: "\(items.filter { $0.earnedAt != nil }.count) / \(items.count)", size: 11, color: GColor.muted)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: G.small), count: 4), spacing: G.gap) {
                            ForEach(items, id: \.code) { badge in
                                VStack(spacing: G.dp(4)) {
                                    let icon = badge.earnedAt == nil ? "lock.fill" : kind.hasPrefix("STREAK_") ? "flame.fill" : "trophy.fill"
                                    Image(systemName: icon).foregroundStyle(badge.earnedAt == nil ? GColor.muted : Color.orange)
                                        .frame(width: G.dp(42), height: G.dp(42)).background(.white, in: Circle())
                                    GText(text: badge.name, size: 12, weight: 600, alignment: .center)
                                    GText(text: badge.earnedAt.map { String($0.prefix(10)) } ?? "아직 못 받았어요", size: 11, color: GColor.muted)
                                    if !badge.description.isEmpty { GText(text: badge.description, size: 11, color: GColor.muted, alignment: .center) }
                                }
                            }
                        }
                    }
                }
                GText(text: "배지는 이렇게 받아요", size: 18, weight: 700)
                GText(text: "첫 식사나 첫 운동을 기록하면 배지를 받아요. 식단이나 운동 스트릭이 마일스톤에 이르면 배지를 받아요. 누적 운동 볼륨이나 단백질이 정한 단계에 이르면 배지를 받아요. 한 번 받은 배지는 스트릭이 끊겨도 사라지지 않아요.")
                    .padding(G.gap).background(.white, in: RoundedRectangle(cornerRadius: G.dp(12)))
            }.padding(.horizontal, G.gutter).padding(.vertical, G.gap)
                .frame(maxWidth: .infinity, alignment: .leading)
        }.gListCanvas().navigationTitle("배지 모음")
    }
}
