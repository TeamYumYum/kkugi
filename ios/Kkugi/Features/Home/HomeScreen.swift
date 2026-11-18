import SwiftUI

struct HomeScreen: View {
    let session: AuthSession
    let profile: () -> Void
    @State private var growth: GrowthSummaryResponse?
    @State private var unread = 0
    @State private var failed = false
    @State private var recommendation: LastMealRecommendationResponse?
    @State private var expanded = false
    @State private var page = 0
    @State private var recording = false
    @State private var chosen: [LastMealFood] = []
    @State private var refreshing = false
    @State private var recommendationError = ""
    @State private var hasReport = false

    var body: some View {
        NavigationStack {
            ZStack {
                HomeGarden().ignoresSafeArea()
                VStack(spacing: G.gap) {
                    HStack {
                        if let growth {
                            NavigationLink { GrowthScreen(session: session) } label: {
                                Label("\(growth.diet.currentDays)일", systemImage: "fork.knife")
                                Label("\(growth.workout.currentWeeks)주", systemImage: "dumbbell.fill")
                            }.accessibilityLabel("연속 기록")
                        } else if failed { Button("다시 시도") { Task { await load() } } }
                        Spacer()
                        Button(action: profile) { Image(systemName: "person.crop.circle") }.accessibilityLabel("내 프로필")
                        NavigationLink { NotificationInbox(session: session) } label: {
                            Image(systemName: unread > 0 ? "bell.badge" : "bell")
                        }.accessibilityLabel("알림")
                    }.padding(G.small).background(.regularMaterial, in: Capsule())
                    HStack(alignment: .top) {
                        if let recommendation, !recommendation.hidden,
                           let entry = recommendation.pages.indices.contains(page) ? recommendation.pages[page] : nil {
                            VStack(alignment: .leading, spacing: G.small) {
                                Button(expanded ? "마지막 끼니 접기" : "마지막 끼니") { expanded.toggle() }
                                if expanded {
                                    ForEach(entry.foods.indices, id: \.self) { index in
                                        Text("\(entry.foods[index].foodName) · \(entry.foods[index].grams)g")
                                    }
                                    Text(entry.reason)
                                    if recommendation.pages.count > 1 {
                                        Picker("추천 기록", selection: $page) {
                                            ForEach(recommendation.pages.indices, id: \.self) { Text("\($0 + 1)").tag($0) }
                                        }.pickerStyle(.segmented)
                                    }
                                    Button("이대로 기록") { chosen = entry.foods; recording = true }
                                    Button("다시 추천 (\(recommendation.refreshRemaining))") { Task { await refresh() } }
                                        .disabled(refreshing || recommendation.refreshRemaining == 0 || recommendation.refreshBlockedReason != nil)
                                }
                            }.padding(G.gap).background(.regularMaterial, in: RoundedRectangle(cornerRadius: G.gap))
                        }
                        Spacer()
                        if !expanded {
                            NavigationLink { CoachingChat(session: session) } label: {
                                Image(systemName: "bubble.left.and.bubble.right").padding(G.small)
                                    .background(.regularMaterial, in: Circle())
                            }.accessibilityLabel("꾸기에게 묻기")
                        }
                        if hasReport && !expanded {
                            NavigationLink { LatestWeeklyReport(session: session) } label: {
                                Image(systemName: "chart.bar.doc.horizontal").padding(G.small)
                                    .background(.regularMaterial, in: Circle())
                            }.accessibilityLabel("주간 리포트")
                        }
                    }
                    if !recommendationError.isEmpty { Text(recommendationError).padding(6).background(.regularMaterial) }
                    Spacer()
                    HStack {
                        NavigationLink("식사 기록") { MealDiary(session: session) }
                        Spacer()
                        NavigationLink("운동") { WorkoutScreen(session: session) }
                        Spacer()
                        NavigationLink("코칭") { CoachingScreen(session: session) }
                        Spacer()
                        NavigationLink("성장") { GrowthScreen(session: session) }
                    }.padding(G.gap).background(.regularMaterial, in: Capsule())
                }.padding(G.gutter)
            }.foregroundStyle(GColor.text)
            .task { await load() }
            .sheet(isPresented: $recording) {
                ManualMealForm(session: session, date: Date(), recommendation: chosen) {
                    recording = false
                    Task { await load() }
                }
            }
        }
    }

    private var dateKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    @MainActor private func load() async {
        do {
            let response = try await session.homeData("growth/me", ApiResponseGrowthSummaryResponse.self)
            guard response.success == true, let result = response.data else { throw URLError(.badServerResponse) }
            growth = result
            failed = false
        } catch { failed = true }
        if let count = try? await session.homeData("members/me/notifications/unread-count", ApiResponseUnreadNotificationCountResponse.self).data?.unreadCount { unread = count }
        hasReport = (try? await session.homeData("weekly-reports/me/latest", ApiResponseWeeklyReportResponse.self).data) != nil
        do { try await loadRecommendation(dateKey) } catch { recommendation = nil }
    }

    @MainActor private func loadRecommendation(_ day: String) async throws {
        let response = try await session.homeData("last-meal-recommendations/" + day, ApiResponseLastMealRecommendationResponse.self)
        guard response.success == true, let result = response.data else { throw URLError(.badServerResponse) }
        recommendation = result
        if !result.pages.indices.contains(page) { page = 0 }
    }

    @MainActor private func refresh() async {
        guard !refreshing else { return }
        let day = dateKey
        refreshing = true
        recommendationError = ""
        defer { refreshing = false }
        do {
            _ = try await session.protectedRequest("api/v1/last-meal-recommendations/" + day + "/refresh", method: "POST")
            for _ in 0..<15 {
                try await Task.sleep(for: .seconds(2))
                try await loadRecommendation(day)
                if recommendation?.refreshing == false { return }
            }
            recommendationError = "새 추천을 준비하고 있어요"
        } catch { recommendationError = "추천을 불러오지 못했어요" }
    }
}

private extension AuthSession {
    func homeData<T: Decodable>(_ path: String, _ type: T.Type, query: [URLQueryItem] = []) async throws -> T {
        let bytes = try await protectedRequest("api/v1/" + path, method: "GET", query: query)
        return try JSONDecoder().decode(type, from: bytes)
    }
}

private struct NotificationInbox: View {
    let session: AuthSession
    @State private var items: [MemberNotificationResponse] = []
    @State private var pageIndex = 0
    @State private var hasNext = false
    @State private var loading = false
    @State private var message = ""

    var body: some View {
        List {
            if loading { ProgressView() }
            if !message.isEmpty { Text(message); Button("다시 시도") { Task { await load(pageIndex) } } }
            if !loading && message.isEmpty && items.isEmpty { Text("아직 알림이 없어요") }
            ForEach(items, id: \.id) { item in
                Button {
                    Task {
                        do {
                            _ = try await session.protectedRequest("api/v1/members/me/notifications/\(item.id)/read", method: "POST")
                            await load(pageIndex)
                        } catch { message = "읽음으로 표시하지 못했어요" }
                    }
                } label: {
                    VStack(alignment: .leading) {
                        GText(text: item.title, weight: item.read ? 400 : 700)
                        GText(text: item.body, color: GColor.muted)
                    }
                }
            }
            if pageIndex > 0 || hasNext {
                HStack {
                    Button("이전") { Task { await load(pageIndex - 1) } }.disabled(pageIndex == 0)
                    Spacer()
                    Text("\(pageIndex + 1)페이지")
                    Spacer()
                    Button("다음") { Task { await load(pageIndex + 1) } }.disabled(!hasNext)
                }.buttonStyle(.borderless).disabled(loading)
            }
        }.navigationTitle("알림").task { await load(pageIndex) }.refreshable { await load(pageIndex) }
    }

    @MainActor private func load(_ requested: Int) async {
        guard !loading, requested >= 0 else { return }
        loading = true
        defer { loading = false }
        do {
            let page = try await session.homeData(
                "members/me/notifications", ApiResponseMemberNotificationPageResponse.self,
                query: [URLQueryItem(name: "page", value: String(requested)), URLQueryItem(name: "size", value: "20")]
            )
            guard page.success == true, let data = page.data else { throw URLError(.badServerResponse) }
            pageIndex = data.page
            hasNext = (data.page + 1) * data.size < data.totalElements
            items = data.items
            message = ""
        } catch { message = "알림을 불러오지 못했어요" }
    }
}
