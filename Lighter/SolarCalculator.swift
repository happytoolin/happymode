import CoreLocation
import Foundation

enum SolarDayType {
    case normal(sunrise: Date, sunset: Date)
    case alwaysDark
    case alwaysLight
}

enum SolarCalculator {
    private static let zenith: Double = 90.833

    static func solarDay(for date: Date, coordinate: CLLocationCoordinate2D, timeZone: TimeZone = .current) -> SolarDayType {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeZone

        let dayOfYear = localCalendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let components = localCalendar.dateComponents([.year, .month, .day], from: date)

        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return .alwaysDark
        }

        let sunriseCalc = eventUTCHour(dayOfYear: dayOfYear,
                                       latitude: coordinate.latitude,
                                       longitude: coordinate.longitude,
                                       sunrise: true)
        let sunsetCalc = eventUTCHour(dayOfYear: dayOfYear,
                                      latitude: coordinate.latitude,
                                      longitude: coordinate.longitude,
                                      sunrise: false)

        if let sunriseHour = sunriseCalc.hour,
           let sunsetHour = sunsetCalc.hour,
           let sunrise = utcDate(year: year, month: month, day: day, hour: sunriseHour),
           let sunset = utcDate(year: year, month: month, day: day, hour: sunsetHour) {
            return .normal(sunrise: sunrise, sunset: sunset)
        }

        if sunriseCalc.cosH > 1 || sunsetCalc.cosH > 1 {
            return .alwaysDark
        }

        if sunriseCalc.cosH < -1 || sunsetCalc.cosH < -1 {
            return .alwaysLight
        }

        return .alwaysDark
    }

    private static func eventUTCHour(dayOfYear: Int,
                                     latitude: Double,
                                     longitude: Double,
                                     sunrise: Bool) -> (hour: Double?, cosH: Double) {
        let lngHour = longitude / 15
        let localHour: Double = sunrise ? 6 : 18
        let t = Double(dayOfYear) + ((localHour - lngHour) / 24)

        let meanAnomaly = (0.9856 * t) - 3.289
        var trueLongitude = meanAnomaly
            + (1.916 * sin(degToRad(meanAnomaly)))
            + (0.020 * sin(degToRad(2 * meanAnomaly)))
            + 282.634
        trueLongitude = normalizeDegrees(trueLongitude)

        var rightAscension = radToDeg(atan(0.91764 * tan(degToRad(trueLongitude))))
        rightAscension = normalizeDegrees(rightAscension)

        let lQuadrant = floor(trueLongitude / 90) * 90
        let raQuadrant = floor(rightAscension / 90) * 90
        rightAscension += (lQuadrant - raQuadrant)
        rightAscension /= 15

        let sinDeclination = 0.39782 * sin(degToRad(trueLongitude))
        let cosDeclination = cos(asin(sinDeclination))

        let cosH = (cos(degToRad(zenith)) - (sinDeclination * sin(degToRad(latitude))))
            / (cosDeclination * cos(degToRad(latitude)))

        if cosH > 1 || cosH < -1 {
            return (nil, cosH)
        }

        let hourAngle = sunrise ? (360 - radToDeg(acos(cosH))) : radToDeg(acos(cosH))
        let localHourAngle = hourAngle / 15

        let localMeanTime = localHourAngle + rightAscension - (0.06571 * t) - 6.622
        let utcHour = normalizeHours(localMeanTime - lngHour)

        return (utcHour, cosH)
    }

    private static func utcDate(year: Int, month: Int, day: Int, hour: Double) -> Date? {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        var components = DateComponents()
        components.calendar = utcCalendar
        components.timeZone = utcCalendar.timeZone
        components.year = year
        components.month = month
        components.day = day

        guard let startOfDay = utcCalendar.date(from: components) else {
            return nil
        }

        return startOfDay.addingTimeInterval(hour * 3600)
    }

    private static func degToRad(_ value: Double) -> Double {
        value * .pi / 180
    }

    private static func radToDeg(_ value: Double) -> Double {
        value * 180 / .pi
    }

    private static func normalizeDegrees(_ value: Double) -> Double {
        var normalized = value.truncatingRemainder(dividingBy: 360)
        if normalized < 0 {
            normalized += 360
        }
        return normalized
    }

    private static func normalizeHours(_ value: Double) -> Double {
        var normalized = value.truncatingRemainder(dividingBy: 24)
        if normalized < 0 {
            normalized += 24
        }
        return normalized
    }
}
