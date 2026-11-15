import XCTest
@testable import FuzzyBar

final class CustomPersonalityTests: XCTestCase {
    private func decode(_ text: String) throws -> CustomPersonality {
        try CustomPersonality.decode(Data(text.utf8))
    }

    private func assertFails(_ text: String, _ expected: CustomPersonality.ImportError,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try decode(text), file: file, line: line) {
            XCTAssertEqual($0 as? CustomPersonality.ImportError, expected, file: file, line: line)
        }
    }

    private let minutes = (0..<12).map { String(format: ":%02d  s%d", $0 * 5, $0 + 1) }.joined(separator: "\n")
    private let hours12 = ([12] + Array(1...11)).map { "\($0)  h\($0 % 12)" }.joined(separator: "\n")

    /// A minimal valid file with `extra` lines after the name.
    private func file(_ extra: String = "", minutes: String? = nil, hours: String? = nil) -> String {
        "name: X\n\(extra)\n\(minutes ?? self.minutes)\n\(hours ?? hours12)\n"
    }

    private var pirateURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Examples/Pirate.fuzzybar")
    }

    func testThePirateExampleImports() throws {
        let pirate = try CustomPersonality.decode(Data(contentsOf: pirateURL))
        XCTAssertEqual(pirate.name, "Pirate")
        XCTAssertEqual(pirate.phrase(hour: 20, minute: 40), "twenty 'fore nine, arr")
        XCTAssertEqual(pirate.phrase(hour: 23, minute: 58), "nigh on twelve, arr")
        XCTAssertEqual(pirate.phrase(hour: 0, minute: 1), "smack on twelve, arr")
        XCTAssertLessThanOrEqual(pirate.longestReading.count, SpecialTime.maxLength, pirate.longestReading)
    }

    /// The example is exactly what Save as Template writes, so the two
    /// can't drift apart.
    func testTheExampleIsWhatSaveAsTemplateWrites() throws {
        let data = try Data(contentsOf: pirateURL)
        XCTAssertEqual(String(decoding: try CustomPersonality.decode(data).encoded(), as: UTF8.self),
                       String(decoding: data, as: UTF8.self))
    }

    /// Saving any slot-table personality as a template and reading it back
    /// gives the same reading at every minute, so the format can say
    /// everything the built-in ones do.
    func testEveryTemplateRoundTripsExactly() throws {
        for personality in Personality.allCases {
            guard let template = personality.template else {
                XCTAssertNil(personality.slotPhrases, "\(personality) has a slot table but no template")
                continue
            }
            let read = try CustomPersonality.decode(template.encoded())
            for hour in 0..<24 {
                for minute in 0..<60 {
                    XCTAssertEqual(read.phrase(hour: hour, minute: minute),
                                   FuzzyTime.phrase(hour: hour, minute: minute, personality: personality),
                                   "\(personality) \(hour):\(minute)")
                }
            }
        }
        XCTAssertNil(Personality.spoken.template)
        XCTAssertNil(Personality.vague.template)
        XCTAssertNil(Personality.exact.template)
        XCTAssertNil(Personality.spanish.template)
        XCTAssertNil(Personality.french.template)
        // am/pm personalities need all 24 hours; the rest fold to 12.
        XCTAssertEqual(Personality.classic.template?.hours.count, 24)
        XCTAssertEqual(Personality.german.template?.hours.count, 12)
    }

    /// Only the app bundle declares the type, so this runs under the Xcode
    /// project's hosted tests and skips under SwiftPM.
    func testTheFileTypeIsDeclared() throws {
        try XCTSkipUnless(Bundle.main.bundleIdentifier == "dev.plumpbug.fuzzybar", "needs the app's Info.plist")
        XCTAssertEqual(CustomPersonality.contentType.preferredFilenameExtension, "fuzzybar")
        XCTAssertTrue(CustomPersonality.contentType.conforms(to: .plainText))
    }

    func testDefaultsAndOrderDoNotMatter() throws {
        // Hours first, minutes shuffled, no format or next hour from.
        let shuffled = file(minutes: minutes.split(separator: "\n").reversed().joined(separator: "\n"))
        let p = try decode(shuffled)
        XCTAssertEqual(p.format, "{phrase} {hour}")
        XCTAssertEqual(p.nextHourFrom, 7)
        XCTAssertEqual(p.phrase(hour: 9, minute: 35), "s8 h10")
        XCTAssertEqual(p.phrase(hour: 9, minute: 30), "s7 h9")
        XCTAssertEqual(p.phrase(hour: 0, minute: 0), "s1 h0")
    }

    func testTwentyFourHoursAndHourFirstFormats() throws {
        let h24 = (0..<24).map { "\($0)  H\($0)" }.joined(separator: "\n")
        let p = try decode(file("format: {hour}: {phrase}\nnext hour from: :25", hours: h24))
        XCTAssertEqual(p.hours.count, 24)
        XCTAssertEqual(p.phrase(hour: 21, minute: 20), "H21: s5")
        XCTAssertEqual(p.phrase(hour: 21, minute: 25), "H22: s6")
        XCTAssertEqual(p.phrase(hour: 23, minute: 59), "H0: s12")
    }

    func testTheWordsAreTakenAsWritten() throws {
        let odd = minutes.replacingOccurrences(of: ":00  s1", with: ":00\t{hour} o'clock, “sort of”   # not a note")
        let p = try decode("# a note\n\n  name:  Pi: rate  \n" + odd + "\n" + hours12)
        XCTAssertEqual(p.name, "Pi: rate")
        XCTAssertEqual(p.phrase(hour: 3, minute: 0), "{hour} o'clock, “sort of”   # not a note h3")
    }

    /// TextEdit and friends save in more than one way.
    func testLineEndingsBOMAndUTF16() throws {
        let text = file("next hour from: 35")
        XCTAssertEqual(try decode(text.replacingOccurrences(of: "\n", with: "\r\n")).slots.count, 12)
        XCTAssertEqual(try CustomPersonality.decode(Data(("\u{FEFF}" + text).utf8)).name, "X")
        XCTAssertEqual(try CustomPersonality.decode(text.data(using: .utf16)!).name, "X")
        // Line numbers count CRLF as one break.
        assertFails("name: X\r\n\r\nnonsense\r\n", .unreadableLine(3))
    }

    func testErrorsNameTheLineAndLabel() {
        assertFails("{\\rtf1\\ansi name: X}", .richText)
        XCTAssertThrowsError(try CustomPersonality.decode(Data([0xFF, 0xFE, 0xFF, 0xD8, 0x00]))) {
            XCTAssertEqual($0 as? CustomPersonality.ImportError, .notText)
        }
        assertFails("name: X\nwhat is this", .unreadableLine(2))
        assertFails("name: X\nnmae: Y", .unknownSetting(2, "nmae"))
        assertFails("name: \n", .noWords(1, "name"))
        assertFails(file().replacingOccurrences(of: ":05  s2", with: ":05  "), .noWords(4, ":05"))
        assertFails(file().replacingOccurrences(of: ":05  s2", with: ":07  s2"), .badMinute(4, ":07"))
        assertFails(file().replacingOccurrences(of: ":05  s2", with: ":00  again"), .duplicate(4, ":00"))
        assertFails(file().replacingOccurrences(of: "\n9  h9", with: "\n25  h9"), .badHour(24, "25"))
        assertFails(file().replacingOccurrences(of: "\n9  h9", with: "\n9pm  h9"), .badHour(24, "9pm"))
        assertFails(file("next hour from: :37"), .badNextHour(2, ":37"))
        assertFails(file("next hour from: :00"), .badNextHour(2, ":00"))
        assertFails(file().replacingOccurrences(of: "name: X\n", with: ""), .missingName)
        assertFails(file().replacingOccurrences(of: ":40  s9\n", with: ""), .missingMinute(":40"))
        assertFails(file().replacingOccurrences(of: "\n7  h7", with: ""), .missingHour("7", twentyFour: false))
        assertFails(file().replacingOccurrences(of: "\n7  h7", with: "\n13  h1"), .missingHour("0", twentyFour: true))
        assertFails(file("format: {phrase}"), .formatNeedsPlaceholders)
        XCTAssertEqual(CustomPersonality.ImportError.missingMinute(":40").errorDescription,
                       "The file needs a line for :40.")
    }

    @MainActor
    func testImportSwitchesReplacesByNameAndRemoveFallsBack() throws {
        let defaults = scratchDefaults()
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 20, minute: 40))!
        let clock = Clock(dateProvider: { now }, defaults: defaults)
        let store = clock.personalities
        store.personality = .german

        let pirate = try CustomPersonality.decode(Data(contentsOf: pirateURL))
        XCTAssertFalse(store.importPersonality(pirate))
        XCTAssertEqual(clock.fuzzy, "twenty 'fore nine, arr")
        let id = try XCTUnwrap(store.customPersonalityID)

        // Same name, different case: an update, not a second entry.
        var edited = pirate
        edited.name = "PIRATE"
        edited.format = "{phrase} {hour}, yarr"
        XCTAssertTrue(store.importPersonality(edited))
        XCTAssertEqual(store.customPersonalities.count, 1)
        XCTAssertEqual(store.customPersonalityID, id)
        XCTAssertEqual(clock.fuzzy, "twenty 'fore nine, yarr")

        // Survives a relaunch.
        let reloaded = Clock(dateProvider: { now }, defaults: defaults)
        XCTAssertEqual(reloaded.personalities.customPersonalityID, id)
        XCTAssertEqual(reloaded.fuzzy, "twenty 'fore nine, yarr")

        // Removing the active one goes back to the built-in it replaced.
        store.removePersonality(id: id)
        XCTAssertNil(store.customPersonalityID)
        XCTAssertEqual(clock.fuzzy, "zwanzig vor neun")
        XCTAssertNil(PersonalityStore(defaults: defaults).customPersonalityID)
    }

    /// What Import and drag-and-drop say: imported or updated, a warning
    /// when a reading could run behind the notch, and why a file failed.
    @MainActor
    func testImportingAFileSaysHowItWent() throws {
        let store = PersonalityStore(defaults: scratchDefaults())
        XCTAssertEqual(store.importPersonality(from: pirateURL), PersonalityMessage(text: "Imported Pirate."))
        XCTAssertEqual(store.importPersonality(from: pirateURL), PersonalityMessage(text: "Updated Pirate."))

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        func written(_ name: String, _ text: String) throws -> URL {
            let url = folder.appendingPathComponent(name)
            try Data(text.utf8).write(to: url)
            return url
        }

        let long = try written("Long.fuzzybar", file(minutes: minutes.replacingOccurrences(of: "s12", with: "a very long way from anywhere")))
        let warned = store.importPersonality(from: long)
        XCTAssertFalse(warned.isError)
        XCTAssertTrue(warned.text.hasPrefix("Imported X. Its longest reading, \"a very long way from anywhere h1"), warned.text)
        XCTAssertTrue(warned.text.hasSuffix("is 33 characters; past 30 it can end up behind the notch."), warned.text)

        XCTAssertEqual(store.importPersonality(from: try written("Bad.fuzzybar", "name: Bad\n")),
                       PersonalityMessage(text: "The file needs a line for :00.", isError: true))
        XCTAssertEqual(store.importPersonality(from: folder.appendingPathComponent("Gone.fuzzybar")),
                       PersonalityMessage(text: "Couldn't read Gone.fuzzybar.", isError: true))
        XCTAssertEqual(store.customPersonalities.map(\.name), ["Pirate", "X"])
    }

    @MainActor
    func testAMissingActiveCustomFallsBackAtLaunch() {
        let defaults = scratchDefaults()
        defaults.set(UUID().uuidString, forKey: PersonalityStore.customActiveKey)
        XCTAssertNil(PersonalityStore(defaults: defaults).customPersonalityID)
        XCTAssertNil(defaults.string(forKey: PersonalityStore.customActiveKey))
    }

    /// Special times win over everything, a custom personality included,
    /// and the ticker follows the custom one's boundaries.
    @MainActor
    func testSpecialTimesWinAndTheTickerFollowsTheCustomOne() throws {
        let cal = gregorian()
        func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ m: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: m))!
        }
        let pirate = try CustomPersonality.decode(Data(contentsOf: pirateURL))
        let tea = SpecialTime(hour: 16, minute: 0, text: "tea")
        func text(_ date: Date) -> String {
            Clock.text(for: date, calendar: cal, personality: .spoken, custom: pirate, specialTimes: [tea])
        }
        XCTAssertEqual(text(at(2026, 9, 22, 16, 0)), "tea")
        XCTAssertEqual(text(at(2027, 1, 1, 0, 0)), "Happy New Year!")
        XCTAssertEqual(text(at(2026, 9, 22, 16, 1)), "smack on four, arr")

        // Pirate holds "nigh on" to :59 like the ported ones; Spoken would flip at :58.
        XCTAssertEqual(Clock.nextTick(after: at(2026, 9, 22, 9, 57), popoverVisible: false, calendar: cal,
                                      personality: .spoken, custom: pirate),
                       at(2026, 9, 22, 10, 0).addingTimeInterval(0.05))
    }
}
