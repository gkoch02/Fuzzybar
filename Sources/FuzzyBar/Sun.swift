import Foundation

/// Sunrise and sunset from NOAA's simplified solar-position equations, ported
/// from LittleFuzzyClock's sun.py. Good to a couple of minutes outside the polar
/// regions, which is far finer than the location FuzzyBar has to go on.
enum Sun {
    enum Day: Equatable {
        case risesAndSets(sunrise: Date, sunset: Date)
        /// Midnight sun: the sun never goes below the horizon that day.
        case alwaysUp
        /// Polar night: the sun never comes above it.
        case alwaysDown
    }

    /// Sunrise and sunset on the calendar day containing `date`.
    static func day(containing date: Date, latitude: Double, longitude: Double,
                    calendar: Calendar = .current) -> Day {
        // The equations work in minutes after UTC midnight of a calendar day.
        // Usually that's the local date, but across the date line (Chatham,
        // Kiribati, Samoa, Tonga) the local day's sun is the previous UTC
        // day's, so take whichever neighbour puts solar noon on the local day.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let localDate = utc.date(from: calendar.dateComponents([.year, .month, .day], from: date))!
        let candidates = [0, -1, 1].map { utc.date(byAdding: .day, value: $0, to: localDate)! }
        let base = candidates.first { calendar.isDate(solarNoon(base: $0, longitude: longitude, utc: utc),
                                                     inSameDayAs: date) } ?? localDate
        let (eqtime, decl) = solarTerms(base: base, utc: utc)

        let lat = latitude * .pi / 180
        // 90.833 degrees allows for refraction and the sun's apparent radius.
        let cosH = cos(90.833 * .pi / 180) / (cos(lat) * cos(decl)) - tan(lat) * tan(decl)
        if cosH < -1 { return .alwaysUp }
        if cosH > 1 { return .alwaysDown }
        let h = acos(cosH) * 180 / .pi

        let sunrise = 720 - 4 * (longitude + h) - eqtime
        let sunset = 720 - 4 * (longitude - h) - eqtime
        return .risesAndSets(sunrise: base.addingTimeInterval(sunrise * 60),
                             sunset: base.addingTimeInterval(sunset * 60))
    }

    /// Equation of time (minutes) and solar declination (radians) for the UTC day at `base`.
    private static func solarTerms(base: Date, utc: Calendar) -> (Double, Double) {
        let n = Double(utc.ordinality(of: .day, in: .year, for: base)!)
        let gamma = 2 * Double.pi / 365 * (n - 1)
        let eqtime = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let decl = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
        return (eqtime, decl)
    }

    private static func solarNoon(base: Date, longitude: Double, utc: Calendar) -> Date {
        base.addingTimeInterval((720 - 4 * longitude - solarTerms(base: base, utc: utc).0) * 60)
    }
}
