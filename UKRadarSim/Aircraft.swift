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

    var aircraftType: String
    var destination: String
    var isInbound: Bool
    var approachCaptured: Bool = false
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
    let controlledAirspaceShelves: [AirspaceShelf]
    let surroundingAirways: [AirwaySegment]
    let terrainSectors: [TerrainSector]
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
        controlledAirspaceShelves: [],
        surroundingAirways: [],
        terrainSectors: [],
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


struct AirspaceShelf {
    let polygonFractions: [CGPoint]
    let floorLabel: String
    let ceilingLabel: String
}

struct AirwaySegment {
    let identifier: String
    let waypoints: [CGPoint]
}

struct TerrainSector {
    let polygonFractions: [CGPoint]
    let minimumAltitudeLabel: String
}

enum AirportMapCatalog {
    /// Baseline geometry for each airport view.
    /// Controlled-airspace overlays are injected from shared UK segments so airports
    /// in the same region render a consistent structure.
    static func geometry(for airportICAO: String) -> RadarGeometry {
        let baseGeometry: RadarGeometry
        switch airportICAO {
        case "EGLL": baseGeometry = heathrow
        case "EGPF": baseGeometry = glasgow
        case "EGPH": baseGeometry = edinburgh
        default: baseGeometry = gatwick
        }

        let overlays = UKControlledAirspaceData.overlays(for: airportICAO)

        return RadarGeometry(
            worldSize: baseGeometry.worldSize,
            approachCourseHeading: baseGeometry.approachCourseHeading,
            centerlineStartFraction: baseGeometry.centerlineStartFraction,
            runwayThresholdFraction: baseGeometry.runwayThresholdFraction,
            controlledAirspacePolygonFractions: overlays.boundary ?? baseGeometry.controlledAirspacePolygonFractions,
            controlledAirspaceShelves: overlays.shelves.isEmpty ? baseGeometry.controlledAirspaceShelves : overlays.shelves,
            surroundingAirways: baseGeometry.surroundingAirways,
            terrainSectors: baseGeometry.terrainSectors,
            wrapInset: baseGeometry.wrapInset
        )
    }

    private static let gatwick = RadarGeometry(
        worldSize: CGSize(width: 1000, height: 800),
        approachCourseHeading: 258.0,
        centerlineStartFraction: CGPoint(x: 0.10, y: 0.54),
        runwayThresholdFraction: CGPoint(x: 0.76, y: 0.50),
        controlledAirspacePolygonFractions: [
            CGPoint(x: 0.03, y: 0.20), CGPoint(x: 0.15, y: 0.10), CGPoint(x: 0.42, y: 0.07),
            CGPoint(x: 0.68, y: 0.12), CGPoint(x: 0.86, y: 0.22), CGPoint(x: 0.95, y: 0.38),
            CGPoint(x: 0.94, y: 0.58), CGPoint(x: 0.86, y: 0.74), CGPoint(x: 0.72, y: 0.87),
            CGPoint(x: 0.48, y: 0.93), CGPoint(x: 0.24, y: 0.90), CGPoint(x: 0.08, y: 0.78),
            CGPoint(x: 0.02, y: 0.56), CGPoint(x: 0.02, y: 0.36)
        ],
        controlledAirspaceShelves: [
            AirspaceShelf(
                polygonFractions: [
                    CGPoint(x: 0.10, y: 0.28), CGPoint(x: 0.28, y: 0.20), CGPoint(x: 0.52, y: 0.18),
                    CGPoint(x: 0.72, y: 0.26), CGPoint(x: 0.81, y: 0.40), CGPoint(x: 0.79, y: 0.58),
                    CGPoint(x: 0.66, y: 0.70), CGPoint(x: 0.44, y: 0.74), CGPoint(x: 0.22, y: 0.68),
                    CGPoint(x: 0.10, y: 0.56)
                ],
                floorLabel: "2500",
                ceilingLabel: "FL195"
            ),
            AirspaceShelf(
                polygonFractions: [
                    CGPoint(x: 0.24, y: 0.34), CGPoint(x: 0.42, y: 0.30), CGPoint(x: 0.60, y: 0.32),
                    CGPoint(x: 0.70, y: 0.42), CGPoint(x: 0.68, y: 0.56), CGPoint(x: 0.58, y: 0.66),
                    CGPoint(x: 0.40, y: 0.68), CGPoint(x: 0.26, y: 0.58), CGPoint(x: 0.20, y: 0.46)
                ],
                floorLabel: "3500",
                ceilingLabel: "FL195"
            ),
            AirspaceShelf(
                polygonFractions: [
                    CGPoint(x: 0.36, y: 0.40), CGPoint(x: 0.50, y: 0.38), CGPoint(x: 0.60, y: 0.44),
                    CGPoint(x: 0.60, y: 0.56), CGPoint(x: 0.50, y: 0.62), CGPoint(x: 0.38, y: 0.58),
                    CGPoint(x: 0.32, y: 0.48)
                ],
                floorLabel: "4500",
                ceilingLabel: "FL195"
            )
        ],
        surroundingAirways: [
            AirwaySegment(
                identifier: "L9",
                waypoints: [
                    CGPoint(x: 0.00, y: 0.36), CGPoint(x: 0.20, y: 0.40),
                    CGPoint(x: 0.44, y: 0.46), CGPoint(x: 0.68, y: 0.52), CGPoint(x: 1.00, y: 0.58)
                ]
            ),
            AirwaySegment(
                identifier: "M23",
                waypoints: [
                    CGPoint(x: 0.14, y: 0.86), CGPoint(x: 0.30, y: 0.70),
                    CGPoint(x: 0.46, y: 0.58), CGPoint(x: 0.63, y: 0.44), CGPoint(x: 0.78, y: 0.28)
                ]
            ),
            AirwaySegment(
                identifier: "UL607",
                waypoints: [
                    CGPoint(x: 0.24, y: 0.06), CGPoint(x: 0.40, y: 0.22),
                    CGPoint(x: 0.56, y: 0.40), CGPoint(x: 0.72, y: 0.64), CGPoint(x: 0.88, y: 0.92)
                ]
            )
        ],
        terrainSectors: [
            TerrainSector(
                polygonFractions: [
                    CGPoint(x: 0.00, y: 0.00), CGPoint(x: 0.45, y: 0.00), CGPoint(x: 0.42, y: 0.44), CGPoint(x: 0.00, y: 0.40)
                ],
                minimumAltitudeLabel: "MSA 2400"
            ),
            TerrainSector(
                polygonFractions: [
                    CGPoint(x: 0.45, y: 0.00), CGPoint(x: 1.00, y: 0.00), CGPoint(x: 1.00, y: 0.44), CGPoint(x: 0.42, y: 0.44)
                ],
                minimumAltitudeLabel: "MSA 3300"
            ),
            TerrainSector(
                polygonFractions: [
                    CGPoint(x: 0.00, y: 0.40), CGPoint(x: 0.42, y: 0.44), CGPoint(x: 0.40, y: 1.00), CGPoint(x: 0.00, y: 1.00)
                ],
                minimumAltitudeLabel: "MSA 2600"
            )
        ],
        wrapInset: 100
    )

    private static let heathrow = RadarGeometry(
        worldSize: CGSize(width: 1000, height: 800),
        approachCourseHeading: 269.0,
        centerlineStartFraction: CGPoint(x: 0.08, y: 0.50),
        runwayThresholdFraction: CGPoint(x: 0.73, y: 0.50),
        controlledAirspacePolygonFractions: [
            CGPoint(x: 0.02, y: 0.24), CGPoint(x: 0.16, y: 0.12), CGPoint(x: 0.40, y: 0.06),
            CGPoint(x: 0.64, y: 0.08), CGPoint(x: 0.84, y: 0.18), CGPoint(x: 0.95, y: 0.34),
            CGPoint(x: 0.97, y: 0.52), CGPoint(x: 0.91, y: 0.70), CGPoint(x: 0.78, y: 0.84),
            CGPoint(x: 0.56, y: 0.92), CGPoint(x: 0.30, y: 0.93), CGPoint(x: 0.12, y: 0.86),
            CGPoint(x: 0.04, y: 0.72), CGPoint(x: 0.01, y: 0.52), CGPoint(x: 0.01, y: 0.36)
        ],
        controlledAirspaceShelves: [
            AirspaceShelf(
                polygonFractions: [
                    CGPoint(x: 0.12, y: 0.28), CGPoint(x: 0.30, y: 0.18), CGPoint(x: 0.52, y: 0.14),
                    CGPoint(x: 0.72, y: 0.18), CGPoint(x: 0.82, y: 0.30), CGPoint(x: 0.84, y: 0.48),
                    CGPoint(x: 0.78, y: 0.62), CGPoint(x: 0.60, y: 0.72), CGPoint(x: 0.38, y: 0.76),
                    CGPoint(x: 0.18, y: 0.66), CGPoint(x: 0.10, y: 0.50)
                ],
                floorLabel: "2500",
                ceilingLabel: "FL195"
            ),
            AirspaceShelf(
                polygonFractions: [
                    CGPoint(x: 0.22, y: 0.34), CGPoint(x: 0.38, y: 0.28), CGPoint(x: 0.56, y: 0.26),
                    CGPoint(x: 0.68, y: 0.34), CGPoint(x: 0.72, y: 0.48), CGPoint(x: 0.66, y: 0.62),
                    CGPoint(x: 0.52, y: 0.70), CGPoint(x: 0.34, y: 0.66), CGPoint(x: 0.22, y: 0.54),
                    CGPoint(x: 0.18, y: 0.44)
                ],
                floorLabel: "3500",
                ceilingLabel: "FL195"
            ),
            AirspaceShelf(
                polygonFractions: [
                    CGPoint(x: 0.34, y: 0.40), CGPoint(x: 0.48, y: 0.36), CGPoint(x: 0.60, y: 0.40),
                    CGPoint(x: 0.64, y: 0.50), CGPoint(x: 0.58, y: 0.60), CGPoint(x: 0.44, y: 0.64),
                    CGPoint(x: 0.34, y: 0.56), CGPoint(x: 0.30, y: 0.46)
                ],
                floorLabel: "4500",
                ceilingLabel: "FL195"
            )
        ],
        surroundingAirways: [
            AirwaySegment(
                identifier: "L607",
                waypoints: [
                    CGPoint(x: 0.00, y: 0.42), CGPoint(x: 0.22, y: 0.44),
                    CGPoint(x: 0.44, y: 0.46), CGPoint(x: 0.67, y: 0.48), CGPoint(x: 1.00, y: 0.50)
                ]
            ),
            AirwaySegment(
                identifier: "UL9",
                waypoints: [
                    CGPoint(x: 0.08, y: 0.84), CGPoint(x: 0.24, y: 0.68),
                    CGPoint(x: 0.40, y: 0.54), CGPoint(x: 0.58, y: 0.40), CGPoint(x: 0.82, y: 0.22)
                ]
            ),
            AirwaySegment(
                identifier: "N546",
                waypoints: [
                    CGPoint(x: 0.20, y: 0.08), CGPoint(x: 0.34, y: 0.24),
                    CGPoint(x: 0.50, y: 0.42), CGPoint(x: 0.66, y: 0.60), CGPoint(x: 0.82, y: 0.82)
                ]
            )
        ],
        terrainSectors: [
            TerrainSector(
                polygonFractions: [
                    CGPoint(x: 0.00, y: 0.00), CGPoint(x: 0.50, y: 0.00), CGPoint(x: 0.48, y: 0.42), CGPoint(x: 0.00, y: 0.40)
                ],
                minimumAltitudeLabel: "MSA 2300"
            ),
            TerrainSector(
                polygonFractions: [
                    CGPoint(x: 0.50, y: 0.00), CGPoint(x: 1.00, y: 0.00), CGPoint(x: 1.00, y: 0.44), CGPoint(x: 0.48, y: 0.42)
                ],
                minimumAltitudeLabel: "MSA 2600"
            ),
            TerrainSector(
                polygonFractions: [
                    CGPoint(x: 0.00, y: 0.40), CGPoint(x: 0.48, y: 0.42), CGPoint(x: 0.44, y: 1.00), CGPoint(x: 0.00, y: 1.00)
                ],
                minimumAltitudeLabel: "MSA 2500"
            )
        ],
        wrapInset: 100
    )

    private static let glasgow = RadarGeometry(
        worldSize: CGSize(width: 1000, height: 800),
        approachCourseHeading: 226.0,
        centerlineStartFraction: CGPoint(x: 0.20, y: 0.26),
        runwayThresholdFraction: CGPoint(x: 0.70, y: 0.66),
        controlledAirspacePolygonFractions: [
            CGPoint(x: 0.04, y: 0.14), CGPoint(x: 0.22, y: 0.08), CGPoint(x: 0.48, y: 0.06),
            CGPoint(x: 0.70, y: 0.10), CGPoint(x: 0.86, y: 0.20), CGPoint(x: 0.94, y: 0.36),
            CGPoint(x: 0.95, y: 0.56), CGPoint(x: 0.90, y: 0.74), CGPoint(x: 0.80, y: 0.84),
            CGPoint(x: 0.62, y: 0.92), CGPoint(x: 0.38, y: 0.92), CGPoint(x: 0.20, y: 0.84),
            CGPoint(x: 0.08, y: 0.70), CGPoint(x: 0.03, y: 0.50), CGPoint(x: 0.03, y: 0.30)
        ],
        controlledAirspaceShelves: [
            AirspaceShelf(
                polygonFractions: [
                    CGPoint(x: 0.14, y: 0.24), CGPoint(x: 0.32, y: 0.18), CGPoint(x: 0.54, y: 0.18),
                    CGPoint(x: 0.70, y: 0.24), CGPoint(x: 0.80, y: 0.36), CGPoint(x: 0.82, y: 0.52),
                    CGPoint(x: 0.76, y: 0.66), CGPoint(x: 0.62, y: 0.76), CGPoint(x: 0.44, y: 0.80),
                    CGPoint(x: 0.24, y: 0.72), CGPoint(x: 0.14, y: 0.58)
                ],
                floorLabel: "3000",
                ceilingLabel: "FL195"
            ),
            AirspaceShelf(
                polygonFractions: [
                    CGPoint(x: 0.24, y: 0.34), CGPoint(x: 0.38, y: 0.32), CGPoint(x: 0.52, y: 0.34),
                    CGPoint(x: 0.62, y: 0.42), CGPoint(x: 0.64, y: 0.54), CGPoint(x: 0.58, y: 0.66),
                    CGPoint(x: 0.44, y: 0.70), CGPoint(x: 0.30, y: 0.64), CGPoint(x: 0.22, y: 0.52)
                ],
                floorLabel: "4500",
                ceilingLabel: "FL195"
            ),
            AirspaceShelf(
                polygonFractions: [
                    CGPoint(x: 0.34, y: 0.40), CGPoint(x: 0.46, y: 0.40), CGPoint(x: 0.56, y: 0.46),
                    CGPoint(x: 0.58, y: 0.56), CGPoint(x: 0.52, y: 0.64), CGPoint(x: 0.40, y: 0.66),
                    CGPoint(x: 0.30, y: 0.58), CGPoint(x: 0.28, y: 0.48)
                ],
                floorLabel: "5500",
                ceilingLabel: "FL195"
            )
        ],
        surroundingAirways: [
            AirwaySegment(
                identifier: "P600",
                waypoints: [
                    CGPoint(x: 0.04, y: 0.30), CGPoint(x: 0.26, y: 0.36),
                    CGPoint(x: 0.48, y: 0.42), CGPoint(x: 0.72, y: 0.52), CGPoint(x: 1.00, y: 0.64)
                ]
            ),
            AirwaySegment(
                identifier: "N560",
                waypoints: [
                    CGPoint(x: 0.16, y: 0.88), CGPoint(x: 0.30, y: 0.70),
                    CGPoint(x: 0.46, y: 0.54), CGPoint(x: 0.62, y: 0.36), CGPoint(x: 0.76, y: 0.16)
                ]
            )
        ],
        terrainSectors: [
            TerrainSector(
                polygonFractions: [
                    CGPoint(x: 0.00, y: 0.00), CGPoint(x: 0.48, y: 0.00), CGPoint(x: 0.42, y: 0.50), CGPoint(x: 0.00, y: 0.42)
                ],
                minimumAltitudeLabel: "MSA 3900"
            ),
            TerrainSector(
                polygonFractions: [
                    CGPoint(x: 0.48, y: 0.00), CGPoint(x: 1.00, y: 0.00), CGPoint(x: 1.00, y: 0.52), CGPoint(x: 0.42, y: 0.50)
                ],
                minimumAltitudeLabel: "MSA 4200"
            ),
            TerrainSector(
                polygonFractions: [
                    CGPoint(x: 0.00, y: 0.42), CGPoint(x: 0.42, y: 0.50), CGPoint(x: 0.40, y: 1.00), CGPoint(x: 0.00, y: 1.00)
                ],
                minimumAltitudeLabel: "MSA 3600"
            )
        ],
        wrapInset: 100
    )

    private static let edinburgh = RadarGeometry(
        worldSize: CGSize(width: 1000, height: 800),
        approachCourseHeading: 236.0,
        centerlineStartFraction: CGPoint(x: 0.20, y: 0.28),
        runwayThresholdFraction: CGPoint(x: 0.71, y: 0.64),
        controlledAirspacePolygonFractions: [
            CGPoint(x: 0.05, y: 0.14), CGPoint(x: 0.24, y: 0.09), CGPoint(x: 0.48, y: 0.08),
            CGPoint(x: 0.68, y: 0.12), CGPoint(x: 0.84, y: 0.22), CGPoint(x: 0.92, y: 0.36),
            CGPoint(x: 0.94, y: 0.56), CGPoint(x: 0.90, y: 0.74), CGPoint(x: 0.80, y: 0.86),
            CGPoint(x: 0.64, y: 0.92), CGPoint(x: 0.42, y: 0.92), CGPoint(x: 0.24, y: 0.86),
            CGPoint(x: 0.10, y: 0.74), CGPoint(x: 0.04, y: 0.56), CGPoint(x: 0.04, y: 0.34)
        ],
        controlledAirspaceShelves: [
            AirspaceShelf(
                polygonFractions: [
                    CGPoint(x: 0.14, y: 0.24), CGPoint(x: 0.30, y: 0.20), CGPoint(x: 0.52, y: 0.20),
                    CGPoint(x: 0.70, y: 0.26), CGPoint(x: 0.80, y: 0.38), CGPoint(x: 0.82, y: 0.54),
                    CGPoint(x: 0.78, y: 0.68), CGPoint(x: 0.66, y: 0.78), CGPoint(x: 0.48, y: 0.82),
                    CGPoint(x: 0.28, y: 0.74), CGPoint(x: 0.16, y: 0.58)
                ],
                floorLabel: "3500",
                ceilingLabel: "FL195"
            ),
            AirspaceShelf(
                polygonFractions: [
                    CGPoint(x: 0.24, y: 0.36), CGPoint(x: 0.38, y: 0.34), CGPoint(x: 0.52, y: 0.36),
                    CGPoint(x: 0.62, y: 0.44), CGPoint(x: 0.64, y: 0.56), CGPoint(x: 0.58, y: 0.68),
                    CGPoint(x: 0.44, y: 0.72), CGPoint(x: 0.30, y: 0.66), CGPoint(x: 0.22, y: 0.54)
                ],
                floorLabel: "4500",
                ceilingLabel: "FL195"
            ),
            AirspaceShelf(
                polygonFractions: [
                    CGPoint(x: 0.34, y: 0.42), CGPoint(x: 0.46, y: 0.42), CGPoint(x: 0.56, y: 0.48),
                    CGPoint(x: 0.58, y: 0.58), CGPoint(x: 0.52, y: 0.66), CGPoint(x: 0.40, y: 0.68),
                    CGPoint(x: 0.30, y: 0.60), CGPoint(x: 0.28, y: 0.50)
                ],
                floorLabel: "5500",
                ceilingLabel: "FL195"
            )
        ],
        surroundingAirways: [
            AirwaySegment(
                identifier: "P18",
                waypoints: [
                    CGPoint(x: 0.06, y: 0.30), CGPoint(x: 0.24, y: 0.38),
                    CGPoint(x: 0.46, y: 0.44), CGPoint(x: 0.72, y: 0.56), CGPoint(x: 0.96, y: 0.70)
                ]
            ),
            AirwaySegment(
                identifier: "N63",
                waypoints: [
                    CGPoint(x: 0.18, y: 0.88), CGPoint(x: 0.34, y: 0.70),
                    CGPoint(x: 0.50, y: 0.54), CGPoint(x: 0.64, y: 0.38), CGPoint(x: 0.78, y: 0.20)
                ]
            )
        ],
        terrainSectors: [
            TerrainSector(
                polygonFractions: [
                    CGPoint(x: 0.00, y: 0.00), CGPoint(x: 0.50, y: 0.00), CGPoint(x: 0.45, y: 0.48), CGPoint(x: 0.00, y: 0.42)
                ],
                minimumAltitudeLabel: "MSA 3200"
            ),
            TerrainSector(
                polygonFractions: [
                    CGPoint(x: 0.50, y: 0.00), CGPoint(x: 1.00, y: 0.00), CGPoint(x: 1.00, y: 0.54), CGPoint(x: 0.45, y: 0.48)
                ],
                minimumAltitudeLabel: "MSA 3800"
            ),
            TerrainSector(
                polygonFractions: [
                    CGPoint(x: 0.00, y: 0.42), CGPoint(x: 0.45, y: 0.48), CGPoint(x: 0.44, y: 1.00), CGPoint(x: 0.00, y: 1.00)
                ],
                minimumAltitudeLabel: "MSA 2900"
            )
        ],
        wrapInset: 100
    )
}
