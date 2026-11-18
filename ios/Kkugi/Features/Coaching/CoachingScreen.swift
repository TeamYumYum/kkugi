import SwiftUI

struct CoachingScreen: View {
    @State private var refreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: G.gap) {
            if refreshing {
                ProgressView()
                GText(text: "불러오는 중이에요")
            } else {
                GText(text: "아직 표시할 코칭 내용이 없어요", color: GColor.muted)
            }
            Button {
                refreshing = true
                Task { await Task.yield(); refreshing = false }
            } label: {
                GText(text: "새로고침", size: 15, weight: 700, color: .white)
            }.buttonStyle(GButtonStyle(background: GColor.text, outline: false)).disabled(refreshing)
            Spacer()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, G.gutter)
            .padding(.top, G.gap).background(Color(hex: 0xF5F7FA))
            .navigationTitle("코칭").navigationBarTitleDisplayMode(.inline)
    }
}

struct TargetCalorieScreen: View {
    let session: AuthSession
    @State private var plan: CoachingPlanResponse?
    @State private var editingTarget = ""
    @State private var choiceMessage = ""
    @State private var saving = false
    @State private var failed = false

    var body: some View {
        List {
            if failed { Button("코칭 목표 다시 불러오기") { Task { await load() } } }
            if let plan {
                Section("하루 섭취 목표") {
                    LabeledContent("열량", value: "\(plan.targetKcal.formatted()) kcal")
                    LabeledContent("탄수화물", value: "\(plan.carbRatio.formatted())%")
                    LabeledContent("단백질", value: "\(plan.proteinRatio.formatted())%")
                    LabeledContent("지방", value: "\(plan.fatRatio.formatted())%")
                    if let low = plan.manualRange?.minKcal, let high = plan.manualRange?.maxKcal {
                        TextField("새 목표 (\(low)~\(high) kcal)", text: $editingTarget).keyboardType(.numberPad)
                        Button("내일부터 적용") { Task { await changeTarget(low, high) } }
                    }
                    if plan.recalcPending {
                        Text("변경한 프로필로 목표를 다시 계산할까요?")
                        Button("다시 계산") { Task { await recalculate(true) } }
                        Button("현재 목표 유지") { Task { await recalculate(false) } }
                    }
                    if !choiceMessage.isEmpty { Text(choiceMessage) }
                }
            } else if !failed { ProgressView() }
        }.disabled(saving).gListCanvas().navigationTitle("목표 칼로리").task { await load() }.refreshable { await load() }
    }

    @MainActor private func changeTarget(_ low: Int, _ high: Int) async {
        guard !saving else { return }
        guard let value = Int(editingTarget), value >= low && value <= high else {
            choiceMessage = "\(low)~\(high) kcal 사이 정수를 입력해 주세요"
            return
        }
        saving = true
        defer { saving = false }
        do {
            let bytes = try await session.protectedRequest("api/v1/coaching-plan/me/target", method: "PUT",
                body: JSONEncoder().encode(TargetChangeRequest(targetKcal: value)))
            let response = try JSONDecoder().decode(ApiResponseCoachingPlanResponse.self, from: bytes)
            guard response.success == true, let result = response.data else { throw URLError(.badServerResponse) }
            plan = result
            editingTarget = ""
            choiceMessage = "새 목표는 내일부터 적용돼요"
        } catch { choiceMessage = "목표를 저장하지 못했어요" }
    }

    @MainActor private func recalculate(_ choice: Bool) async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        do {
            let bytes = try await session.protectedRequest("api/v1/coaching-plan/me/recalc-choice", method: "POST",
                body: JSONEncoder().encode(RecalcChoiceRequest(recalculate: choice)))
            guard try JSONDecoder().decode(ApiResponseVoid.self, from: bytes).success == true else {
                throw URLError(.badServerResponse)
            }
            await load()
            choiceMessage = choice ? "오늘 목표를 다시 계산했어요" : "현재 목표를 유지했어요"
        } catch { choiceMessage = "목표 변경을 처리하지 못했어요" }
    }

    @MainActor private func load() async {
        do {
            let data = try await session.protectedRequest("api/v1/coaching-plan/me", method: "GET")
            let response = try JSONDecoder().decode(ApiResponseCoachingPlanResponse.self, from: data)
            guard response.success == true, let value = response.data else { throw URLError(.badServerResponse) }
            plan = value
            failed = false
        } catch { failed = true }
    }
}

struct WeightDiary: View {
    let session: AuthSession
    @State private var date = Date()
    @State private var input = ""
    @State private var records: [WeightRecordResponse] = []
    @State private var message = ""
    @State private var saving = false
    @State private var ready = false

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func key(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: value)
    }

    var body: some View {
        List {
            DatePicker("기록일", selection: $date, in: ...Date(), displayedComponents: .date)
                .environment(\.timeZone, calendar.timeZone)
            TextField("체중 (kg)", text: $input).keyboardType(.decimalPad).disabled(!ready)
            Button("체중 저장") { Task { await save() } }.disabled(!ready || input.isEmpty)
            if !message.isEmpty { Text(message) }
            if !ready { Button("기록 다시 불러오기") { Task { await load(date) } } }
            Section("선택한 날짜까지 최근 30일") {
                if ready && records.isEmpty { Text("기록한 체중이 없어요") }
                ForEach(records, id: \.recordedOn) { record in
                    LabeledContent(record.recordedOn, value: "\(record.weightKg.formatted()) kg")
                }
            }
        }.disabled(saving).gListCanvas().navigationTitle("체중 기록").task(id: key(date)) { await load(date) }
    }

    @MainActor private func load(_ selected: Date) async {
        let day = key(selected)
        let start = calendar.date(byAdding: .day, value: -29, to: selected)!
        ready = false
        records = []
        input = ""
        message = ""
        do {
            let data = try await session.protectedRequest("api/v1/weight-records", method: "GET", query: [
                URLQueryItem(name: "from", value: key(start)), URLQueryItem(name: "to", value: day)
            ])
            let response = try JSONDecoder().decode(ApiResponseWeightRecordListResponse.self, from: data)
            guard response.success == true, let result = response.data else { throw URLError(.badServerResponse) }
            guard key(date) == day, !Task.isCancelled else { return }
            records = result.items.sorted { $0.recordedOn > $1.recordedOn }
            if let current = records.first(where: { $0.recordedOn == day }) { input = String(current.weightKg) }
            ready = true
        } catch { if key(date) == day && !Task.isCancelled { message = "체중 기록을 불러오지 못했어요" } }
    }

    @MainActor private func save() async {
        guard !saving, ready else { return }
        guard let value = OnboardingDraft.measure(input, range: 20...300) else {
            message = "체중은 20~300kg 사이로 입력해 주세요"
            return
        }
        saving = true
        defer { saving = false }
        do {
            let body = WeightRecordPutRequest(weightKg: NSDecimalNumber(decimal: value).doubleValue)
            let data = try await session.protectedRequest("api/v1/weight-records/" + key(date), method: "PUT",
                                                         body: JSONEncoder().encode(body))
            let response = try JSONDecoder().decode(ApiResponseWeightRecordResponse.self, from: data)
            guard response.success == true, let saved = response.data, saved.recordedOn == key(date) else {
                throw URLError(.badServerResponse)
            }
            records.removeAll { $0.recordedOn == saved.recordedOn }
            records.insert(saved, at: 0)
            input = String(saved.weightKg)
            message = "체중을 저장했어요"
        } catch { message = "저장하지 못했어요. 다시 시도해 주세요" }
    }
}

struct LatestWeeklyReport: View {
    let session: AuthSession
    @State private var report: WeeklyReportResponse?
    @State private var empty = false
    @State private var failed = false

    var body: some View {
        List {
            if let report {
                Section("\(report.periodStartDate) ~ \(report.periodEndDate)") {
                    LabeledContent("식단 기록", value: "\(report.diet.loggedDays)일")
                    LabeledContent("식단 목표 달성", value: "\(report.diet.achievedDays)일")
                    if let count = report.workout.countedCount { LabeledContent("운동 횟수", value: "\(count)회") }
                    if let kg = report.weight.changeKg { LabeledContent("체중 변화", value: "\(kg.formatted()) kg") }
                    Text(report.comment.text)
                }
            } else if empty { Text("아직 주간 리포트가 없어요") }
            else if failed { Button("리포트 다시 불러오기") { Task { await load() } } }
            else { ProgressView() }
        }.gListCanvas().navigationTitle("주간 리포트").task { await load() }
    }

    @MainActor private func load() async {
        do {
            let data = try await session.protectedRequest("api/v1/weekly-reports/me/latest", method: "GET")
            let response = try JSONDecoder().decode(ApiResponseWeeklyReportResponse.self, from: data)
            guard response.success == true, let value = response.data else { throw URLError(.badServerResponse) }
            report = value
        } catch let failure as AuthClient.RequestFailure where failure.status == 404 { empty = true }
        catch { failed = true }
    }
}
