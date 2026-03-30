import Foundation

struct GeoPoint: Equatable {
    let latitude: Double
    let longitude: Double
}

struct PlanarPoint: Equatable {
    let x: Double
    let y: Double
}

struct LineSegment: Equatable {
    let start: GeoPoint
    let end: GeoPoint
}

struct ArcSegment: Equatable {
    let center: GeoPoint
    let radiusMeters: Double
    let startBearingDegrees: Double
    let endBearingDegrees: Double
    let clockwise: Bool

    func sample(stepDegrees: Double = 5) -> [GeoPoint] {
        let normalizedStep = max(stepDegrees, 0.1)
        let sweep = ArcSegment.sweepDegrees(
            start: startBearingDegrees,
            end: endBearingDegrees,
            clockwise: clockwise
        )

        let sampleCount = max(Int(ceil(sweep / normalizedStep)), 1)
        return (0...sampleCount).map { index in
            let progress = Double(index) / Double(sampleCount)
            let signedSweep = clockwise ? -sweep : sweep
            let bearing = normalizeAngle(startBearingDegrees + (signedSweep * progress))
            return GeoProjection.destination(
                from: center,
                bearingDegrees: bearing,
                distanceMeters: radiusMeters
            )
        }
    }

    private static func sweepDegrees(start: Double, end: Double, clockwise: Bool) -> Double {
        let normalizedStart = normalizeAngle(start)
        let normalizedEnd = normalizeAngle(end)

        if clockwise {
            let delta = normalizedStart - normalizedEnd
            return delta >= 0 ? delta : delta + 360
        }

        let delta = normalizedEnd - normalizedStart
        return delta >= 0 ? delta : delta + 360
    }
}

enum BoundarySegment: Equatable {
    case line(LineSegment)
    case arc(ArcSegment)
}

struct PlanarBounds: Equatable {
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
}

enum GeoProjection {
    private static let earthRadiusMeters = 6_371_000.0

    static func project(_ point: GeoPoint, relativeTo origin: GeoPoint) -> PlanarPoint {
        let latRad = point.latitude * .pi / 180
        let lonRad = point.longitude * .pi / 180
        let originLatRad = origin.latitude * .pi / 180
        let originLonRad = origin.longitude * .pi / 180

        let x = earthRadiusMeters * (lonRad - originLonRad) * cos(originLatRad)
        let y = earthRadiusMeters * (latRad - originLatRad)

        return PlanarPoint(x: x, y: y)
    }

    static func destination(from origin: GeoPoint, bearingDegrees: Double, distanceMeters: Double) -> GeoPoint {
        let angularDistance = distanceMeters / earthRadiusMeters
        let bearing = bearingDegrees * .pi / 180
        let lat1 = origin.latitude * .pi / 180
        let lon1 = origin.longitude * .pi / 180

        let lat2 = asin(
            sin(lat1) * cos(angularDistance) +
            cos(lat1) * sin(angularDistance) * cos(bearing)
        )

        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return GeoPoint(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
}

enum AirspaceGeometryParser {
    enum ParseError: Error, Equatable {
        case unsupportedSegment(String)
        case malformedSegment(String)
        case malformedCoordinate(String)
    }

    static func parseSegments(from rawDefinitions: [String]) throws -> [BoundarySegment] {
        try rawDefinitions.map(parseSegment)
    }

    private static func parseSegment(_ rawDefinition: String) throws -> BoundarySegment {
        let tokens = rawDefinition
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard let segmentType = tokens.first?.uppercased() else {
            throw ParseError.malformedSegment(rawDefinition)
        }

        switch segmentType {
        case "LINE":
            guard tokens.count == 3 else { throw ParseError.malformedSegment(rawDefinition) }
            let start = try parseCoordinate(tokens[1])
            let end = try parseCoordinate(tokens[2])
            return .line(LineSegment(start: start, end: end))

        case "ARC":
            guard tokens.count == 6 else { throw ParseError.malformedSegment(rawDefinition) }
            let center = try parseCoordinate(tokens[1])
            guard tokens[2].uppercased().hasSuffix("NM"),
                  let radiusNm = Double(tokens[2].dropLast(2)),
                  let startBearing = Double(tokens[3]),
                  let endBearing = Double(tokens[4])
            else {
                throw ParseError.malformedSegment(rawDefinition)
            }

            let clockwise: Bool
            switch tokens[5].uppercased() {
            case "CW": clockwise = true
            case "CCW": clockwise = false
            default: throw ParseError.malformedSegment(rawDefinition)
            }

            return .arc(
                ArcSegment(
                    center: center,
                    radiusMeters: radiusNm * 1_852,
                    startBearingDegrees: startBearing,
                    endBearingDegrees: endBearing,
                    clockwise: clockwise
                )
            )

        default:
            throw ParseError.unsupportedSegment(segmentType)
        }
    }

    static func parseCoordinate(_ token: String) throws -> GeoPoint {
        let text = token.uppercased().replacingOccurrences(of: " ", with: "")
        guard text.count == 15 else { throw ParseError.malformedCoordinate(token) }

        let latSlice = text.prefix(7)
        let lonSlice = text.suffix(8)

        let lat = try parseDMS(String(latSlice), positiveHemisphere: "N", negativeHemisphere: "S")
        let lon = try parseDMS(String(lonSlice), positiveHemisphere: "E", negativeHemisphere: "W")

        return GeoPoint(latitude: lat, longitude: lon)
    }

    private static func parseDMS(_ token: String, positiveHemisphere: Character, negativeHemisphere: Character) throws -> Double {
        guard let hemisphere = token.last,
              hemisphere == positiveHemisphere || hemisphere == negativeHemisphere
        else {
            throw ParseError.malformedCoordinate(token)
        }

        let digits = token.dropLast()
        let isLatitude = positiveHemisphere == "N"
        let degreeDigits = isLatitude ? 2 : 3
        let minStart = digits.index(digits.startIndex, offsetBy: degreeDigits)
        let secStart = digits.index(minStart, offsetBy: 2)

        guard digits.count == degreeDigits + 4,
              let degrees = Double(digits[..<minStart]),
              let minutes = Double(digits[minStart..<secStart]),
              let seconds = Double(digits[secStart...])
        else {
            throw ParseError.malformedCoordinate(token)
        }

        let value = degrees + (minutes / 60) + (seconds / 3_600)
        return hemisphere == negativeHemisphere ? -value : value
    }
}

enum BoundaryGeometryBuilder {
    static func toPlanarPolygon(
        segments: [BoundarySegment],
        origin: GeoPoint,
        arcStepDegrees: Double = 5,
        closePolygon: Bool = true
    ) -> [PlanarPoint] {
        var points: [GeoPoint] = []

        for segment in segments {
            let segmentPoints: [GeoPoint]
            switch segment {
            case let .line(line):
                segmentPoints = [line.start, line.end]
            case let .arc(arc):
                segmentPoints = arc.sample(stepDegrees: arcStepDegrees)
            }

            if points.isEmpty {
                points.append(contentsOf: segmentPoints)
            } else {
                points.append(contentsOf: segmentPoints.dropFirst())
            }
        }

        var planar = points.map { GeoProjection.project($0, relativeTo: origin) }

        if closePolygon,
           let first = planar.first,
           let last = planar.last,
           first != last {
            planar.append(first)
        }

        return planar
    }

    static func boundingBox(for points: [PlanarPoint]) -> PlanarBounds? {
        guard let first = points.first else { return nil }

        return points.dropFirst().reduce(
            PlanarBounds(minX: first.x, maxX: first.x, minY: first.y, maxY: first.y)
        ) { partial, point in
            PlanarBounds(
                minX: min(partial.minX, point.x),
                maxX: max(partial.maxX, point.x),
                minY: min(partial.minY, point.y),
                maxY: max(partial.maxY, point.y)
            )
        }
    }
}

private func normalizeAngle(_ angle: Double) -> Double {
    let normalized = angle.truncatingRemainder(dividingBy: 360)
    return normalized >= 0 ? normalized : normalized + 360
}
