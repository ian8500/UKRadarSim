import SwiftUI
import Foundation

struct LatLon {
    let lat: Double
    let lon: Double
}

enum BoundaryPrimitive {
    case line(to: LatLon)
    case clockwiseArc(center: LatLon, radiusNM: Double, to: LatLon)
    case anticlockwiseArc(center: LatLon, radiusNM: Double, to: LatLon)
}

struct AirspaceBoundary {
    let name: String
    let floorText: String
    let ceilingText: String
    let start: LatLon
    let primitives: [BoundaryPrimitive]
}

struct AirspaceGeoBounds {
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
}

enum LegalAirspaceKind {
    case cta
    case ctr
}

struct LegalAirspaceLayer {
    let kind: LegalAirspaceKind
    let boundary: AirspaceBoundary
}

enum GatwickAIPAirspace {
    static let egkkARP = LatLon(lat: 51.148056, lon: -0.190278) // 510853N 0001125W

    static let gatwickCTA = AirspaceBoundary(
        name: "GATWICK CTA",
        floorText: "1500 FT",
        ceilingText: "2500 FT",
        start: LatLon(lat: 51.016667, lon: 0.082778), // 510100N 0000458E
        primitives: [
            .line(to: LatLon(lat: 51.016667, lon: -0.429167)), // 510100N 0002545W
            .clockwiseArc(
                center: LatLon(lat: 51.148056, lon: -0.190278), // 510853N 0001125W
                radiusNM: 12.0,
                to: LatLon(lat: 51.190000, lon: -0.500833) // 511124N 0003003W
            ),
            .line(to: LatLon(lat: 51.271667, lon: 0.092500)), // 511618N 0000533E
            .clockwiseArc(
                center: LatLon(lat: 51.148056, lon: -0.190278), // 510853N 0001125W
                radiusNM: 13.0,
                to: LatLon(lat: 51.016667, lon: 0.082778) // back to start
            )
        ]
    )

    static let gatwickCTRVerifiedNorthSegment = AirspaceBoundary(
        name: "GATWICK CTR (verified north segment)",
        floorText: "SFC",
        ceilingText: "2500 FT",
        start: LatLon(lat: 51.216111, lon: -0.191389), // 511258N 0001129W
        primitives: [
            .clockwiseArc(
                center: LatLon(lat: 51.213611, lon: -0.138611), // 511249N 0000819W
                radiusNM: 2.0,
                to: LatLon(lat: 51.234722, lon: -0.179722) // 511405N 0001047W
            ),
            .line(to: LatLon(lat: 51.243611, lon: -0.115556)) // 511437N 0000656W
        ]
    )

    // UK AIP EGKK AD 2.17 table text retrieved via NATS PDF (AIRAC AMDT 14/2020 publication set).
    // Replace this block with current AIRAC legal text if updated.
    static let gatwickCTRCompletedFromAIP = AirspaceBoundary(
        name: "GATWICK CTR",
        floorText: "SFC",
        ceilingText: "2500 FT",
        start: LatLon(lat: 51.216111, lon: -0.191389), // 511258N 0001129W
        primitives: [
            .line(to: LatLon(lat: 51.200000, lon: 0.061389)), // 511200N 0000341E
            .clockwiseArc(
                center: LatLon(lat: 51.148056, lon: -0.190278), // 510853N 0001125W
                radiusNM: 10,
                to: LatLon(lat: 51.097222, lon: 0.061667) // 510550N 0000342E
            ),
            .line(to: LatLon(lat: 51.044444, lon: -0.323056)), // 510240N 0001923W
            .clockwiseArc(
                center: LatLon(lat: 51.148056, lon: -0.190278),
                radiusNM: 8,
                to: LatLon(lat: 51.188333, lon: -0.392222) // 511118N 0002332W
            ),
            .line(to: LatLon(lat: 51.216111, lon: -0.191389))
        ]
    )

    static let gatwickCTRTodoAppendBlock: [BoundaryPrimitive] = [
        // TODO(legal-data): Append future official CTR amendments here as additional primitives,
        // preserving ordering from the legal definition text.
    ]

    static let mapLayers: [LegalAirspaceLayer] = [
        LegalAirspaceLayer(kind: .cta, boundary: gatwickCTA),
        LegalAirspaceLayer(kind: .ctr, boundary: gatwickCTRCompletedFromAIP),
        LegalAirspaceLayer(kind: .ctr, boundary: gatwickCTRVerifiedNorthSegment)
    ]
}

enum AirspaceBoundaryRenderer {
    private static let earthRadiusMeters = 6_371_000.0
    private static let metersPerNauticalMile = 1_852.0

    static func dmsToDecimal(_ dms: String) -> Double? {
        let trimmed = dms.replacingOccurrences(of: " ", with: "").uppercased()
        guard let hemisphere = trimmed.last else { return nil }

        let body = String(trimmed.dropLast())
        let isLat = hemisphere == "N" || hemisphere == "S"
        let degreeDigits = isLat ? 2 : 3
        guard body.count == degreeDigits + 4 else { return nil }

        let degEnd = body.index(body.startIndex, offsetBy: degreeDigits)
        let minEnd = body.index(degEnd, offsetBy: 2)

        guard let deg = Double(body[..<degEnd]),
              let min = Double(body[degEnd..<minEnd]),
              let sec = Double(body[minEnd...])
        else {
            return nil
        }

        let unsigned = deg + (min / 60.0) + (sec / 3600.0)
        switch hemisphere {
        case "N", "E": return unsigned
        case "S", "W": return -unsigned
        default: return nil
        }
    }

    static func sampleBoundary(_ boundary: AirspaceBoundary) -> [LatLon] {
        var sampled: [LatLon] = [boundary.start]
        var current = boundary.start

        for primitive in boundary.primitives {
            switch primitive {
            case let .line(to):
                sampled.append(to)
                current = to

            case let .clockwiseArc(center, radiusNM, to):
                let points = sampleArc(from: current, center: center, radiusNM: radiusNM, to: to, clockwise: true)
                sampled.append(contentsOf: points.dropFirst())
                current = to

            case let .anticlockwiseArc(center, radiusNM, to):
                let points = sampleArc(from: current, center: center, radiusNM: radiusNM, to: to, clockwise: false)
                sampled.append(contentsOf: points.dropFirst())
                current = to
            }
        }

        return sampled
    }

    static func bounds(for boundaries: [AirspaceBoundary]) -> AirspaceGeoBounds {
        let all = boundaries.flatMap(sampleBoundary)
        let originLat = all.map(\.lat).reduce(0, +) / Double(max(all.count, 1))
        let projected = all.map { equirectangular($0, originLat: originLat) }

        let minX = projected.map(\.x).min() ?? -1
        let maxX = projected.map(\.x).max() ?? 1
        let minY = projected.map(\.y).min() ?? -1
        let maxY = projected.map(\.y).max() ?? 1

        return AirspaceGeoBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    static func project(_ point: LatLon, bounds: AirspaceGeoBounds, size: CGSize, originLat: Double) -> CGPoint {
        let local = equirectangular(point, originLat: originLat)
        let pad = 0.05

        let availableW = size.width * (1 - (2 * pad))
        let availableH = size.height * (1 - (2 * pad))
        let sourceW = max(bounds.maxX - bounds.minX, 1)
        let sourceH = max(bounds.maxY - bounds.minY, 1)
        let scale = min(Double(availableW) / sourceW, Double(availableH) / sourceH)

        let fittedW = sourceW * scale
        let fittedH = sourceH * scale
        let originX = (Double(size.width) - fittedW) / 2
        let originY = (Double(size.height) - fittedH) / 2

        let x = originX + ((local.x - bounds.minX) * scale)
        let y = originY + ((bounds.maxY - local.y) * scale)

        return CGPoint(x: x, y: y)
    }

    static func makePath(from points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private static func sampleArc(from start: LatLon, center: LatLon, radiusNM: Double, to end: LatLon, clockwise: Bool) -> [LatLon] {
        let startBearing = initialBearing(from: center, to: start)
        let endBearing = initialBearing(from: center, to: end)
        let sweep = angularSweep(start: startBearing, end: endBearing, clockwise: clockwise)

        let baseCount = Int(ceil(sweep / 2.0)) + 1
        let radiusWeight = Int(ceil(radiusNM * sweep / 10.0))
        let sampleCount = max(64, baseCount, radiusWeight)

        return (0...sampleCount).map { index in
            let fraction = Double(index) / Double(sampleCount)
            let signedSweep = clockwise ? -sweep : sweep
            let bearing = normalizeDegrees(startBearing + (signedSweep * fraction))
            return destination(from: center, bearingDegrees: bearing, distanceMeters: radiusNM * metersPerNauticalMile)
        }
    }

    private static func angularSweep(start: Double, end: Double, clockwise: Bool) -> Double {
        let s = normalizeDegrees(start)
        let e = normalizeDegrees(end)
        if clockwise {
            let d = s - e
            return d >= 0 ? d : d + 360
        }
        let d = e - s
        return d >= 0 ? d : d + 360
    }

    private static func initialBearing(from: LatLon, to: LatLon) -> Double {
        let lat1 = from.lat * .pi / 180
        let lat2 = to.lat * .pi / 180
        let dLon = (to.lon - from.lon) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = (cos(lat1) * sin(lat2)) - (sin(lat1) * cos(lat2) * cos(dLon))
        let bearing = atan2(y, x) * 180 / .pi
        return normalizeDegrees(bearing)
    }

    private static func destination(from origin: LatLon, bearingDegrees: Double, distanceMeters: Double) -> LatLon {
        let lat1 = origin.lat * .pi / 180
        let lon1 = origin.lon * .pi / 180
        let angularDistance = distanceMeters / earthRadiusMeters
        let bearing = bearingDegrees * .pi / 180

        let lat2 = asin(
            sin(lat1) * cos(angularDistance) +
            cos(lat1) * sin(angularDistance) * cos(bearing)
        )

        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return LatLon(lat: lat2 * 180 / .pi, lon: lon2 * 180 / .pi)
    }

    private static func equirectangular(_ point: LatLon, originLat: Double) -> (x: Double, y: Double) {
        let latRad = point.lat * .pi / 180
        let lonRad = point.lon * .pi / 180
        let refLatRad = originLat * .pi / 180

        return (
            x: earthRadiusMeters * lonRad * cos(refLatRad),
            y: earthRadiusMeters * latRad
        )
    }

    private static func normalizeDegrees(_ angle: Double) -> Double {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        return normalized >= 0 ? normalized : normalized + 360
    }
}
