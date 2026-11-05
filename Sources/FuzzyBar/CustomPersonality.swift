import Foundation
import UniformTypeIdentifiers

/// A personality from a file the user wrote, with every word supplied. The
/// built-in slot-table personalities run on this too (`Personality.template`).
struct CustomPersonality: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    /// Contains `{phrase}` and `{hour}`, e.g. "{phrase} {hour}".
    var format: String
    /// Twelve five-minute slots: 0 is on the hour, 11 is "almost".
    var slots: [String]
    /// Twelve hour names (twelve, one, ... eleven), or twenty-four
    /// (midnight through 11 pm) where am and pm read differently.
    var hours: [String]
    /// The slot from which the hour named is the next one: 7 ("twenty-five
    /// to") for English, 5 for German's "fünf vor halb".
    var nextHourFrom: Int

    static let contentType = UTType(exportedAs: "dev.plumpbug.fuzzybar.personality", conformingTo: .plainText)

    func phrase(hour: Int, minute: Int) -> String {
        // 58 and 59 round to 12, past the last slot; they stay on the
        // "almost" one, which already names the next hour.
        let slot = min(Int((Double(minute) / 5.0).rounded()), 11)
        let h24 = ((slot < nextHourFrom ? hour : hour + 1) % 24 + 24) % 24
        let hourText = hours.count == 24 ? hours[h24] : hours[h24 % 12]
        // One pass, so a phrase that happens to contain "{hour}" stays as written.
        return format.components(separatedBy: "{phrase}")
            .map { $0.replacingOccurrences(of: "{hour}", with: hourText) }
            .joined(separator: slots[slot])
    }

    /// The longest thing it can put in the menubar, for the notch warning.
    var longestReading: String {
        (0..<24).flatMap { h in stride(from: 0, to: 60, by: 5).map { phrase(hour: h, minute: $0) } }
            .max { $0.count < $1.count } ?? ""
    }
}

// MARK: - Files

/// A .fuzzybar file is plain text meant for TextEdit: every line says which
/// time it's for, so there's no quoting to get wrong and nothing to look up.
/// docs/PERSONALITY_FORMAT.md is the format as users see it.
extension CustomPersonality {
    enum ImportError: LocalizedError, Equatable {
        case notText
        case richText
        case unreadableLine(Int)
        case unknownSetting(Int, String)
        case noWords(Int, String)
        case duplicate(Int, String)
        case badMinute(Int, String)
        case badHour(Int, String)
        case badNextHour(Int, String)
        case missingName
        case missingMinute(String)
        case missingHour(String, twentyFour: Bool)
        case formatNeedsPlaceholders

        var errorDescription: String? {
            switch self {
            case .notText:
                return "That file isn't plain text. Save as Template makes one to start from."
            case .richText:
                return "That file is rich text. In TextEdit, choose Format > Make Plain Text, save, and import it again."
            case let .unreadableLine(n):
                return "Line \(n) isn't a setting, a minute line like \":05 five past\", or an hour line like \"9 nine\"."
            case let .unknownSetting(n, key):
                return "Line \(n): FuzzyBar doesn't know the setting \"\(key)\". It knows name, format and next hour from."
            case let .noWords(n, label):
                return "Line \(n): \(label) has no words after it."
            case let .duplicate(n, label):
                return "Line \(n): \(label) is there twice."
            case let .badMinute(n, label):
                return "Line \(n): \(label) isn't one of the minutes. They go in fives, :00 to :55."
            case let .badHour(n, label):
                return "Line \(n): \(label) isn't an hour. Use 12 and 1 to 11, or 0 to 23."
            case let .badNextHour(n, value):
                return "Line \(n): next hour from needs a minute between :05 and :55, not \"\(value)\"."
            case .missingName:
                return "The file needs a name line, like \"name: Pirate\"."
            case let .missingMinute(label):
                return "The file needs a line for \(label)."
            case let .missingHour(label, twentyFour):
                return "The file needs a line for hour \(label)" + (twentyFour ? " (it uses 0 to 23)." : ".")
            case .formatNeedsPlaceholders:
                return "The format line needs both {phrase} and {hour}."
            }
        }
    }

    private static let minuteLabels = (0..<12).map { String(format: ":%02d", $0 * 5) }
    private static let twelveHourLabels = [12] + Array(1...11)

    /// Reads and checks a file. Problems are reported by line and by label,
    /// since the person reading the message is looking at the file in TextEdit.
    static func decode(_ data: Data) throws -> CustomPersonality {
        guard var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw ImportError.notText
        }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        if text.hasPrefix("{\\rtf") { throw ImportError.richText }

        var name: String?
        var format = "{phrase} {hour}"
        var nextHourFrom = 7
        var slots: [Int: String] = [:]
        var hours: [Int: String] = [:]

        // Split on Character newlines so "\r\n" counts as one line break.
        for (index, raw) in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
            let n = index + 1
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if line.hasPrefix(":") {
                let (label, words) = split(line)
                guard let i = minuteLabels.firstIndex(of: label) else { throw ImportError.badMinute(n, label) }
                guard !words.isEmpty else { throw ImportError.noWords(n, label) }
                guard slots[i] == nil else { throw ImportError.duplicate(n, label) }
                slots[i] = words
            } else if line.first!.isNumber {
                let (label, words) = split(line)
                guard let hour = Int(label), (0...23).contains(hour), label.count <= 2 else {
                    throw ImportError.badHour(n, label)
                }
                guard !words.isEmpty else { throw ImportError.noWords(n, label) }
                guard hours[hour] == nil else { throw ImportError.duplicate(n, label) }
                hours[hour] = words
            } else if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces)
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                switch key.lowercased() {
                case "name":
                    guard !value.isEmpty else { throw ImportError.noWords(n, "name") }
                    name = value
                case "format":
                    format = value
                case "next hour from":
                    let digits = value.hasPrefix(":") ? String(value.dropFirst()) : value
                    guard let minute = Int(digits), minute % 5 == 0, (5...55).contains(minute) else {
                        throw ImportError.badNextHour(n, value)
                    }
                    nextHourFrom = minute / 5
                default:
                    throw ImportError.unknownSetting(n, key)
                }
            } else {
                throw ImportError.unreadableLine(n)
            }
        }

        guard let name else { throw ImportError.missingName }
        guard format.contains("{phrase}"), format.contains("{hour}") else { throw ImportError.formatNeedsPlaceholders }
        if let missing = (0..<12).first(where: { slots[$0] == nil }) {
            throw ImportError.missingMinute(minuteLabels[missing])
        }
        // Any of 0 or 13 to 23 means a 24-hour table; otherwise 12 and 1 to 11.
        let twentyFour = hours.keys.contains { $0 == 0 || $0 > 12 }
        let needed = twentyFour ? Array(0...23) : twelveHourLabels
        if let missing = needed.first(where: { hours[$0] == nil }) {
            throw ImportError.missingHour(String(missing), twentyFour: twentyFour)
        }
        // Stored in clock order: index 0 is twelve (or midnight).
        let ordered = twentyFour ? (0...23).map { hours[$0]! } : (0..<12).map { hours[$0 == 0 ? 12 : $0]! }
        return CustomPersonality(name: name, format: format, slots: (0..<12).map { slots[$0]! },
                                 hours: ordered, nextHourFrom: nextHourFrom)
    }

    /// ":05  five past" -> (":05", "five past"); the label ends at the first space or tab.
    private static func split(_ line: String) -> (String, String) {
        guard let gap = line.firstIndex(where: \.isWhitespace) else { return (line, "") }
        return (String(line[..<gap]), line[gap...].trimmingCharacters(in: .whitespaces))
    }

    /// A file a person can edit in TextEdit, with the instructions in it.
    func encoded() -> Data {
        let twentyFour = hours.count == 24
        let hourLabels = twentyFour ? (0...23).map(String.init) : Self.twelveHourLabels.map(String.init)
        let hourWords = twentyFour ? hours : Self.twelveHourLabels.map { hours[$0 % 12] }
        var lines = [
            "# A FuzzyBar personality. Change the words after each label, keep the",
            "# labels, then import this file from FuzzyBar's Preferences. Lines",
            "# starting with # are notes, and FuzzyBar ignores them.",
            "",
            "name: \(name)",
            "",
            "# How the two halves go together in the menubar.",
            "format: \(format)",
            "",
            "# The minute from which the hour named is the next one: with :35,",
            "# 8:35 names nine, not eight.",
            "next hour from: \(Self.minuteLabels[nextHourFrom])",
            "",
            "# What the minutes say. Each line covers the five minutes around it,",
            "# and :55 carries on to :59.",
        ]
        lines += zip(Self.minuteLabels, slots).map { "\($0)  \($1)" }
        lines += [
            "",
            twentyFour
                ? "# The hours, 0 (midnight) to 23."
                : "# The hours. For different words in the morning and evening, use 0 to 23 instead.",
        ]
        lines += zip(hourLabels, hourWords).map { $0.padding(toLength: 4, withPad: " ", startingAt: 0) + $1 }
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }
}

// MARK: - Templates

extension Personality {
    /// This personality as a custom one: what Save as Template writes, and
    /// what `FuzzyTime` phrases it with. Spoken and Vague don't use the
    /// twelve-slot table, so they have none.
    var template: CustomPersonality? {
        guard let slots = slotPhrases else { return nil }
        let hours = (0..<24).map { hourText(displayHour: $0) }
        let halves = hours[0..<12].elementsEqual(hours[12..<24])
        return CustomPersonality(name: title, format: "{phrase}\(joiner){hour}", slots: slots,
                                 hours: halves ? Array(hours[0..<12]) : hours, nextHourFrom: hourAdvanceSlot)
    }
}
