import AppKit
import Combine

/// Updates at phrase boundaries, or each minute while the popover is visible.
@MainActor
final class Clock: ObservableObject {
    @Published private(set) var now: Date
    @Published var specialTimes: [SpecialTime] {
        didSet {
            SpecialTimes.save(specialTimes, to: defaults)
            scheduleNextTick()
        }
    }
    @Published var dateDisplay: DateDisplay {
        didSet {
            dateDisplay.save(to: defaults)
            scheduleNextTick()
        }
    }
    /// Owned here so a personality change can reschedule the tick.
    let personalities: PersonalityStore
    private let defaults: UserDefaults
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var popoverVisible = false
    private let dateProvider: () -> Date
    /// False for a clock held at one time, which has nothing to wake for.
    private let ticks: Bool

    init(dateProvider: @escaping () -> Date = Date.init, defaults: UserDefaults = .standard, ticks: Bool = true) {
        self.dateProvider = dateProvider
        self.defaults = defaults
        self.ticks = ticks
        now = dateProvider()
        personalities = PersonalityStore(defaults: defaults)
        specialTimes = SpecialTimes.load(from: defaults)
        dateDisplay = DateDisplay.load(from: defaults)
        personalities.onChange = { [weak self] in
            // Phrase boundaries differ between personalities (spoken flips at
            // :58, the ported ones at :00), so the pending tick may be wrong.
            self?.objectWillChange.send()
            self?.scheduleNextTick()
        }
        scheduleNextTick()
        observe(.NSSystemClockDidChange, in: .default)
        observe(.NSSystemTimeZoneDidChange, in: .default)
        observe(NSWorkspace.didWakeNotification, in: NSWorkspace.shared.notificationCenter)
    }

    deinit {
        timer?.invalidate()
        for (center, token) in observers { center.removeObserver(token) }
    }

    var fuzzy: String {
        Self.text(for: now, personality: personalities.personality, custom: personalities.activeCustom,
                  specialTimes: specialTimes, dateDisplay: dateDisplay)
    }

    /// What the menubar reads at `date`: a special time wins over everything,
    /// then a custom personality, then the built-in one. The date, when
    /// shown, sits beside whichever of them it is.
    nonisolated static func text(for date: Date, calendar: Calendar = .current, personality: Personality,
                                 custom: CustomPersonality? = nil, specialTimes: [SpecialTime],
                                 dateDisplay: DateDisplay = DateDisplay()) -> String {
        dateDisplay.text(time(for: date, calendar: calendar, personality: personality, custom: custom,
                              specialTimes: specialTimes), on: date, calendar: calendar)
    }

    private nonisolated static func time(for date: Date, calendar: Calendar, personality: Personality,
                                         custom: CustomPersonality?, specialTimes: [SpecialTime]) -> String {
        if let special = SpecialTimes.text(for: date, calendar: calendar, userTimes: specialTimes) { return special }
        guard let custom else { return FuzzyTime.phrase(for: date, calendar: calendar, personality: personality) }
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return custom.phrase(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    /// When the pending tick fires; exposed for tests.
    var timerFireDate: Date? { timer?.fireDate }

    func setPopoverVisible(_ visible: Bool) {
        popoverVisible = visible
        refresh()
    }

    func refresh() {
        now = dateProvider()
        scheduleNextTick()
    }

    private func observe(_ name: Notification.Name, in center: NotificationCenter) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        observers.append((center, token))
    }

    /// Search actual minute boundaries so DST and non-whole-hour time zones work.
    /// Special times last one minute, so they show up here as a change at
    /// their start and another at their end, like any phrase boundary.
    /// It looks five minutes ahead, the length of a slot; a phrase that holds
    /// longer, like Vague's, is simply looked at again on the next wake.
    /// A date in the menubar changes the text at midnight, so that is found
    /// the same way.
    static func nextTick(after date: Date, popoverVisible: Bool, calendar: Calendar = .current,
                         personality: Personality = .default, custom: CustomPersonality? = nil,
                         specialTimes: [SpecialTime] = [], dateDisplay: DateDisplay = DateDisplay()) -> Date {
        let minuteStart = calendar.dateInterval(of: .minute, for: date)!.start
        func text(_ d: Date) -> String {
            Self.text(for: d, calendar: calendar, personality: personality, custom: custom,
                      specialTimes: specialTimes, dateDisplay: dateDisplay)
        }
        let phrase = text(date)
        for offset in 1...5 {
            let candidate = minuteStart.addingTimeInterval(Double(offset) * 60)
            if popoverVisible || text(candidate) != phrase {
                return candidate.addingTimeInterval(0.05)
            }
        }
        return minuteStart.addingTimeInterval(300.05)
    }

    private func scheduleNextTick() {
        timer?.invalidate()
        timer = nil
        // A held clock's next boundary is already past: a timer for it would
        // fire, find the same time, and be set again without end.
        guard ticks else { return }
        let fireDate = Self.nextTick(after: dateProvider(), popoverVisible: popoverVisible,
                                     personality: personalities.personality, custom: personalities.activeCustom,
                                     specialTimes: specialTimes, dateDisplay: dateDisplay)
        let t = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // Allow coalescing without visibly delaying the minute display.
        t.tolerance = popoverVisible ? 0.1 : 1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}


// MARK: - A held clock, for screenshots

extension Clock {
    /// The launch argument that holds a debug build's clock: `-fuzzyNow 08:44`.
    static let holdArgument = "fuzzyNow"

    /// The app's clock. A debug build started with `-fuzzyNow 08:44` reads
    /// that time today and stays there, so a screenshot of one personality
    /// matches the others taken at any other moment
    /// (`Tools/capture_build.sh`). Only the launch arguments are read: a
    /// stored default of the same name does nothing.
    static func launched() -> Clock {
        #if DEBUG
        let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        if let text = arguments[holdArgument] as? String, let date = heldDate(text, on: Date()) {
            return Clock(dateProvider: { date }, ticks: false)
        }
        #endif
        return Clock()
    }

    /// "08:44" or "8:44" as that time on `day`; `nil` for anything else.
    nonisolated static func heldDate(_ text: String, on day: Date, calendar: Calendar = .current) -> Date? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ (1...2).contains($0.count) && $0.allSatisfy(\.isNumber) }),
              let hour = Int(parts[0]), let minute = Int(parts[1]), hour < 24, minute < 60 else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }
}
