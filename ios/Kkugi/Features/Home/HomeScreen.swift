import SwiftUI

struct HomeScreen: View {
    let session: AuthSession
    let profile: () -> Void
    @Environment(\.displayScale) private var displayScale
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
                VStack(spacing: aligned(8)) {
                    HStack(spacing: aligned(5)) {
                        if let growth {
                            NavigationLink { GrowthScreen(session: session) } label: {
                                HStack(spacing: aligned(5)) {
                                    streakChip("\(growth.diet.currentDays)일", icon: "fork.knife")
                                    streakChip("\(growth.workout.currentWeeks)주", icon: "dumbbell.fill")
                                }.frame(minHeight: aligned(48))
                            }.accessibilityLabel("연속 기록")
                        } else if failed { Button("다시 시도") { Task { await load() } } }
                        Spacer()
                        Button(action: profile) {
                            ArtImage(asset: .idle).scaledToFit()
                                .frame(width: aligned(30), height: aligned(30))
                                .frame(width: aligned(35), height: aligned(35))
                                .background(.white, in: Circle())
                        }.accessibilityLabel("내 프로필")
                        NavigationLink { NotificationInbox(session: session) } label: {
                            roundIcon(unread > 0 ? "bell.badge" : "bell")
                        }.accessibilityLabel("알림")
                    }
                    .frame(minHeight: aligned(48))
                    .padding(.horizontal, aligned(12))
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
                            VStack(spacing: aligned(7)) {
                                NavigationLink { CoachingChat(session: session) } label: {
                                    railButton("꾸기에게 묻기", icon: "bubble.left.and.bubble.right")
                                }.accessibilityLabel("꾸기에게 묻기")
                                if hasReport {
                                    NavigationLink { LatestWeeklyReport(session: session) } label: {
                                        railButton("리포트", icon: "chart.bar.doc.horizontal")
                                    }.accessibilityLabel("주간 리포트")
                                }
                            }
                        }
                    }.padding(.leading, aligned(12)).padding(.trailing, aligned(8))
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
                        .padding(.horizontal, G.gutter).padding(.bottom, G.gutter)
                }.padding(.top, aligned(8))
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

    private func aligned(_ dp: CGFloat) -> CGFloat {
        (G.dp(dp) * displayScale).rounded() / displayScale
    }

    private func roundIcon(_ name: String) -> some View {
        Image(systemName: name)
            .frame(width: aligned(38), height: aligned(38))
            .background(.regularMaterial, in: Circle())
    }

    private func railButton(_ title: String, icon: String) -> some View {
        VStack(spacing: aligned(3) + 1 / displayScale) {
            roundIcon(icon)
            GText(text: title, size: 10, weight: 800, alignment: .center)
                .lineLimit(2)
                .padding(.horizontal, aligned(3)).padding(.vertical, aligned(1))
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: aligned(9)))
        }
        .frame(width: aligned(46))
        .contentShape(Rectangle())
    }

    private func streakChip(_ text: String, icon: String) -> some View {
        HStack(spacing: aligned(4)) {
            Image(systemName: icon).resizable().scaledToFit().frame(width: aligned(18), height: aligned(18))
            GText(text: text, size: 12, weight: 500)
        }
        .padding(.leading, aligned(8)).padding(.trailing, aligned(12) + 2 / displayScale).padding(.vertical, aligned(5))
        .background(.regularMaterial, in: Capsule())
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

struct NotificationInbox: View {
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
            if !loading && message.isEmpty && items.isEmpty {
                VStack(spacing: G.gap) {
                    ArtImage(asset: .idle).scaledToFit()
                        .frame(width: G.dp(40), height: G.dp(40))
                        .accessibilityHidden(true)
                    GText(text: "아직 받은 알림이 없어요", size: 18, weight: 700, alignment: .center)
                    GText(text: "끼니 추천이나 주간 리포트가 오면 여기에 모여요.", color: GColor.muted, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, G.gutter * 2).padding(.vertical, G.gutter)
                .listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
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
        }.listStyle(.plain).scrollContentBackground(.hidden)
            .background(Color(hex: 0xF5F7FA))
            .navigationTitle("알림").navigationBarTitleDisplayMode(.inline)
            .task { await load(pageIndex) }.refreshable { await load(pageIndex) }
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
