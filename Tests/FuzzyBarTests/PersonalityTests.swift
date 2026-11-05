import XCTest
@testable import FuzzyBar

/// Expectations ported from LittleFuzzyClock's tests/test_fuzzy_time.py,
/// with the phrase and hour halves joined the way the menubar shows them.
final class PersonalityTests: XCTestCase {
    private func p(_ h: Int, _ m: Int, _ personality: Personality) -> String {
        FuzzyTime.phrase(hour: h, minute: m, personality: personality)
    }

    func testSpokenIsTheDefaultAndUnchanged() {
        XCTAssertEqual(Personality.default, .spoken)
        XCTAssertEqual(p(20, 40, .spoken), FuzzyTime.phrase(hour: 20, minute: 40))
        XCTAssertEqual(p(9, 30, .spoken), "half past nine")
        XCTAssertEqual(p(11, 58, .spoken), "twelve o'clock")
    }

    func testHalfPastNineAcrossEveryPersonality() {
        XCTAssertEqual(p(9, 30, .classic), "half past nine am")
        XCTAssertEqual(p(9, 30, .shakespeare), "'tis half past nine of the clock")
        XCTAssertEqual(p(9, 30, .german), "halb zehn")
        XCTAssertEqual(p(9, 30, .missionControl), "MIDPOINT, 0900 HOURS")
        XCTAssertEqual(p(9, 30, .eldritch), "the half-hour, the ninth hour")
        XCTAssertEqual(p(9, 30, .latin), "media post hora IX a.m.")
    }

    func testClassic() {
        XCTAssertEqual(p(9, 0, .classic), "just after nine am")
        XCTAssertEqual(p(9, 45, .classic), "quarter to ten am")
        XCTAssertEqual(p(9, 57, .classic), "almost ten am")
        XCTAssertEqual(p(9, 59, .classic), "almost ten am")
        XCTAssertEqual(p(11, 58, .classic), "almost twelve pm")
        XCTAssertEqual(p(23, 58, .classic), "almost twelve am")
        XCTAssertEqual(p(0, 0, .classic), "just after twelve am")
        XCTAssertEqual(p(12, 0, .classic), "just after twelve pm")
        XCTAssertEqual(p(15, 30, .classic), "half past three pm")
        XCTAssertEqual(p(11, 45, .classic), "quarter to twelve pm")
    }

    /// One reading per slot, in order, so swapping two slot phrases fails.
    func testClassicReadsEverySlotInOrder() {
        XCTAssertEqual(stride(from: 0, to: 60, by: 5).map { p(9, $0, .classic) }, [
            "just after nine am", "a little past nine am", "ten past nine am", "quarter past nine am",
            "twenty past nine am", "twenty-five past nine am", "half past nine am", "twenty-five to ten am",
            "twenty to ten am", "quarter to ten am", "ten to ten am", "almost ten am",
        ])
    }

    func testShakespeare() {
        XCTAssertEqual(p(9, 0, .shakespeare), "'tis just past nine of the clock")
        XCTAssertEqual(p(9, 15, .shakespeare), "'tis a quarter past nine of the clock")
        XCTAssertEqual(p(9, 45, .shakespeare), "a quarter 'fore ten of the clock")
        XCTAssertEqual(p(9, 58, .shakespeare), "almost ten of the clock")
        XCTAssertEqual(p(23, 58, .shakespeare), "almost twelve of the clock")
    }

    func testGermanAdvancesHourAtTwentyFivePast() {
        XCTAssertEqual(p(9, 0, .german), "kurz nach neun")
        XCTAssertEqual(p(9, 5, .german), "fünf nach neun")
        XCTAssertEqual(p(9, 15, .german), "viertel nach neun")
        XCTAssertEqual(p(9, 22, .german), "zwanzig nach neun")
        XCTAssertEqual(p(9, 23, .german), "fünf vor halb zehn")
        XCTAssertEqual(p(9, 25, .german), "fünf vor halb zehn")
        XCTAssertEqual(p(9, 35, .german), "fünf nach halb zehn")
        XCTAssertEqual(p(9, 45, .german), "viertel vor zehn")
        XCTAssertEqual(p(9, 58, .german), "kurz vor zehn")
        XCTAssertEqual(p(11, 30, .german), "halb zwölf")
        XCTAssertEqual(p(0, 30, .german), "halb eins")
        XCTAssertEqual(p(23, 58, .german), "kurz vor zwölf")
    }

    func testMissionControlUsesTwentyFourHourTime() {
        XCTAssertEqual(p(9, 0, .missionControl), "ON THE MARK, 0900 HOURS")
        XCTAssertEqual(p(9, 15, .missionControl), "T+15 MINUTES, 0900 HOURS")
        XCTAssertEqual(p(9, 35, .missionControl), "T-25 MINUTES, 1000 HOURS")
        XCTAssertEqual(p(9, 45, .missionControl), "T-15 MINUTES, 1000 HOURS")
        XCTAssertEqual(p(9, 58, .missionControl), "IMMINENT, 1000 HOURS")
        XCTAssertEqual(p(21, 0, .missionControl), "ON THE MARK, 2100 HOURS")
        XCTAssertEqual(p(15, 30, .missionControl), "MIDPOINT, 1500 HOURS")
        XCTAssertEqual(p(12, 0, .missionControl), "ON THE MARK, 1200 HOURS")
        XCTAssertEqual(p(23, 58, .missionControl), "IMMINENT, 0000 HOURS")
        XCTAssertEqual(p(0, 0, .missionControl), "ON THE MARK, 0000 HOURS")
    }

    func testEldritch() {
        XCTAssertEqual(p(9, 0, .eldritch), "newly woken, the ninth hour")
        XCTAssertEqual(p(9, 45, .eldritch), "quarter 'fore, the tenth hour")
        XCTAssertEqual(p(9, 58, .eldritch), "the stars are right, the tenth hour")
        XCTAssertEqual(p(10, 45, .eldritch), "quarter 'fore, the eleventh hour")
        XCTAssertEqual(p(23, 58, .eldritch), "the stars are right, the twelfth hour")
        XCTAssertEqual(p(0, 30, .eldritch), "the half-hour, the twelfth hour")
    }

    func testLatin() {
        XCTAssertEqual(p(9, 0, .latin), "modo post hora IX a.m.")
        XCTAssertEqual(p(9, 15, .latin), "quadrans post hora IX a.m.")
        XCTAssertEqual(p(9, 45, .latin), "quadrans ante hora X a.m.")
        XCTAssertEqual(p(9, 58, .latin), "fere hora X a.m.")
        XCTAssertEqual(p(15, 30, .latin), "media post hora III p.m.")
        XCTAssertEqual(p(23, 58, .latin), "fere hora XII a.m.")
    }

    func testVagueNamesThePartOfTheDay() {
        XCTAssertEqual(p(0, 0, .vague), "way too late")
        XCTAssertEqual(p(4, 59, .vague), "way too late")
        XCTAssertEqual(p(5, 0, .vague), "early")
        XCTAssertEqual(p(6, 59, .vague), "early")
        XCTAssertEqual(p(7, 0, .vague), "morning")
        XCTAssertEqual(p(11, 29, .vague), "morning")
        XCTAssertEqual(p(11, 30, .vague), "around noon")
        XCTAssertEqual(p(12, 59, .vague), "around noon")
        XCTAssertEqual(p(13, 0, .vague), "after lunch")
        XCTAssertEqual(p(15, 0, .vague), "afternoon")
        XCTAssertEqual(p(18, 0, .vague), "evening")
        XCTAssertEqual(p(20, 40, .vague), "evening")
        XCTAssertEqual(p(20, 59, .vague), "evening")
        XCTAssertEqual(p(21, 0, .vague), "late")
        XCTAssertEqual(p(23, 59, .vague), "late")
    }

    /// Every minute of the day reads one of the parts, and the parts come
    /// round in order with no gaps: one change a day per part.
    func testVagueCoversTheDayInOrder() {
        let parts = Personality.vagueParts
        XCTAssertEqual(parts.first?.start, 0)
        XCTAssertEqual(parts.map(\.start), parts.map(\.start).sorted())
        var seen: [String] = []
        for minute in 0..<(24 * 60) {
            let text = p(minute / 60, minute % 60, .vague)
            if seen.last != text { seen.append(text) }
        }
        XCTAssertEqual(seen, parts.map(\.phrase))
    }

    /// Vague holds one phrase for hours, so the ticker should wake at the
    /// next part and otherwise sleep in its usual five-minute steps.
    @MainActor
    func testVagueTicksAtPartBoundaries() {
        let cal = gregorian()
        func at(_ hour: Int, _ minute: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: hour, minute: minute))!
        }
        func tick(_ date: Date) -> Date {
            Clock.nextTick(after: date, popoverVisible: false, calendar: cal, personality: .vague)
        }
        XCTAssertEqual(tick(at(11, 27)), at(11, 30).addingTimeInterval(0.05))
        XCTAssertEqual(tick(at(20, 58)), at(21, 0).addingTimeInterval(0.05))
        XCTAssertEqual(tick(at(23, 59)), at(24, 0).addingTimeInterval(0.05))
        XCTAssertEqual(tick(at(9, 0)), at(9, 5).addingTimeInterval(0.05))
    }

    /// Minutes 57-59 must name the *next* hour in every personality: 58 and
    /// 59 round past the last slot, and the cap at 11 keeps them on it.
    func testAlmostNextHourNeverWraps() {
        for personality in Personality.allCases where personality.slotPhrases != nil {
            let slots = personality.slotPhrases!
            for hour in 0..<24 {
                for minute in 57...59 {
                    let text = p(hour, minute, personality)
                    XCTAssertTrue(text.hasPrefix(slots[11]), "\(personality) \(hour):\(minute) -> \(text)")
                    XCTAssertTrue(text.hasSuffix(personality.hourText(displayHour: (hour + 1) % 24)),
                                  "\(personality) \(hour):\(minute) -> \(text)")
                }
            }
        }
    }

    func testSlotTablesAreWellFormed() {
        for personality in Personality.allCases where personality.slotPhrases != nil {
            XCTAssertEqual(personality.slotPhrases!.count, 12, "\(personality)")
            XCTAssertTrue((1...11).contains(personality.hourAdvanceSlot), "\(personality)")
        }
    }

    /// Switching personality at 9:58 must move the pending tick from spoken's
    /// 10:03 boundary to the ported 10:00 one, or the menubar stays stale.
    @MainActor
    func testChangingPersonalityReschedulesTick() {
        let defaults = scratchDefaults()
        // Clock phrases in the current calendar, so build the date there too.
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 9, minute: 58))!
        let clock = Clock(dateProvider: { now }, defaults: defaults)
        XCTAssertEqual(clock.fuzzy, "ten o'clock")

        clock.personalities.personality = .classic
        XCTAssertEqual(clock.fuzzy, "almost ten am")
        XCTAssertEqual(clock.timerFireDate, now.addingTimeInterval(120 + 0.05))

        now = now.addingTimeInterval(120)
        clock.refresh()
        XCTAssertEqual(clock.fuzzy, "just after ten am")
    }

    @MainActor
    func testClockPersistsPersonalityAndRephrases() {
        let defaults = scratchDefaults()
        let cal = gregorian()
        let date = cal.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 9, minute: 30))!

        let clock = Clock(dateProvider: { date }, defaults: defaults)
        XCTAssertEqual(clock.personalities.personality, .spoken)
        clock.personalities.personality = .missionControl
        XCTAssertEqual(defaults.string(forKey: Personality.defaultsKey), "missionControl")
        XCTAssertEqual(clock.fuzzy, FuzzyTime.phrase(for: date, personality: .missionControl))

        XCTAssertEqual(PersonalityStore(defaults: defaults).personality, .missionControl)

        defaults.set("not-a-personality", forKey: Personality.defaultsKey)
        XCTAssertEqual(PersonalityStore(defaults: defaults).personality, .spoken)
    }

    func testEightPersonalitiesShip() {
        XCTAssertEqual(Personality.allCases.map(\.rawValue),
                       ["spoken", "classic", "shakespeare", "german",
                        "missionControl", "eldritch", "latin", "vague"])
    }

    func testPreRenameValuesMigrateAndWithdrawnOnesFallBack() {
        XCTAssertEqual(Personality.stored("hal"), .missionControl)
        XCTAssertEqual(Personality.stored("cthulhu"), .eldritch)
        XCTAssertNil(Personality.stored("klingon"))
        XCTAssertNil(Personality.stored("belter"))
        for personality in Personality.allCases {
            XCTAssertEqual(Personality.stored(personality.rawValue), personality)
        }
        XCTAssertNil(Personality.stored("not-a-personality"))
    }

    @MainActor
    func testStoreMigratesAndRewritesAPreRenameChoice() {
        let defaults = scratchDefaults()

        defaults.set("cthulhu", forKey: Personality.defaultsKey)
        XCTAssertEqual(PersonalityStore(defaults: defaults).personality, .eldritch)
        // Rewritten once, so the next launch reads it straight.
        XCTAssertEqual(defaults.string(forKey: Personality.defaultsKey), "eldritch")
        XCTAssertEqual(PersonalityStore(defaults: defaults).personality, .eldritch)
    }

    @MainActor
    func testStoreFallsBackFromAWithdrawnChoice() {
        let defaults = scratchDefaults()

        for retired in ["klingon", "belter"] {
            defaults.set(retired, forKey: Personality.defaultsKey)
            XCTAssertEqual(PersonalityStore(defaults: defaults).personality, .spoken)
            XCTAssertEqual(defaults.string(forKey: Personality.defaultsKey), "spoken")
        }
    }

    /// The ticker must follow the active personality: spoken flips to
    /// "ten o'clock" at 9:58, classic holds "almost ten" until 10:00.
    @MainActor
    func testTickFollowsTheActivePersonality() {
        let cal = gregorian()
        func at(_ minute: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 9, minute: minute))!
        }
        XCTAssertEqual(Clock.nextTick(after: at(57), popoverVisible: false, calendar: cal, personality: .spoken),
                       at(58).addingTimeInterval(0.05))
        XCTAssertEqual(Clock.nextTick(after: at(57), popoverVisible: false, calendar: cal, personality: .classic),
                       at(60).addingTimeInterval(0.05))
    }
}
