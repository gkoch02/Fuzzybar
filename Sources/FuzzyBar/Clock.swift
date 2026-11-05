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
    /// Owned here so a personality change can reschedule the tick.
    let personalities: PersonalityStore
    private let defaults: UserDefaults
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var popoverVisible = false
    private let dateProvider: () -> Date

    init(dateProvider: @escaping () -> Date = Date.init, defaults: UserDefaults = .standard) {
        self.dateProvider = dateProvider
        self.defaults = defaults
        now = dateProvider()
        personalities = PersonalityStore(defaults: defaults)
        specialTimes = SpecialTimes.load(from: defaults)
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
                  specialTimes: specialTimes)
    }

    /// What the menubar reads at `date`: a special time wins over everything,
    /// then a custom personality, then the built-in one.
    nonisolated static func text(for date: Date, calendar: Calendar = .current, personality: Personality,
                                 custom: CustomPersonality? = nil, specialTimes: [SpecialTime]) -> String {
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
    static func nextTick(after date: Date, popoverVisible: Bool, calendar: Calendar = .current,
                         personality: Personality = .default, custom: CustomPersonality? = nil,
                         specialTimes: [SpecialTime] = []) -> Date {
        let minuteStart = calendar.dateInterval(of: .minute, for: date)!.start
        func text(_ d: Date) -> String {
            Self.text(for: d, calendar: calendar, personality: personality, custom: custom, specialTimes: specialTimes)
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
        let fireDate = Self.nextTick(after: dateProvider(), popoverVisible: popoverVisible,
                                     personality: personalities.personality, custom: personalities.activeCustom,
                                     specialTimes: specialTimes)
        let t = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // Allow coalescing without visibly delaying the minute display.
        t.tolerance = popoverVisible ? 0.1 : 1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}

