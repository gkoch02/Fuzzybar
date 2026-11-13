import XCTest
@testable import FuzzyBar

final class DateDisplayTests: XCTestCase {
    private let cal = gregorian("America/New_York")
    private let us = Locale(identifier: "en_US")

    private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ m: Int, _ s: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: m, second: s))!
    }

    func testEachStyle() {
        let friday = at(2026, 11, 13, 9, 0)
        let expected: [DateStyle: String] = [.weekday: "Friday", .monthDay: "Nov 13", .numeric: "11/13/26",
                                             .spoken: "Friday the thirteenth"]
        for style in DateStyle.allCases {
            XCTAssertEqual(style.text(for: friday, calendar: cal, locale: us), expected[style], "\(style)")
        }
    }

    func testStylesFollowTheLocaleExceptSpoken() {
        let friday = at(2026, 11, 13, 9, 0)
        let german = Locale(identifier: "de_DE")
        XCTAssertEqual(DateStyle.weekday.text(for: friday, calendar: cal, locale: german), "Freitag")
        XCTAssertEqual(DateStyle.numeric.text(for: friday, calendar: cal, locale: german), "13.11.26")
        XCTAssertEqual(DateStyle.numeric.text(for: friday, calendar: cal, locale: Locale(identifier: "en_GB")), "13/11/26")
        XCTAssertEqual(DateStyle.spoken.text(for: friday, calendar: cal, locale: german), "Friday the thirteenth")
    }

    func testSpokenOrdinalsForEveryDayOfAMonth() {
        let texts = (1...31).map { DateStyle.spoken.text(for: at(2026, 10, $0, 12, 0), calendar: cal, locale: us) }
        XCTAssertEqual(texts[0], "Thursday the first")
        XCTAssertEqual(texts[20], "Wednesday the twenty-first")
        XCTAssertEqual(texts[30], "Saturday the thirty-first")
        XCTAssertFalse(texts.contains { $0.contains(where: \.isNumber) })
    }

    /// The date is the one where the calendar is, not in UTC.
    func testUsesTheCalendarsTimeZone() {
        let lateEvening = at(2026, 11, 13, 23, 30)
        XCTAssertEqual(DateStyle.weekday.text(for: lateEvening, calendar: cal, locale: us), "Friday")
        XCTAssertEqual(DateStyle.weekday.text(for: lateEvening, calendar: gregorian(), locale: us), "Saturday")
    }

    func testPositionAndOff() {
        let friday = at(2026, 11, 13, 8, 40)
        func text(_ display: DateDisplay, _ times: [SpecialTime] = []) -> String {
            Clock.text(for: friday, calendar: cal, personality: .spoken, specialTimes: times, dateDisplay: display)
        }
        XCTAssertEqual(text(DateDisplay()), "twenty to nine")
        XCTAssertEqual(text(DateDisplay(isShown: false, style: .numeric, position: .after)), "twenty to nine")
        XCTAssertEqual(text(DateDisplay(isShown: true)), "Friday\(DateDisplay.gap)twenty to nine")
        XCTAssertEqual(text(DateDisplay(isShown: true, position: .after)), "twenty to nine\(DateDisplay.gap)Friday")
        // A special time replaces the phrase and leaves the date beside it.
        let tea = SpecialTime(hour: 8, minute: 40, text: "tea")
        XCTAssertEqual(text(DateDisplay(isShown: true, position: .after), [tea]), "tea\(DateDisplay.gap)Friday")
    }

    /// Spoken reads "twelve o'clock" from two minutes before midnight to two
    /// after, so only the date changes at midnight itself.
    @MainActor
    func testTicksAtMidnightOnlyWhenTheDateIsShown() {
        let shown = DateDisplay(isShown: true)
        func tick(_ date: Date, _ display: DateDisplay) -> Date {
            Clock.nextTick(after: date, popoverVisible: false, calendar: cal, personality: .spoken, dateDisplay: display)
        }
        let evening = at(2026, 11, 13, 23, 58, 20)
        XCTAssertEqual(tick(evening, shown), at(2026, 11, 14, 0, 0).addingTimeInterval(0.05))
        XCTAssertEqual(tick(evening, DateDisplay()), at(2026, 11, 14, 0, 3).addingTimeInterval(0.05))
        XCTAssertEqual(tick(at(2026, 11, 13, 12, 30), shown), at(2026, 11, 13, 12, 33).addingTimeInterval(0.05))
    }

    @MainActor
    func testClockPersistsTheDateDisplayAndReschedules() {
        let defaults = scratchDefaults()
        // Clock phrases in the current calendar, so build the date there too.
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 23, minute: 58))!
        let clock = Clock(dateProvider: { now }, defaults: defaults)
        XCTAssertEqual(clock.dateDisplay, DateDisplay())
        XCTAssertEqual(clock.fuzzy, "twelve o'clock")
        XCTAssertEqual(clock.timerFireDate, now.addingTimeInterval(5 * 60 + 0.05))

        clock.dateDisplay = DateDisplay(isShown: true, style: .spoken, position: .after)
        XCTAssertEqual(clock.fuzzy, "twelve o'clock\(DateDisplay.gap)Friday the thirteenth")
        XCTAssertEqual(clock.timerFireDate, now.addingTimeInterval(2 * 60 + 0.05), "wakes at midnight for the date")
        XCTAssertEqual(Clock(dateProvider: { now }, defaults: defaults).dateDisplay, clock.dateDisplay)

        defaults.set("nonsense", forKey: DateDisplay.styleKey)
        defaults.set("sideways", forKey: DateDisplay.positionKey)
        XCTAssertEqual(DateDisplay.load(from: defaults), DateDisplay(isShown: true))
    }
}
