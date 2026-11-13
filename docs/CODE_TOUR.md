# A tour of the code

For anyone opening this repo for the first time. `README.md` says what the app does, how to build it and where each file is, `CLAUDE.md` holds the rules for working on it, and `docs/PERSONALITY_FORMAT.md` describes personality files. This page is meant to be read once, top to bottom, and leaves you knowing how 8:38 on the Mac's clock becomes "twenty to nine" in the menu bar, when the app wakes up to change it, and how to find your way around the rest.

You don't need to know Swift well to follow it. Where a piece of Swift is quoted, the sentence around it says what it does.

## The big picture

FuzzyBar is one small macOS app, built two ways from the same files in `Sources/FuzzyBar/`:

1. **Swift Package Manager** (`Package.swift`, `swift build`, `swift test`, `./build.sh`): the everyday way. `build.sh` builds the app, wraps it as `build/FuzzyBar.app`, signs it for this Mac, and with `--install` copies it to `/Applications`.
2. **Xcode** (`FuzzyBar.xcodeproj`, generated from `project.yml` by XcodeGen): used for Mac App Store builds, which need the App Sandbox and Apple's signing.

The app is a SwiftUI `MenuBarExtra`: a menu bar item with a popover under it, and no Dock icon. Beside the app: `Tests/` (Swift tests, and Python tests for the build script and project), `Tools/` (scripts for screenshots, the README banner, the time-zone table and checking an archive), `Assets/` (the icon, drawn by `make_icon.swift`, and screenshots) and `Examples/` (a sample personality file).

There's no network use, and nothing runs in the background besides one timer.

## Words this code uses

| Word | Means |
|---|---|
| **fuzzy time** / **phrase** | The time in words, as the menu bar shows it: "twenty to nine" |
| **slot** | One of twelve five-minute steps round the clock face: slot 0 is on the hour, slot 8 is "twenty to". Minutes are rounded to the nearest slot |
| **personality** | A way of saying the time (`Personality`): Spoken (the default), Classic, Shakespeare, German, Mission Control, Eldritch, Latin, Vague |
| **template** / **slot table** | A personality written as twelve slot phrases, the hour names and a pattern like `{phrase} {hour}`. `CustomPersonality` holds one; `Personality.template` gives the built-in ones that work this way |
| **custom personality** | One written by the user as a plain-text `.fuzzybar` file and imported in Preferences. Same shape as a template (`docs/PERSONALITY_FORMAT.md`) |
| **Vague** | The personality that names the part of the day ("evening") instead of the minutes (`Personality.vagueParts`) |
| **special time** | A minute with its own text, daily or yearly ("pi o'clock" at 3:14). It beats any personality for that minute (`SpecialTime`). New Year's is built in |
| **tick** | The moment the app next wakes up to update. `Clock.nextTick` works it out: the next minute the words would change, or every minute while the popover is open |
| **popover** | The panel under the menu bar item: exact time, date, sunrise and sunset, calendar, Preferences and Quit (`PopoverView`) |
| **reference city** | The city a time-zone name points at ("America/New_York" → New York), used for sunrise and sunset without asking for location (`ZoneLocations.swift`, generated) |
| **`@Published`** | A value that, when it changes, redraws whatever shows it |
| **`UserDefaults`** | Where the app keeps its settings between launches. Tests use a throwaway copy (`scratchDefaults()`) |

## Following one minute

Say the Mac's clock reaches 8:38 in the evening, with the default Spoken personality. Here's the path, with the file and the function at each step. To find a function, open the file in Xcode and press Cmd-Shift-O, or search the file for `func` and its name.

**1. The app starts.** `Sources/FuzzyBar/FuzzyBarApp.swift`. `FuzzyBarApp` makes one `Clock` and one `SunSettings`, and declares the menu bar item:

```swift
MenuBarExtra(clock.fuzzy) {
    PopoverView(now: clock.now, sun: sun, openSettings: { openSettings() })
    ...
}
```

That says: the menu bar shows the text `clock.fuzzy`, and clicking it opens `PopoverView`. Because `Clock` is watched by SwiftUI, the menu bar redraws whenever the clock says something changed.

**2. The clock sets an alarm.** `Sources/FuzzyBar/Clock.swift`. When `Clock` is made (`init`), it loads the chosen personality (through `PersonalityStore`) and the special times from `UserDefaults`, then calls `scheduleNextTick()`. That asks `nextTick(after:popoverVisible:…)` when to wake next. `nextTick` looks at each of the next five minute boundaries and picks the first one where the words would differ from now. At 8:36 the phrase is "twenty-five to nine", and it stays that until 8:38, when the rounding moves to slot 8, so the alarm is set for 8:38 (plus a twentieth of a second). It's a one-shot `Timer`. The clock also listens for the Mac waking from sleep and for the system clock or time zone changing, and refreshes on any of them.

**3. The alarm goes off.** The timer calls `refresh()`, which sets `now` to the current time and schedules the next tick. `now` is `@Published`, so SwiftUI rereads `clock.fuzzy`.

**4. Choosing who speaks.** `Clock.fuzzy` calls `Clock.text(for:…)`, which decides in this order: a special time for this minute wins (`SpecialTimes.text`, in `SpecialTimes.swift`); otherwise an imported custom personality, if one is chosen; otherwise the built-in personality, through `FuzzyTime.phrase(for:…)`.

**5. Into words.** `Sources/FuzzyBar/FuzzyTime.swift`. `phrase(hour:minute:personality:)` sends Vague to `vaguePhrase`, any personality with a slot table to `CustomPersonality.phrase`, and Spoken to `spokenPhrase`:

```swift
var slot = Int((Double(minute) / 5.0).rounded())  // 0...12
if slot == 12 { slot = 0; h += 1 }
```

That divides the minutes by five and rounds: 38 ÷ 5 = 7.6, which rounds to slot 8. (Slot 12 means the minutes rounded up to the next hour.) The `switch` below it turns slot 8 into "twenty to" plus the *next* hour's name from `Personality.englishHours`: "twenty to nine".

**6. On screen.** The menu bar item now reads "twenty to nine". Nothing else runs until the next tick at 8:43, when "quarter to nine" starts. That's the end of the trip.

If the popover is open, step 2 picks every minute instead, so the exact time in the popover stays right; `PopoverView` shows it, the date, `SunView` and `CalendarView`, all from the same `now`.

## The files that matter

| File | One line |
|---|---|
| `Sources/FuzzyBar/FuzzyBarApp.swift` | The menu bar item, the popover, and the Preferences window |
| `Sources/FuzzyBar/Clock.swift` | When to update, and which text wins (special time, custom, built-in) |
| `Sources/FuzzyBar/FuzzyTime.swift` | Turning an hour and minute into words |
| `Sources/FuzzyBar/Personality.swift` | The built-in personalities and their words |
| `Sources/FuzzyBar/CustomPersonality.swift` | Slot-table personalities: phrasing, reading and writing `.fuzzybar` files |
| `Sources/FuzzyBar/PersonalityStore.swift` | Which personality is chosen, and the imported ones, saved between launches |
| `Sources/FuzzyBar/SpecialTimes.swift` | Special times and New Year's |
| `Sources/FuzzyBar/Sun.swift` | Sunrise and sunset maths |
| `Sources/FuzzyBar/SettingsView.swift` | The Preferences window |
| `build.sh` | Build, sign, and optionally install |

## What you can skip

- **`ZoneLocations.swift`**: a long generated table of time zones and their cities. Regenerated by `Tools/make_zone_locations.py`, never edited by hand.
- **`Sun.swift`'s equations**: standard solar-position maths. `SunView.swift` is what decides how it's worded.
- **`CalendarView.swift`, `CalendarGrid.swift`**: the month calendar.
- **`LoginSettings.swift`**: the Start at Login switch.
- **`project.yml`, `FuzzyBar.xcodeproj`, `Tools/check_archive.sh`**: only for Mac App Store builds.
- **`Assets/`, `Tools/make_*.py`**: artwork.

The comments are long for an app this size. They're there because the code was written mostly by an AI, which rereads everything each time and benefits from having the reason for each choice next to it. A person can safely read around them.

## Finding things

In Xcode (open `Package.swift` and choose **My Mac** as the destination, or open `FuzzyBar.xcodeproj`):

- **Find in Project** (Cmd-Shift-F): search every file for a word or name.
- **Open Quickly** (Cmd-Shift-O): type a type or function name (`Clock`, `spokenPhrase`) and jump straight to it.
- **Jump to Definition**: Cmd-click a name to go to where it's defined; Ctrl-Cmd-← comes back.

From a terminal in the repo folder:

```bash
grep -rn "twenty to" Sources/                    # where does this wording come from?
grep -rn "func nextTick" Sources/                # where is this function defined?
grep -rln "SpecialTimes" Sources/ Tests/         # which files use this name?
```

Every phrase a built-in personality can say is in `Personality.swift`, so searching for a phrase you saw usually lands there.

## Reading a crash

Run the app from a terminal and anything it prints, including a crash, appears there:

```bash
swift build && .build/debug/FuzzyBar
```

Ctrl-C quits it. Swift reads the other way from Python: **the top of the list is where it stopped**. A made-up example:

```
Fatal error: Index out of range
#0  FuzzyBar`CustomPersonality.phrase(hour:minute:) at CustomPersonality.swift:27
#1  FuzzyBar`static Clock.text(for:calendar:personality:custom:specialTimes:) at Clock.swift:57
#2  FuzzyBar`Clock.fuzzy.getter at Clock.swift:50
```

Line `#0` is the code that failed; `#1` called it. Lines naming `SwiftUI`, `AppKit` or `libswift` are Apple's code; look for the first line naming a file in this repo. In Xcode, a crash stops the app on the failing line with the list in the **Debug navigator** (Cmd-7). Crashes of an installed copy are in the Console app under Crash Reports, filed by app name.

| Message | Usually means |
|---|---|
| `Fatal error: Unexpectedly found nil while unwrapping an Optional value` | Code assumed something was there and it wasn't (a `!` in the code) |
| `Fatal error: Index out of range` | Asked for item 13 of a list with 12, such as a slot or hour list that's too short |
| A red build error | The code doesn't compile. Xcode's **Issue navigator** (Cmd-5), or the terminal, names the file and line |

A personality file with a mistake isn't a crash: importing it shows what's wrong, in words, in Preferences.

## Making a change

1. **Find the place**, with the tables above or `grep`. To add a way of saying the time without touching code, write a `.fuzzybar` file (`docs/PERSONALITY_FORMAT.md`; `Examples/Pirate.fuzzybar` is a complete one) and import it in Preferences.
2. **Change one thing.**
3. **Try it**:

   ```bash
   swift build && .build/debug/FuzzyBar
   ```

   It appears in the menu bar beside any installed copy (quit that one first to avoid confusion). Preferences is in its popover. Ctrl-C in the terminal quits it.
4. **Undo** if it's wrong: `git diff` shows what you changed, `git checkout -- <file>` puts the original back.
5. **Run the tests**:

   ```bash
   swift test
   ```

   A failing test prints what it expected and what it got. The tests are grouped by the file they test: a change to `FuzzyTime.swift` is checked by `Tests/FuzzyBarTests/FuzzyTimeTests.swift`. If you added or renamed a Swift file, also run `xcodegen generate` and `python3 -m unittest discover -s Tests/BuildScriptTests` (`CLAUDE.md`).
6. **Install it** with `./build.sh --install` when you want it to replace the copy in `/Applications`.

## Where to go next

| To understand | Read |
|---|---|
| What the app does, building it, every file | `README.md` |
| How to work on the code | `CLAUDE.md` |
| Writing your own personality | `docs/PERSONALITY_FORMAT.md` |
| The tests | `Tests/FuzzyBarTests/`, named after the file each one tests |
