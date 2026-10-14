# FuzzyBar

[![Tests](https://github.com/gkoch02/Fuzzybar/actions/workflows/test.yml/badge.svg)](https://github.com/gkoch02/Fuzzybar/actions/workflows/test.yml)

A tiny native macOS menubar clock that tells the time in words.

<p align="center">
  <img src="Assets/screenshots/popover.png" width="465" alt="The menubar reading “ten to four”, with FuzzyBar's popover open below it: 3:50 PM, the full date, sunrise around twenty to seven and sunset around ten to seven, a September calendar with week numbers, and Preferences and Quit.">
</p>

Click it for the exact time, today's date, a month calendar, and a couple of
menu items. That's the whole app.

**[Get it on the Mac App Store](https://apps.apple.com/us/app/id6813746171)** for
$0.99, a signed universal build the store installs and keeps updated, or build it
yourself for free from this repository (below). It's the same app either way.

FuzzyBar exists because the fuzzy clock I'd used for years stopped getting
updates and still ran under Rosetta. This one is a small amount of Swift,
builds natively for Apple Silicon, and has no dependencies.

## Features

- Time in words in the menubar, updated when the phrase changes
- Eight personalities, from plain spoken English to Mission Control, Eldritch, and Vague
- Popover with the exact time, full date, and a month calendar with week numbers
- Special times: your own text for a minute of your choosing, daily or yearly
- Start at login, via the system Login Items list
- Today's sunrise and sunset in the popover, without asking for your location
- Your own personalities, written as plain text files and imported
- No Dock icon, no network, no analytics, nothing running that doesn't need to

## Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later (command line tools are enough) to build from source; the
  [Mac App Store](https://apps.apple.com/us/app/id6813746171) build needs nothing else

## Build and install

```sh
git clone https://github.com/gkoch02/Fuzzybar.git
cd Fuzzybar
./build.sh --install
```

That builds a release binary, wraps it in `build/FuzzyBar.app`, copies it to
`/Applications`, and launches it. Run `./build.sh` on its own to build without
installing.

Local builds are ad-hoc signed, which is all you need to run it on your own
Mac. If you have an Apple developer certificate and want a real signature,
point `SIGN_IDENTITY` at it:

```sh
SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./build.sh --install
```

No certificates, keys, or notarization credentials are stored in this repo.

There is also an Xcode project, `FuzzyBar.xcodeproj`, generated from `project.yml`
with [XcodeGen](https://github.com/yonaskolb/XcodeGen). It exists for Mac App
Store archives (App Sandbox, automatic signing, the asset-catalog icon). After
**Product → Archive**, run `Tools/check_archive.sh` before uploading: it fails a
Debug archive or a build number the project has moved past.
Day-to-day builds and tests still go through SwiftPM and `build.sh`.

## How the fuzzy time works

Minutes are rounded to the nearest five, then mapped to the usual spoken
phrases: *o'clock*, *five past*, *ten past*, *quarter past*, *twenty past*,
*twenty-five past*, *half past*, and the same again counting down *to* the next
hour. So 8:38 is "twenty to nine" and 8:37 is "twenty-five to nine".

## Sunrise and sunset

The popover shows today's sunrise and sunset, fuzzily ("sunset around ten to
seven"), because the location behind them is a guess. FuzzyBar has no location
access and doesn't ask for any: it uses the reference city of the Mac's time
zone, so a Mac set to America/New_York gets New York's sun. Preferences can
switch that to typed-in coordinates, or hide the two lines. At midnight sun or
polar night the popover says the sun doesn't set or doesn't rise today.

The arithmetic is NOAA's simplified solar-position equations, ported from
LittleFuzzyClock and good to a minute or two. The zone-to-city table, and
the old names that still point at a city (US/Eastern, Asia/Calcutta), are
generated from an IANA tzdata release's `zone.tab` and `backward` by
`Tools/make_zone_locations.py` and compiled in; the script's docstring has the
download steps.

## Special times

Preferences has a list of special times: a minute, either every day or one
day a year, and what the menubar should say then ("pi o'clock" at 3:14). It
replaces the phrase for that one minute in every personality, then the usual
phrase comes back. Text is capped at 30 characters so it stays clear of the
notch on MacBooks that have one.

One is built in: the first minute of the year reads *Happy New Year!* A
special time of your own for 12:00 am on January 1 takes its place.

## Personalities

Preferences has a Personality picker. The default is the spoken English above;
six of the others are ported from
[LittleFuzzyClock](https://github.com/gkoch02/LittleFuzzyClock), and Vague is
FuzzyBar's own. All shown at 8:40 pm:

| Personality | 8:40 pm reads | Notes |
| --- | --- | --- |
| Spoken (default) | `twenty to nine` | The way you'd say it out loud. |
| Classic | `twenty to nine pm` | Plain English with am and pm; "just after" and "almost" at the edges. |
| Shakespeare | `twenty 'fore nine of the clock` | Archaic English; drops am/pm as anachronistic. |
| German | `zwanzig vor neun` | Standard High German; "halb zehn" anchors on the *next* hour. |
| Mission Control | `T-20 MINUTES, 2100 HOURS` | Mission-control patter; 24-hour numeric time. |
| Eldritch | `twenty 'fore, the ninth hour` | Cosmic dread; ordinal hours; climaxes with "the stars are right". |
| Latin | `viginti ante hora IX p.m.` | Roman-numeral hours; real Latin prepositions. |
| Vague | `evening` | Just the part of the day, from *early* round to *way too late*. |

<p align="center">
  <img src="Assets/screenshots/strips/personalities.png" width="432" alt="Eight menubar strips stacked, one per personality. The first seven at 8:44 am: quarter to nine; quarter to nine am; a quarter ’fore nine of the clock; viertel vor neun; T-15 MINUTES, 0900 HOURS; quarter ’fore, the ninth hour; quadrans ante hora IX a.m. The last, Vague, at 3:50 pm: afternoon.">
</p>

Vague ignores the minutes and names the part of the day: *way too late*
until 5, then *early*, *morning* from 7, *around noon* from 11:30, *after
lunch* from 1, *afternoon* from 3, *evening* from 6, and *late* from 9.

The six ported personalities share LittleFuzzyClock's twelve-slot table, so
minutes 58 and 59 stay on its last slot (Classic's "almost nine pm") rather than
turning to the hour the way the spoken default does. The phrase tables live in
`Sources/FuzzyBar/Personality.swift`.

The logic lives in `Sources/FuzzyBar/FuzzyTime.swift` and is covered by tests:

```sh
swift test
python3 -m unittest discover -s Tests/BuildScriptTests
```

The build-script tests need macOS and skip elsewhere.

## Your own personalities

Preferences can import a personality you wrote yourself: a plain text
`.fuzzybar` file with a line for each five minutes and each hour, like
`:40  twenty 'fore` and `9  nine`. **Save as Template…** writes the current
one out and opens it in TextEdit as a starting point, and
[`docs/PERSONALITY_FORMAT.md`](docs/PERSONALITY_FORMAT.md) has the details.
[`Examples/Pirate.fuzzybar`](Examples/Pirate.fuzzybar) is a complete example.

The App Sandbox allows reading and writing only files you pick in an open or
save panel, or drop on the Preferences window. That's the one exception
FuzzyBar asks for.

## Project layout

| Path | What it is |
| --- | --- |
| `Sources/FuzzyBar/FuzzyBarApp.swift` | App entry point and the menubar popover |
| `Sources/FuzzyBar/FuzzyTime.swift` | Time-to-words conversion |
| `Sources/FuzzyBar/Personality.swift` | The eight phrasing personalities |
| `Sources/FuzzyBar/Clock.swift` | Phrase-boundary ticker (minute updates while the popover is open) and special times |
| `Sources/FuzzyBar/CalendarView.swift`, `CalendarGrid.swift` | The popover's month calendar and the six weeks it shows |
| `Sources/FuzzyBar/Sun.swift`, `SunSettings.swift`, `SunView.swift` | Sunrise and sunset: the equations, the location setting, the popover lines |
| `Sources/FuzzyBar/ZoneLocations.swift` | Time zone reference cities, generated by `Tools/make_zone_locations.py` |
| `Sources/FuzzyBar/SettingsView.swift`, `LoginSettings.swift` | Preferences window, and the Start at Login switch |
| `Sources/FuzzyBar/CustomPersonality.swift`, `PersonalitySection.swift` | Personality files: the format, templates, and the Preferences picker with Import and Save |
| `Sources/FuzzyBar/PersonalityStore.swift` | The chosen personality and imported ones, saved between launches |
| `Sources/FuzzyBar/SpecialTimes.swift`, `SpecialTimesSection.swift` | Special times and the New Year's message, and their Preferences list |
| `Tests/FuzzyBarTests/`, `Tests/BuildScriptTests/` | Swift tests, one file per unit, and the build-script and Xcode-project checks |
| `Examples/`, `docs/PERSONALITY_FORMAT.md` | An example personality file and the format it follows |
| `Assets/` | Icon renderer, the generated `.icns`, and the store screenshots (raws plus captioned set) |
| `Tools/make_screenshots.py` | Renders the captioned screenshots from the raws |
| `Tools/check_archive.sh` | Checks an Xcode archive is a Release build of the bumped version |
| `Resources/` | Asset catalog (app icon) and the privacy manifest for the Xcode build |
| `build.sh` | Builds, signs, and optionally installs the app bundle |
| `project.yml`, `FuzzyBar.xcodeproj` | XcodeGen spec and the generated project for App Store archives |
| `FuzzyBar.entitlements` | App Sandbox, plus reading and writing files the user picks |

## Regenerating the icon

The app icon is drawn in code. Edit `Assets/make_icon.swift` and run:

```sh
./Assets/make_icns.sh
```

That rewrites both `Assets/AppIcon.icns` (used by `build.sh`) and the PNG set in
`Resources/Assets.xcassets` (used by the Xcode project).

## License

MIT. See [LICENSE](LICENSE).
