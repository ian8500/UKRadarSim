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

struct AirspaceLabelAnchor {
    let primary: LatLon
    let alternates: [LatLon]
}

struct AirspaceSector {
    let id: String
    let name: String
    let airspaceClass: String
    let floorText: String
    let ceilingText: String
    let start: LatLon
    let primitives: [BoundaryPrimitive]
    let labelAnchor: AirspaceLabelAnchor
    let isFilled: Bool
    let isDashed: Bool
    let displayPriority: Int
}

enum CASLabelMode: String, CaseIterable, Identifiable {
    case off
    case baseOnly
    case baseAndTop
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .baseOnly: return "Base"
        case .baseAndTop: return "Base + Top"
        case .full: return "Full"
        }
    }
}

struct AirspaceDisplayOptions {
    var showCAS: Bool
    var showOnlyGatwick: Bool
    var showLabels: Bool
    var labelMode: CASLabelMode
    var selectedSectorID: String?
}

struct AirspaceRenderModel {
    struct DrawableSector {
        let sector: AirspaceSector
        let path: Path
    }

    struct Label {
        let sectorID: String
        let anchor: CGPoint
        let lines: [String]
    }

    let drawables: [DrawableSector]
    let labels: [Label]
}

enum AirspaceRenderer {
    private static let earthRadiusMeters = 6_371_000.0
    private static let metersPerNauticalMile = 1_852.0

    static func makeRenderModel(
        sectors: [AirspaceSector],
        options: AirspaceDisplayOptions,
        canvasSize: CGSize,
        paddingRatio: Double = 0.05
    ) -> AirspaceRenderModel {
        let visible = visibleSectors(from: sectors, options: options)
            .sorted { $0.displayPriority < $1.displayPriority }

        guard !visible.isEmpty else {
            return AirspaceRenderModel(drawables: [], labels: [])
        }

        let sampledByID = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, sampleSector($0)) })
        let allPoints = sampledByID.values.flatMap { $0 }
        let originLat = allPoints.map(\.lat).reduce(0, +) / Double(max(allPoints.count, 1))
        let projected = allPoints.map { equirectangular($0, originLat: originLat) }

        let minX = projected.map(\.x).min() ?? -1
        let maxX = projected.map(\.x).max() ?? 1
        let minY = projected.map(\.y).min() ?? -1
        let maxY = projected.map(\.y).max() ?? 1
        let bounds = CGRect(x: minX, y: minY, width: max(maxX - minX, 1), height: max(maxY - minY, 1))

        let drawables = visible.compactMap { sector -> AirspaceRenderModel.DrawableSector? in
            guard let samples = sampledByID[sector.id] else { return nil }
            let points = samples.map { projectedPoint($0, originLat: originLat, sourceBounds: bounds, canvasSize: canvasSize, paddingRatio: paddingRatio) }
            return AirspaceRenderModel.DrawableSector(sector: sector, path: path(from: points))
        }

        let labels = makeLabels(
            visibleSectors: visible,
            options: options,
            originLat: originLat,
            sourceBounds: bounds,
            canvasSize: canvasSize,
            paddingRatio: paddingRatio
        )

        return AirspaceRenderModel(drawables: drawables, labels: labels)
    }

    static func visibleSectors(from sectors: [AirspaceSector], options: AirspaceDisplayOptions) -> [AirspaceSector] {
        guard options.showCAS else { return [] }

        return sectors.filter { sector in
            if options.showOnlyGatwick {
                return sector.id.contains("EGKK")
            }
            return true
        }
    }

    private static func makeLabels(
        visibleSectors: [AirspaceSector],
        options: AirspaceDisplayOptions,
        originLat: Double,
        sourceBounds: CGRect,
        canvasSize: CGSize,
        paddingRatio: Double
    ) -> [AirspaceRenderModel.Label] {
        guard options.showLabels, options.labelMode != .off else { return [] }

        var labels: [AirspaceRenderModel.Label] = []
        var occupied: [CGRect] = []

        for sector in visibleSectors.sorted(by: { $0.displayPriority < $1.displayPriority }) {
            let isSelected = options.selectedSectorID == sector.id
            let textLines = labelLines(for: sector, mode: options.labelMode)
            if textLines.isEmpty { continue }

            let anchorCandidates = [sector.labelAnchor.primary] + sector.labelAnchor.alternates
            let targetSize = CGSize(width: 140, height: CGFloat(max(1, textLines.count)) * 14)

            var placedLabel: AirspaceRenderModel.Label?
            for anchor in anchorCandidates {
                let point = projectedPoint(
                    anchor,
                    originLat: originLat,
                    sourceBounds: sourceBounds,
                    canvasSize: canvasSize,
                    paddingRatio: paddingRatio
                )
                let frame = CGRect(
                    x: point.x - (targetSize.width / 2),
                    y: point.y - (targetSize.height / 2),
                    width: targetSize.width,
                    height: targetSize.height
                )

                let collides = occupied.contains { $0.intersects(frame) }
                if !collides || isSelected {
                    occupied.append(frame)
                    placedLabel = AirspaceRenderModel.Label(sectorID: sector.id, anchor: point, lines: textLines)
                    break
                }
            }

            if let placedLabel {
                labels.append(placedLabel)
            }
        }

        return labels
    }

    private static func labelLines(for sector: AirspaceSector, mode: CASLabelMode) -> [String] {
        switch mode {
        case .off:
            return []
        case .baseOnly:
            return [sector.floorText]
        case .baseAndTop:
            return [sector.floorText, sector.ceilingText]
        case .full:
            return [sector.name, "Class \(sector.airspaceClass)", "Floor \(sector.floorText)", "Ceiling \(sector.ceilingText)"]
        }
    }

    static func sampleSector(_ sector: AirspaceSector) -> [LatLon] {
        var sampled: [LatLon] = [sector.start]
        var current = sector.start

        for primitive in sector.primitives {
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

        if let first = sampled.first, let last = sampled.last, (abs(first.lat - last.lat) > 0.000001 || abs(first.lon - last.lon) > 0.000001) {
            sampled.append(first)
        }

        return sampled
    }

    static func path(from points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private static func projectedPoint(
        _ point: LatLon,
        originLat: Double,
        sourceBounds: CGRect,
        canvasSize: CGSize,
        paddingRatio: Double
    ) -> CGPoint {
        let local = equirectangular(point, originLat: originLat)
        let availableW = max(1, canvasSize.width * CGFloat(1 - (2 * paddingRatio)))
        let availableH = max(1, canvasSize.height * CGFloat(1 - (2 * paddingRatio)))

        let scaleX = Double(availableW) / max(Double(sourceBounds.width), 1)
        let scaleY = Double(availableH) / max(Double(sourceBounds.height), 1)
        let scale = min(scaleX, scaleY)

        let fittedW = Double(sourceBounds.width) * scale
        let fittedH = Double(sourceBounds.height) * scale
        let originX = (Double(canvasSize.width) - fittedW) / 2
        let originY = (Double(canvasSize.height) - fittedH) / 2

        let x = originX + ((local.x - Double(sourceBounds.minX)) * scale)
        let y = originY + ((Double(sourceBounds.maxY) - local.y) * scale)
        return CGPoint(x: x, y: y)
    }

    private static func sampleArc(from start: LatLon, center: LatLon, radiusNM: Double, to end: LatLon, clockwise: Bool) -> [LatLon] {
        let startBearing = initialBearing(from: center, to: start)
        let endBearing = initialBearing(from: center, to: end)
        let sweep = angularSweep(start: startBearing, end: endBearing, clockwise: clockwise)

        let baseCount = Int(ceil(sweep / 2.0)) + 1
        let radiusWeight = Int(ceil(radiusNM * max(sweep, 1) / 9.0))
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
            let delta = s - e
            return delta >= 0 ? delta : delta + 360
        }
        let delta = e - s
        return delta >= 0 ? delta : delta + 360
    }

    private static func initialBearing(from: LatLon, to: LatLon) -> Double {
        let lat1 = from.lat * .pi / 180
        let lat2 = to.lat * .pi / 180
        let dLon = (to.lon - from.lon) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = (cos(lat1) * sin(lat2)) - (sin(lat1) * cos(lat2) * cos(dLon))
        return normalizeDegrees(atan2(y, x) * 180 / .pi)
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
