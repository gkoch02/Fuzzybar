import Foundation

/// The phrasing styles ported from LittleFuzzyClock, plus FuzzyBar's own
/// Spoken (the default), Spanish, French, Precise and Vague. LittleFuzzyClock renders the phrase and
/// the hour on two lines of an e-ink panel; the menubar gets one line, so
/// each personality also says how to join the two halves.
enum Personality: String, CaseIterable, Identifiable {
    case spoken
    case classic
    case shakespeare
    case german
    case spanish
    case french
    case missionControl
    case eldritch
    case latin
    case precise
    case vague

    static let `default`: Personality = .spoken
    static let defaultsKey = "personality"

    /// Raw values from before Mission Control and Eldritch were renamed, so
    /// an older preference maps forward. The withdrawn "klingon" and
    /// "belter" are absent on purpose: they fall back to the default like
    /// any unknown value.
    private static let renamed: [String: Personality] = [
        "hal": .missionControl,
        "cthulhu": .eldritch,
    ]

    /// Reads a stored `defaultsKey` string, migrating a pre-rename value.
    /// `nil` for a withdrawn one and for anything that was never a
    /// personality; the caller supplies the default.
    static func stored(_ raw: String) -> Personality? {
        Personality(rawValue: raw) ?? renamed[raw]
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spoken: return "Spoken"
        case .classic: return "Classic"
        case .shakespeare: return "Shakespeare"
        case .german: return "German"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .missionControl: return "Mission Control"
        case .eldritch: return "Eldritch"
        case .latin: return "Latin"
        case .precise: return "Precise"
        case .vague: return "Vague"
        }
    }

    /// One-line description for the picker.
    var note: String {
        switch self {
        case .spoken: return "The way you'd say it out loud."
        case .classic: return "Plain English with am and pm."
        case .shakespeare: return "Archaic English; no am or pm, that's anachronistic."
        case .german: return "Standard High German; \"halb\" anchors on the next hour."
        case .spanish: return "Spanish as Spain says it, hour first: \"las diez menos cuarto\"."
        case .french: return "The hour first; noon and midnight are \"midi\" and \"minuit\"."
        case .missionControl: return "Mission-control patter in 24-hour time."
        case .eldritch: return "Cosmic dread; climaxes with \"the stars are right\"."
        case .latin: return "Roman-numeral hours and real Latin prepositions."
        case .precise: return "Every minute, read out like a digital clock."
        case .vague: return "Just the part of the day; the hour is your problem."
        }
    }

    /// The twelve five-minute slots, index 0 = on the hour, 11 = "almost".
    /// `nil` for the spoken personality, which has its own thirteen-slot logic,
    /// for Spanish and French, where the hour comes first (see
    /// `minutePhrases`), for precise, which names every minute, and for vague,
    /// which ignores them (see `vagueParts`).
    var slotPhrases: [String]? {
        switch self {
        case .spoken, .spanish, .french, .precise, .vague:
            return nil
        case .classic:
            return ["just after", "a little past", "ten past", "quarter past", "twenty past",
                    "twenty-five past", "half past", "twenty-five to", "twenty to", "quarter to",
                    "ten to", "almost"]
        case .shakespeare:
            return ["'tis just past", "a moment past", "ten past", "'tis a quarter past", "twenty past",
                    "twenty-five past", "'tis half past", "twenty-five 'fore", "twenty 'fore",
                    "a quarter 'fore", "ten 'fore", "almost"]
        case .german:
            return ["kurz nach", "fünf nach", "zehn nach", "viertel nach", "zwanzig nach",
                    "fünf vor halb", "halb", "fünf nach halb", "zwanzig vor", "viertel vor",
                    "zehn vor", "kurz vor"]
        case .missionControl:
            return ["ON THE MARK", "T+5 MINUTES", "T+10 MINUTES", "T+15 MINUTES", "T+20 MINUTES",
                    "T+25 MINUTES", "MIDPOINT", "T-25 MINUTES", "T-20 MINUTES", "T-15 MINUTES",
                    "T-10 MINUTES", "IMMINENT"]
        case .eldritch:
            return ["newly woken", "moments past", "ten past", "quarter past", "twenty past",
                    "twenty-five past", "the half-hour", "twenty-five 'fore", "twenty 'fore",
                    "quarter 'fore", "ten 'fore", "the stars are right"]
        case .latin:
            return ["modo post", "quinque post", "decem post", "quadrans post", "viginti post",
                    "viginti quinque post", "media post", "viginti quinque ante", "viginti ante",
                    "quadrans ante", "decem ante", "fere"]
        }
    }

    /// What follows the hour in Spanish and French, for the same twelve
    /// slots; `nil` for everyone else. The last is the exception: "almost"
    /// goes in front of the hour. French's slots 0 and 6 are for a plural
    /// hour; `FuzzyTime` makes them agree with "une heure", "midi" and
    /// "minuit".
    var minutePhrases: [String]? {
        switch self {
        case .spanish:
            return ["y pico", "y cinco", "y diez", "y cuarto", "y veinte", "y veinticinco", "y media",
                    "menos veinticinco", "menos veinte", "menos cuarto", "menos diez", "casi"]
        case .french:
            return ["passées", "cinq", "dix", "et quart", "vingt", "vingt-cinq", "et demie",
                    "moins vingt-cinq", "moins vingt", "moins le quart", "moins dix", "presque"]
        default:
            return nil
        }
    }

    /// Vague's parts of the day as (start, phrase), start in minutes after
    /// midnight, ascending. Each runs until the next one starts; the first
    /// also covers the small hours before "early".
    static let vagueParts: [(start: Int, phrase: String)] = [
        (0, "way too late"),
        (5 * 60, "early"),
        (7 * 60, "morning"),
        (11 * 60 + 30, "around noon"),
        (13 * 60, "after lunch"),
        (15 * 60, "afternoon"),
        (18 * 60, "evening"),
        (21 * 60, "late"),
    ]

    /// The slot at which the displayed hour flips to the next one. German's
    /// "fünf vor halb zehn" already names the next hour at 25 past, so it
    /// flips at 5; everyone else at 7 (twenty-five to). Must stay in 1...11
    /// so the "almost" slot always names the next hour.
    var hourAdvanceSlot: Int { self == .german ? 5 : 7 }

    var joiner: String {
        switch self {
        case .missionControl, .eldritch: return ", "
        default: return " "
        }
    }

    static let englishHours = [
        "twelve", "one", "two", "three", "four", "five",
        "six", "seven", "eight", "nine", "ten", "eleven",
    ]
    /// Precise's minutes from one to nineteen, then the tens from twenty.
    static let englishMinutes = [
        "", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
    ]
    static let englishTens = ["", "", "twenty", "thirty", "forty", "fifty"]
    private static let germanHours = [
        "zwölf", "eins", "zwei", "drei", "vier", "fünf",
        "sechs", "sieben", "acht", "neun", "zehn", "elf",
    ]
    private static let spanishHours = [
        "doce", "una", "dos", "tres", "cuatro", "cinco",
        "seis", "siete", "ocho", "nueve", "diez", "once",
    ]
    /// From one to eleven: twelve is "midi" or "minuit".
    private static let frenchHours = [
        "", "une", "deux", "trois", "quatre", "cinq",
        "six", "sept", "huit", "neuf", "dix", "onze",
    ]
    private static let ordinalHours = [
        "twelfth", "first", "second", "third", "fourth", "fifth",
        "sixth", "seventh", "eighth", "ninth", "tenth", "eleventh",
    ]
    private static let romanHours = [
        "XII", "I", "II", "III", "IV", "V",
        "VI", "VII", "VIII", "IX", "X", "XI",
    ]

    /// Renders the hour half for a 24-hour display hour (0...23).
    func hourText(displayHour: Int) -> String {
        let h24 = ((displayHour % 24) + 24) % 24
        let index = h24 % 12  // 0 = twelve
        let isPM = h24 >= 12
        switch self {
        case .spoken, .classic, .precise, .vague:
            return "\(Self.englishHours[index]) \(isPM ? "pm" : "am")"
        case .shakespeare:
            return "\(Self.englishHours[index]) of the clock"
        case .german:
            return Self.germanHours[index]
        case .spanish:
            return "\(index == 1 ? "la" : "las") \(Self.spanishHours[index])"
        case .french:
            if index == 0 { return isPM ? "midi" : "minuit" }
            return "\(Self.frenchHours[index]) \(index == 1 ? "heure" : "heures")"
        case .missionControl:
            return String(format: "%02d00 HOURS", h24)
        case .eldritch:
            return "the \(Self.ordinalHours[index]) hour"
        case .latin:
            return "hora \(Self.romanHours[index]) \(isPM ? "p.m." : "a.m.")"
        }
    }
}
