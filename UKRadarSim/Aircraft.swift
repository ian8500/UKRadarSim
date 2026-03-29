import Foundation
import CoreGraphics

enum VerticalTrend {
    case climb
    case level
    case descend

    var symbol: String {
        switch self {
        case .climb: return "↑"
        case .level: return "—"
        case .descend: return "↓"
        }
    }
}

struct Aircraft: Identifiable {
    let id = UUID()

    var callsign: String

    // True sim position
    var trueX: CGFloat
    var trueY: CGFloat

    // What radar currently shows
    var displayX: CGFloat
    var displayY: CGFloat
    var historyDots: [CGPoint] = []

    var heading: Double
    var groundSpeed: Int

    var currentLevel: Int
    var selectedLevel: Int
    var trend: VerticalTrend

    var destination: String
    var isInbound: Bool
    var approachCaptured: Bool = false
    var autoLandingActive: Bool = false
    var isLanded: Bool = false
}

enum StripBay: String, CaseIterable, Identifiable {
    case inbound = "Inbound"
    case outbound = "Outbound"

    var id: String { rawValue }
}

struct EFPSStrip: Identifiable {
    let id = UUID()
    let aircraftID: UUID
    var callsign: String
    var aircraftType: String
    let destination: String
    let isInbound: Bool

    var bay: StripBay
    var selectedLevel: Int
    var currentLevel: Int
    var selectedHeading: Int
    var currentHeading: Int
    var selectedSpeed: Int
    var approachType: String
    var approachCleared: Bool
    var approachCaptured: Bool = false
    var isLanded: Bool = false
    var instructionLog: [String]
    var lastIssuedLevel: Int?
    var lastIssuedHeading: Int?
    var lastIssuedSpeed: Int?
    var lastIssuedApproachType: String?

    var stripColorHex: String {
        isInbound ? "#E8CF9B" : "#D2E4FF"
    }

    var levelDisplay: String {
        if selectedLevel < 70 {
            return "\(selectedLevel * 100)FT"
        }
        return "FL\(selectedLevel)"
    }
}

struct RadarGeometry {
    let worldSize: CGSize
    let approachCourseHeading: Double
    let centerlineStartFraction: CGPoint
    let runwayThresholdFraction: CGPoint
    let controlledAirspacePolygonFractions: [CGPoint]
    let wrapInset: CGFloat

    static let `default` = RadarGeometry(
        worldSize: CGSize(width: 1000, height: 800),
        approachCourseHeading: 34.5,
        centerlineStartFraction: CGPoint(x: 0.18, y: 0.72),
        runwayThresholdFraction: CGPoint(x: 0.79, y: 0.29),
        controlledAirspacePolygonFractions: [
            CGPoint(x: 0.15, y: 0.78),
            CGPoint(x: 0.28, y: 0.18),
            CGPoint(x: 0.72, y: 0.12),
            CGPoint(x: 0.88, y: 0.48),
            CGPoint(x: 0.70, y: 0.86),
            CGPoint(x: 0.22, y: 0.88)
        ],
        wrapInset: 100
    )

    var centerlineStart: CGPoint {
        point(inWorldFromFraction: centerlineStartFraction)
    }

    var runwayThreshold: CGPoint {
        point(inWorldFromFraction: runwayThresholdFraction)
    }

    var wrapBounds: CGRect {
        CGRect(
            x: -wrapInset,
            y: -wrapInset,
            width: worldSize.width + (wrapInset * 2),
            height: worldSize.height + (wrapInset * 2)
        )
    }

    func point(inWorldFromFraction fraction: CGPoint) -> CGPoint {
        CGPoint(x: fraction.x * worldSize.width, y: fraction.y * worldSize.height)
    }

    func point(inViewFromWorld worldPoint: CGPoint, viewSize: CGSize) -> CGPoint {
        let xScale = viewSize.width / worldSize.width
        let yScale = viewSize.height / worldSize.height
        return CGPoint(x: worldPoint.x * xScale, y: worldPoint.y * yScale)
    }

    func point(inViewFromFraction fraction: CGPoint, viewSize: CGSize) -> CGPoint {
        point(inViewFromWorld: point(inWorldFromFraction: fraction), viewSize: viewSize)
    }
}
