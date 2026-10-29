import XCTest

extension XCTestCase {
    /// A UserDefaults suite of the test's own, removed when the test ends.
    func scratchDefaults() -> UserDefaults {
        // A path, not a name: a named suite leaves an empty plist in
        // ~/Library/Preferences even after removePersistentDomain.
        let suite = FileManager.default.temporaryDirectory
            .appendingPathComponent("FuzzyBarTests.\(UUID().uuidString)").path
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return UserDefaults(suiteName: suite)!
    }
}

/// A Gregorian calendar in `zone`, so a test's dates don't depend on the Mac's.
func gregorian(_ zone: String = "UTC") -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: zone)!
    return cal
}

func iso(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
