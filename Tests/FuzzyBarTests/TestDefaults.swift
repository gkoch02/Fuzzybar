import XCTest

extension XCTestCase {
    /// A UserDefaults of the test's own, held in memory.
    func scratchDefaults() -> UserDefaults { InMemoryDefaults() }
}

/// A `UserDefaults` that never touches cfprefsd or a plist. A file-backed suite
/// can serve a read from before the latest write on the simulator, which makes
/// timing-free tests flaky (Nightdraft#151), and a bare suite name leaks a plist
/// into ~/Library/Preferences. The typed getters and setters funnel through
/// these overrides; `InMemoryDefaultsTests` pins that.
final class InMemoryDefaults: UserDefaults, @unchecked Sendable {
    private var store: [String: Any] = [:]
    private let lock = NSLock()

    init() { super.init(suiteName: nil)! }

    override func object(forKey defaultName: String) -> Any? {
        lock.withLock { store[defaultName] }
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        lock.withLock { store[defaultName] = value }
    }

    override func removeObject(forKey defaultName: String) {
        lock.withLock { _ = store.removeValue(forKey: defaultName) }
    }

    override func dictionaryRepresentation() -> [String: Any] {
        lock.withLock { store }
    }
}

/// A Gregorian calendar in `zone`, so a test's dates don't depend on the Mac's.
func gregorian(_ zone: String = "UTC") -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: zone)!
    return cal
}

func iso(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

/// `InMemoryDefaults` relies on Foundation routing the typed accessors through
/// `object(forKey:)` and `set(_:forKey:)`. If that ever stopped, they would
/// fall through to the real defaults; this pins it.
final class InMemoryDefaultsTests: XCTestCase {
    func testTypedAccessorsStayInMemory() {
        let key = "InMemoryDefaultsTests-\(UUID().uuidString)"
        let defaults = InMemoryDefaults()

        defaults.set(true, forKey: key)
        XCTAssertTrue(defaults.bool(forKey: key))
        defaults.set(39.7, forKey: key)
        XCTAssertEqual(defaults.double(forKey: key), 39.7)
        defaults.set(5, forKey: key)
        XCTAssertEqual(defaults.integer(forKey: key), 5)
        defaults.set("x", forKey: key)
        XCTAssertEqual(defaults.string(forKey: key), "x")
        defaults.set(["a", "b"], forKey: key)
        XCTAssertEqual(defaults.stringArray(forKey: key), ["a", "b"])
        defaults.set(Data([1, 2]), forKey: key)
        XCTAssertEqual(defaults.data(forKey: key), Data([1, 2]))
        XCTAssertEqual(defaults.dictionaryRepresentation().keys.sorted(), [key])

        XCTAssertNil(UserDefaults.standard.object(forKey: key), "leaked into the real defaults")
        defaults.removeObject(forKey: key)
        XCTAssertNil(defaults.object(forKey: key))
    }

    func testInstancesShareNothing() {
        let a = InMemoryDefaults(), b = InMemoryDefaults()
        a.set(1, forKey: "k")
        XCTAssertNil(b.object(forKey: "k"))
    }
}
