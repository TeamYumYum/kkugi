import Foundation

struct GardenWidgetSnapshot: Codable, Equatable {
    let memberID: Int64?
    let onboarded: Bool
    var day: String?
    var dietDays: Int?
    var workoutWeeks: Int?
    var targetKcal: Double?
    var intakeKcal: Double?

    static let signedOut = Self(memberID: nil, onboarded: false)

    func calories(on today: String) -> String {
        guard day == today else { return "오늘 기록을 확인해 주세요" }
        guard let targetKcal, let intakeKcal else { return "하루 목표 계산 중" }
        let remaining = Int((targetKcal - intakeKcal).rounded())
        return remaining >= 0 ? "남은 \(remaining) kcal" : "목표보다 \(-remaining) kcal 초과"
    }

    static func koreaDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum GardenWidgetStore {
    private static let key = "garden-widget-v1"

    private static var defaults: UserDefaults? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "KkugiAppGroup") as? String,
              FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil else { return nil }
        return UserDefaults(suiteName: group)
    }

    static func read() -> GardenWidgetSnapshot {
        guard let data = defaults?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(GardenWidgetSnapshot.self, from: data) else { return .signedOut }
        return snapshot
    }

    @discardableResult static func write(_ snapshot: GardenWidgetSnapshot) -> Bool {
        guard let defaults, let bytes = try? JSONEncoder().encode(snapshot), read() != snapshot else { return false }
        defaults.set(bytes, forKey: key)
        return true
    }
}
