import SwiftUI
import WidgetKit

private struct GardenEntry: TimelineEntry {
    let date: Date
    let snapshot: GardenWidgetSnapshot
}

private struct GardenTimeline: TimelineProvider {
    func placeholder(in context: Context) -> GardenEntry { GardenEntry(date: Date(), snapshot: .signedOut) }
    func getSnapshot(in context: Context, completion: @escaping (GardenEntry) -> Void) {
        completion(GardenEntry(date: Date(), snapshot: GardenWidgetStore.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GardenEntry>) -> Void) {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        completion(Timeline(entries: [GardenEntry(date: now, snapshot: GardenWidgetStore.read())], policy: .after(tomorrow)))
    }
}

private struct GardenWidgetView: View {
    let entry: GardenEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("꾸기").font(.headline)
            if entry.snapshot.memberID == nil { Text("로그인해 주세요") }
            else if !entry.snapshot.onboarded { Text("온보딩을 마쳐 주세요") }
            else if let days = entry.snapshot.dietDays, let weeks = entry.snapshot.workoutWeeks {
                Text(entry.snapshot.calories(on: GardenWidgetSnapshot.koreaDay(entry.date)))
                Text("식단 \(days)일 · 운동 \(weeks)주").font(.caption)
            } else { Text("앱에서 오늘 기록을 확인해 주세요") }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .privacySensitive()
        .containerBackground(for: .widget) { Color(red: 0.98, green: 0.96, blue: 0.93) }
        .widgetURL(URL(string: "kkugi://home"))
    }
}

@main
struct KkugiGardenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KkugiGarden", provider: GardenTimeline()) { GardenWidgetView(entry: $0) }
            .configurationDisplayName("꾸기")
            .description("오늘 남은 열량과 식단·운동 연속 기록을 확인해요.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
