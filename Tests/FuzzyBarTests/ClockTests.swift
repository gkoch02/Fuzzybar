import XCTest
@testable import FuzzyBar

final class ClockTests: XCTestCase {
    @MainActor func testClockSchedulesPhraseAndMinuteBoundaries() {
        let cal = gregorian()
        let cases = [("2024-01-01T08:00:30Z", "2024-01-01T08:03:00Z"),
                     ("2024-01-01T08:03:00Z", "2024-01-01T08:08:00Z"),
                     ("2024-01-01T23:57:59Z", "2024-01-01T23:58:00Z"),
                     ("2024-01-01T23:59:30Z", "2024-01-02T00:03:00Z")]
        for (start, expected) in cases {
            XCTAssertEqual(Clock.nextTick(after: iso(start), popoverVisible: false, calendar: cal).timeIntervalSince(iso(expected)), 0.05, accuracy: 0.001)
        }
        XCTAssertEqual(Clock.nextTick(after: iso("2024-01-01T23:59:30Z"), popoverVisible: true, calendar: cal).timeIntervalSince(iso("2024-01-02T00:00:00Z")), 0.05, accuracy: 0.001)
    }

    @MainActor func testClockScheduleAcrossDSTAndFractionalTimeZone() {
        for (zone, start) in [("America/Los_Angeles", "2024-03-10T09:59:30Z"),
                              ("America/Los_Angeles", "2024-11-03T08:59:30Z"),
                              ("Asia/Kathmandu", "2024-01-01T08:00:30Z")] {
            let cal = gregorian(zone)
            let initial = iso(start)
            let tick = Clock.nextTick(after: initial, popoverVisible: false, calendar: cal)
            XCTAssertGreaterThan(tick, initial)
            XCTAssertLessThanOrEqual(tick.timeIntervalSince(initial), 300.05)
            XCTAssertNotEqual(FuzzyTime.phrase(for: initial, calendar: cal), FuzzyTime.phrase(for: tick, calendar: cal))
        }
    }

    func testHeldDateReadsHoursAndMinutes() {
        let cal = gregorian()
        let day = iso("2024-01-01T15:30:20Z")
        XCTAssertEqual(Clock.heldDate("08:44", on: day, calendar: cal), iso("2024-01-01T08:44:00Z"))
        XCTAssertEqual(Clock.heldDate("8:44", on: day, calendar: cal), iso("2024-01-01T08:44:00Z"))
        XCTAssertEqual(Clock.heldDate("23:59", on: day, calendar: cal), iso("2024-01-01T23:59:00Z"))
        for bad in ["", "0844", "8", "24:00", "08:60", "08:44:10", "-1:30", "a:b", "08:"] {
            XCTAssertNil(Clock.heldDate(bad, on: day, calendar: cal), bad)
        }
    }

    /// A held clock keeps its time through the things that refresh it, and
    /// sets no timer: its next boundary is already in the past.
    @MainActor func testHeldClockSetsNoTimerAndStaysPut() {
        let held = iso("2024-01-01T08:44:00Z")
        let clock = Clock(dateProvider: { held }, defaults: scratchDefaults(), ticks: false)
        XCTAssertNil(clock.timerFireDate)
        clock.setPopoverVisible(true)
        clock.personalities.personality = .french
        clock.refresh()
        XCTAssertNil(clock.timerFireDate)
        XCTAssertEqual(clock.now, held)
    }

    @MainActor func testClockRefreshesOnOpeningAndExternalChanges() {
        var current = iso("2024-01-01T08:00:00Z")
        let clock = Clock(dateProvider: { current }, defaults: scratchDefaults())
        current = current.addingTimeInterval(90)
        clock.setPopoverVisible(true)
        XCTAssertEqual(clock.now, current)
        current = current.addingTimeInterval(3600)
        clock.refresh()
        XCTAssertEqual(clock.now, current)
        clock.setPopoverVisible(false)
        XCTAssertEqual(clock.now, current)
    }
}
