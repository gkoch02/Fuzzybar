import Foundation

/// Converts a clock time into a fuzzy phrase like "twenty to nine".
/// Spoken, FuzzyBar's own, rounds to the nearest five minutes (37 -> 35,
/// 38 -> 40) and turns to the next hour at :58. Vague names the part of the
/// day, and Exact every minute. Spanish and French put the hour first. The LittleFuzzyClock personalities run on the same twelve-slot
/// engine as imported ones (`CustomPersonality.phrase`).
enum FuzzyTime {
    static func phrase(hour: Int, minute: Int, personality: Personality = .default) -> String {
        if personality == .vague { return vaguePhrase(hour: hour, minute: minute) }
        if personality == .exact { return exactPhrase(hour: hour, minute: minute) }
        if let minutes = personality.minutePhrases {
            return hourFirstPhrase(hour: hour, minute: minute, personality: personality, minutes: minutes)
        }
        guard let table = personality.template else { return spokenPhrase(hour: hour, minute: minute) }
        return table.phrase(hour: hour, minute: minute)
    }

    /// No rounding: the parts of the day start on the exact minute.
    private static func vaguePhrase(hour: Int, minute: Int) -> String {
        let minuteOfDay = hour * 60 + minute
        return Personality.vagueParts.last { $0.start <= minuteOfDay }!.phrase
    }

    /// The minute as a digital clock is read aloud, "eight forty-four" and
    /// "nine oh five", except on the hour and the quarters, which keep
    /// Spoken's words.
    private static func exactPhrase(hour: Int, minute: Int) -> String {
        let hourWord = Personality.englishHours[hour % 12]
        switch minute {
        case 0: return "\(hourWord) o'clock"
        case 15: return "quarter past \(hourWord)"
        case 30: return "half past \(hourWord)"
        case 45: return "quarter to \(Personality.englishHours[(hour + 1) % 12])"
        case ..<10: return "\(hourWord) oh \(Personality.englishMinutes[minute])"
        case ..<20: return "\(hourWord) \(Personality.englishMinutes[minute])"
        default:
            let tens = Personality.englishTens[minute / 10]
            let ones = Personality.englishMinutes[minute % 10]
            return "\(hourWord) \(ones.isEmpty ? tens : "\(tens)-\(ones)")"
        }
    }

    /// "las nueve y cuarto", "neuf heures et quart": the slots and the turn
    /// to the next hour are the slot tables' (`CustomPersonality.phrase`),
    /// with the hour in front of all but "almost".
    private static func hourFirstPhrase(hour: Int, minute: Int, personality: Personality, minutes: [String]) -> String {
        let slot = min(Int((Double(minute) / 5.0).rounded()), 11)
        let displayHour = (slot < personality.hourAdvanceSlot ? hour : hour + 1) % 24
        let hourText = personality.hourText(displayHour: displayHour)
        if slot == 11 { return "\(minutes[slot]) \(hourText)" }

        var after = minutes[slot]
        if personality == .french {
            // "midi" and "minuit" are masculine, "une heure" is singular.
            let noon = displayHour % 12 == 0
            switch slot {
            case 0: after = noon ? "passé" : displayHour % 12 == 1 ? "passée" : "passées"
            case 6: after = noon ? "et demi" : "et demie"
            default: break
            }
        }
        return "\(hourText) \(after)"
    }

    private static func spokenPhrase(hour: Int, minute: Int) -> String {
        var h = hour
        var slot = Int((Double(minute) / 5.0).rounded())  // 0...12
        if slot == 12 { slot = 0; h += 1 }

        // Anything past the half hour references the *next* hour.
        let hourWord = Personality.englishHours[h % 12]
        let nextHourWord = Personality.englishHours[(h + 1) % 12]

        switch slot {
        case 0: return "\(hourWord) o'clock"
        case 1: return "five past \(hourWord)"
        case 2: return "ten past \(hourWord)"
        case 3: return "quarter past \(hourWord)"
        case 4: return "twenty past \(hourWord)"
        case 5: return "twenty-five past \(hourWord)"
        case 6: return "half past \(hourWord)"
        case 7: return "twenty-five to \(nextHourWord)"
        case 8: return "twenty to \(nextHourWord)"
        case 9: return "quarter to \(nextHourWord)"
        case 10: return "ten to \(nextHourWord)"
        case 11: return "five to \(nextHourWord)"
        default: return "\(hourWord) o'clock"
        }
    }

    static func phrase(for date: Date, calendar: Calendar = .current, personality: Personality = .default) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return phrase(hour: c.hour ?? 0, minute: c.minute ?? 0, personality: personality)
    }
}
