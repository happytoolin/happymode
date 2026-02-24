import CoreLocation
import Foundation

enum SolarDayType {
    case normal(sunrise: Date, sunset: Date)
    case alwaysDark
    case alwaysLight
}

enum SolarCalculator {
    static func solarDay(for date: Date, coordinate: CLLocationCoordinate2D, timeZone: TimeZone = .current) -> SolarDayType {
        guard let solar = Solar(for: date, coordinate: coordinate) else {
            return .alwaysDark
        }

        if let sunrise = solar.sunrise, let sunset = solar.sunset {
            return .normal(sunrise: sunrise, sunset: sunset)
        }

        return polarDayClassification(for: date, coordinate: coordinate, timeZone: timeZone)
    }

    private static func polarDayClassification(for date: Date,
                                               coordinate: CLLocationCoordinate2D,
                                               timeZone: TimeZone) -> SolarDayType {
        let sunriseCosH = eventCosH(for: date,
                                    latitude: coordinate.latitude,
                                    longitude: coordinate.longitude,
                                    sunrise: true,
                                    timeZone: timeZone)
        let sunsetCosH = eventCosH(for: date,
                                   latitude: coordinate.latitude,
                                   longitude: coordinate.longitude,
                                   sunrise: false,
                                   timeZone: timeZone)

        if sunriseCosH > 1 || sunsetCosH > 1 {
            return .alwaysDark
        }

        if sunriseCosH < -1 || sunsetCosH < -1 {
            return .alwaysLight
        }

        return .alwaysDark
    }

    private static func eventCosH(for date: Date,
                                  latitude: Double,
                                  longitude: Double,
                                  sunrise: Bool,
                                  timeZone: TimeZone) -> Double {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeZone
        let dayOfYear = localCalendar.ordinality(of: .day, in: .year, for: date) ?? 1

        let lngHour = longitude / 15
        let localHour: Double = sunrise ? 6 : 18
        let t = Double(dayOfYear) + ((localHour - lngHour) / 24)

        let meanAnomaly = (0.9856 * t) - 3.289
        var trueLongitude = meanAnomaly
            + (1.916 * sin(meanAnomaly * .pi / 180))
            + (0.020 * sin(2 * meanAnomaly * .pi / 180))
            + 282.634
        trueLongitude = normalizeDegrees(trueLongitude)

        let sinDeclination = 0.39782 * sin(trueLongitude * .pi / 180)
        let cosDeclination = cos(asin(sinDeclination))

        return (cos(90.833 * .pi / 180) - (sinDeclination * sin(latitude * .pi / 180)))
            / (cosDeclination * cos(latitude * .pi / 180))
    }

    private static func normalizeDegrees(_ value: Double) -> Double {
        var normalized = value.truncatingRemainder(dividingBy: 360)
        if normalized < 0 {
            normalized += 360
        }
        return normalized
    }
}
