import Foundation

/// How the date reads beside the time in the menubar.
enum DateStyle: String, CaseIterable, Identifiable {
    case weekday, monthDay, numeric, spoken

    var id: String { rawValue }

    /// The spoken style is English, like the personalities, so its weekday is
    /// too; the others follow the Mac's language and date order.
    private static let english = Locale(identifier: "en_US")
    private static let ordinals = [
        "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
        "eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth", "seventeenth",
        "eighteenth", "nineteenth", "twentieth", "twenty-first", "twenty-second", "twenty-third",
        "twenty-fourth", "twenty-fifth", "twenty-sixth", "twenty-seventh", "twenty-eighth", "twenty-ninth",
        "thirtieth", "thirty-first",
    ]

    /// "Friday", "Nov 13", "11/13/26" or "Friday the thirteenth".
    func text(for date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        func format(_ locale: Locale) -> Date.FormatStyle {
            Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        }
        switch self {
        case .weekday: return date.formatted(format(locale).weekday(.wide))
        case .monthDay: return date.formatted(format(locale).month(.abbreviated).day())
        case .numeric: return date.formatted(format(locale).year(.twoDigits).month(.defaultDigits).day())
        case .spoken:
            let weekday = date.formatted(format(Self.english).weekday(.wide))
            let day = calendar.component(.day, from: date)
            // A calendar with longer months than ours falls back to the number.
            let ordinal = Self.ordinals.indices.contains(day - 1) ? Self.ordinals[day - 1] : "\(day)"
            return "\(weekday) the \(ordinal)"
        }
    }
}

/// Whether the menubar shows the date, how, and on which side of the time.
struct DateDisplay: Equatable {
    enum Position: String, CaseIterable, Identifiable {
        case before, after
        var id: String { rawValue }
    }

    var isShown = false
    var style = DateStyle.weekday
    var position = Position.before

    static let shownKey = "dateShown"
    static let styleKey = "dateStyle"
    static let positionKey = "datePosition"

    /// Wider than a word space, so the date and the phrase read as two things.
    static let gap = "\u{2003}"

    /// `time` with the date beside it, or `time` alone when the date is off.
    func text(_ time: String, on date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard isShown else { return time }
        let day = style.text(for: date, calendar: calendar, locale: locale)
        return position == .before ? day + Self.gap + time : time + Self.gap + day
    }

    static func load(from defaults: UserDefaults) -> DateDisplay {
        DateDisplay(isShown: defaults.bool(forKey: shownKey),
                    style: defaults.string(forKey: styleKey).flatMap(DateStyle.init) ?? .weekday,
                    position: defaults.string(forKey: positionKey).flatMap(Position.init) ?? .before)
    }

    func save(to defaults: UserDefaults) {
        defaults.set(isShown, forKey: Self.shownKey)
        defaults.set(style.rawValue, forKey: Self.styleKey)
        defaults.set(position.rawValue, forKey: Self.positionKey)
    }
}
