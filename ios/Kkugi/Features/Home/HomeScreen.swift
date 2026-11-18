import SwiftUI

struct HomeScreen: View {
    let session: AuthSession
    let profile: () -> Void
    @State private var growth: GrowthSummaryResponse?
    @State private var workout: WeeklyWorkoutGoalResponse?
    @State private var unread: Int?
    @State private var growthError = false
    @State private var workoutError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: G.gutter) {
                    HStack {
                        GText(text: "홈", size: 24, weight: 700)
                        Spacer()
                        NavigationLink { NotificationInbox(session: session) } label: {
                            Image(systemName: (unread ?? 0) > 0 ? "bell.badge" : "bell")
                        }.accessibilityLabel("알림")
                        Button("내 프로필", action: profile)
                    }
                    NavigationLink("식사 기록") { MealDiary(session: session) }
                    GText(text: "식단 스트릭", size: 18, weight: 700)
                    if let growth {
                        GText(text: "\(growth.diet.currentDays)일 연속")
                        GText(text: "운동 \(growth.workout.currentWeeks)주 연속")
                    } else if growthError { Text("성장 기록을 불러오지 못했어요") } else { ProgressView() }
                    GText(text: "이번 주 운동", size: 18, weight: 700)
                    if let workout {
                        if let week = workout.thisWeek, let progress = workout.progress {
                            GText(text: "\(progress.countedCount) / \(week.targetCount)회")
                        } else if !workout.configured { Text("운동 목표를 설정해 주세요") }
                        else { Text("운동 진행 상황을 확인할 수 없어요") }
                    } else if workoutError { Text("운동 기록을 불러오지 못했어요") } else { ProgressView() }
                    if growthError || workoutError { Button("다시 시도") { Task { await load() } } }
                }.padding(G.gutter)
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @MainActor private func load() async {
        do {
            growth = try await session.homeData("growth/me", ApiResponseGrowthSummaryResponse.self).data
            growthError = growth == nil
        } catch { growthError = true }
        do {
            workout = try await session.homeData("weekly-workout-goal/me", ApiResponseWeeklyWorkoutGoalResponse.self).data
            workoutError = workout == nil
        } catch { workoutError = true }
        unread = try? await session.homeData("members/me/notifications/unread-count", ApiResponseUnreadNotificationCountResponse.self).data?.unreadCount
    }
}

private extension AuthSession {
    func homeData<T: Decodable>(_ path: String, _ type: T.Type) async throws -> T {
        let bytes = try await protectedRequest("api/v1/" + path, method: "GET")
        return try JSONDecoder().decode(type, from: bytes)
    }
}

private struct NotificationInbox: View {
    let session: AuthSession
    @State private var items: [MemberNotificationResponse] = []
    @State private var loading = true
    @State private var message = ""

    var body: some View {
        List {
            if loading { ProgressView() }
            if !message.isEmpty { Text(message); Button("다시 시도") { Task { await load() } } }
            if !loading && message.isEmpty && items.isEmpty { Text("아직 알림이 없어요") }
            ForEach(items, id: \.id) { item in
                Button {
                    Task {
                        do {
                            _ = try await session.protectedRequest("api/v1/members/me/notifications/\(item.id)/read", method: "POST")
                            await load()
                        } catch { message = "읽음으로 표시하지 못했어요" }
                    }
                } label: {
                    VStack(alignment: .leading) {
                        GText(text: item.title, weight: item.read ? 400 : 700)
                        GText(text: item.body, color: GColor.muted)
                    }
                }
            }
        }.navigationTitle("알림").task { await load() }.refreshable { await load() }
    }

    @MainActor private func load() async {
        defer { loading = false }
        do {
            let page = try await session.homeData("members/me/notifications", ApiResponseMemberNotificationPageResponse.self)
            guard page.success == true, let data = page.data else { throw URLError(.badServerResponse) }
            items = data.items
            message = ""
        } catch { message = "알림을 불러오지 못했어요" }
    }
}
