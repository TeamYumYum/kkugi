import Foundation

struct OnboardingDraft {
    var nickname = ""
    var goal = ""
    var gender = ""
    var birthday = ""
    var height = ""
    var weight = ""
    var activity = ""

    var normalizedNickname: String? {
        guard !nickname.unicodeScalars.contains(where: { $0.value < 32 || (127...159).contains($0.value) }) else { return nil }
        let value = nickname.split(separator: " ").joined(separator: " ")
        return (2...12).contains(value.unicodeScalars.count) ? value : nil
    }

    func birthDate(today: Date) -> String? {
        guard birthday.range(of: #"^[0-9]{8}$"#, options: .regularExpression) != nil else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyyMMdd"
        formatter.isLenient = false
        guard birthday >= "19000101", let date = formatter.date(from: birthday),
              formatter.string(from: date) == birthday,
              let years = calendar.dateComponents([.year], from: date, to: today).year, years >= 14 else { return nil }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func measure(_ input: String, range: ClosedRange<Decimal>) -> Decimal? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil,
              var value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
              range.contains(value) else { return nil }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return rounded
    }
}
