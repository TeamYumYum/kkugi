import SwiftUI
import KkugiRenderer

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
                        NavigationLink("코칭") { CoachingScreen() }
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

extension EnvironmentValues {
    @Entry var notificationReferenceDate: Date? = nil
}

struct NotificationInbox: View {
    let session: AuthSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.notificationReferenceDate) private var referenceDate
    @State private var items: [MemberNotificationResponse] = []
    @State private var pageIndex = 0
    @State private var hasNext = false
    @State private var loading = false
    @State private var message = ""
    @State private var failedPage = 0
    @State private var selectedWeek: String?
    @State private var showingGrowth = false
    @State private var markingRead = Set<Int>()
    @State private var pendingHome: UUID?

    var body: some View {
        SharedInboxView(
            state: InboxState(rows: items.map(row), loading: loading, error: message, page: Int32(pageIndex),
                              hasNext: hasNext, failedPage: Int32(failedPage)),
            onBack: { dismiss() },
            onLoad: { page in Task { await load(page) } },
            onSelect: open
        )
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedWeek) { week in LatestWeeklyReport(session: session, weekStartDate: week) }
        .navigationDestination(isPresented: $showingGrowth) { GrowthScreen(session: session) }
        .task { if items.isEmpty { await load(0) } }
        .onDisappear { pendingHome = nil }
    }

    private func open(_ key: String) {
        guard pendingHome == nil, let item = items.first(where: { String($0.id) == key }) else { return }
        var write: Task<Void, Never>?
        if !item.read && markingRead.insert(item.id).inserted {
            write = Task {
                defer { markingRead.remove(item.id) }
                do {
                    _ = try await session.protectedRequest("api/v1/members/me/notifications/\(item.id)/read", method: "POST")
                    if let index = items.firstIndex(where: { $0.id == item.id }) {
                        let current = items[index]
                        items[index] = MemberNotificationResponse(id: current.id, type: current.type, title: current.title,
                                                                  body: current.body, data: current.data, sentAt: current.sentAt, read: true)
                    }
                } catch { return }
            }
        }
        switch item.type {
        case "LAST_MEAL":
            guard let write else { dismiss(); return }
            let token = UUID()
            pendingHome = token
            Task { await write.value; returnHome(token) }
            Task { try? await Task.sleep(for: .milliseconds(1500)); returnHome(token) }
        case "BADGE": showingGrowth = true
        case "WEEKLY_REPORT":
            if let week = item.data["weekStartDate"], week.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
                let format = DateFormatter()
                format.locale = Locale(identifier: "en_US_POSIX")
                format.timeZone = TimeZone(identifier: "Asia/Seoul")
                format.dateFormat = "yyyy-MM-dd"
                if let parsed = format.date(from: week), format.string(from: parsed) == week { selectedWeek = week }
            }
        default: break
        }
    }

    private func returnHome(_ token: UUID) {
        guard pendingHome == token else { return }
        pendingHome = nil
        dismiss()
    }
    private func row(_ item: MemberNotificationResponse) -> InboxRow {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = referenceDate ?? Date()
        let today = calendar.startOfDay(for: now)
        let week = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let sent = (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(item.sentAt))
            ?? (try? Date.ISO8601FormatStyle().parse(item.sentAt))
        let section = sent.map { $0 >= today ? "오늘" : $0 >= week ? "이번 주" : "이전" } ?? "이전"
        let format = DateFormatter()
        format.locale = Locale(identifier: "ko_KR")
        format.timeZone = calendar.timeZone
        format.dateFormat = section == "오늘" ? "a h:mm" : section == "이번 주" ? "EEEE" :
            (sent.map { calendar.isDate($0, equalTo: now, toGranularity: .year) } == true ? "M월 d일" : "yyyy년 M월 d일")
        return InboxRow(key: String(item.id), title: item.title, body: item.body, read: item.read || markingRead.contains(item.id),
                        type: item.type, section: section, time: sent.map { format.string(from: $0) } ?? item.sentAt)
    }

    @MainActor private func load(_ requested: Int) async {
        guard !loading, requested == 0 || (hasNext && requested == pageIndex + 1) else { return }
        loading = true
        message = ""
        defer { loading = false }
        do {
            let page = try await session.homeData(
                "members/me/notifications", ApiResponseMemberNotificationPageResponse.self,
                query: [URLQueryItem(name: "page", value: String(requested)), URLQueryItem(name: "size", value: "20")]
            )
            guard page.success == true, let data = page.data, data.page == requested, data.size > 0 else { throw URLError(.badServerResponse) }
            pageIndex = data.page
            hasNext = (data.page + 1) * data.size < data.totalElements
            if requested == 0 {
                items = data.items
            } else {
                var seen = Set(items.map(\.id))
                items.append(contentsOf: data.items.filter { seen.insert($0.id).inserted })
            }
        } catch {
            failedPage = requested
            message = "알림을 불러오지 못했어요"
        }
    }
}

private struct SharedInboxView: UIViewControllerRepresentable {
    let state: InboxState
    let onBack: () -> Void
    let onLoad: (Int) -> Void
    let onSelect: (String) -> Void

    final class Coordinator: NSObject, InboxActions {
        let model = InboxModel()
        var view: SharedInboxView
        init(_ view: SharedInboxView) { self.view = view }
        func back() { view.onBack() }
        func load(page: Int32) { view.onLoad(Int(page)) }
        func select(key: String) { view.onSelect(key) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIViewController {
        context.coordinator.model.update(value: state)
        return InboxHostKt.inboxController(model: context.coordinator.model, actions: context.coordinator)
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.view = self
        context.coordinator.model.update(value: state)
    }
}
