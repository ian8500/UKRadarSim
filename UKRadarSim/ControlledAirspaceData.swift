import Foundation
import CoreGraphics

private struct ControlledAirspaceRegion {
    enum LayerKind {
        case boundary
        case shelf
    }

    let id: String
    let kind: LayerKind
    let airports: Set<String>
    let polygonFractions: [CGPoint]
    let floorLabel: String?
    let ceilingLabel: String?

    var asShelf: AirspaceShelf? {
        guard kind == .shelf, let floorLabel, let ceilingLabel else { return nil }
        return AirspaceShelf(
            polygonFractions: polygonFractions,
            floorLabel: floorLabel,
            ceilingLabel: ceilingLabel
        )
    }
}

enum UKControlledAirspaceData {
    // These regions are airport-linked slices of UK controlled airspace intended for simulation visuals.
    // They are maintained as reusable segments so airports that share a parent control area can render
    // consistent boundaries and shelves.
    private static let regions: [ControlledAirspaceRegion] = [
        // Gatwick CTR / CTA slices (stylised from Gatwick chart layout)
        ControlledAirspaceRegion(
            id: "EGKK-CTA-OUTER",
            kind: .boundary,
            airports: ["EGKK"],
            polygonFractions: [
                CGPoint(x: 0.18, y: 0.22), CGPoint(x: 0.38, y: 0.18), CGPoint(x: 0.58, y: 0.18),
                CGPoint(x: 0.74, y: 0.26), CGPoint(x: 0.84, y: 0.40), CGPoint(x: 0.87, y: 0.56),
                CGPoint(x: 0.84, y: 0.70), CGPoint(x: 0.75, y: 0.82), CGPoint(x: 0.58, y: 0.90),
                CGPoint(x: 0.40, y: 0.88), CGPoint(x: 0.28, y: 0.82), CGPoint(x: 0.20, y: 0.70),
                CGPoint(x: 0.17, y: 0.54), CGPoint(x: 0.17, y: 0.36)
            ],
            floorLabel: nil,
            ceilingLabel: nil
        ),
        ControlledAirspaceRegion(
            id: "EGKK-CTA-1500",
            kind: .shelf,
            airports: ["EGKK"],
            polygonFractions: [
                CGPoint(x: 0.24, y: 0.30), CGPoint(x: 0.40, y: 0.26), CGPoint(x: 0.56, y: 0.27),
                CGPoint(x: 0.68, y: 0.34), CGPoint(x: 0.75, y: 0.46), CGPoint(x: 0.76, y: 0.58),
                CGPoint(x: 0.70, y: 0.70), CGPoint(x: 0.58, y: 0.76), CGPoint(x: 0.44, y: 0.77),
                CGPoint(x: 0.32, y: 0.73), CGPoint(x: 0.25, y: 0.64), CGPoint(x: 0.22, y: 0.52),
                CGPoint(x: 0.22, y: 0.40)
            ],
            floorLabel: "1500",
            ceilingLabel: "2500"
        ),
        ControlledAirspaceRegion(
            id: "EGKK-CTA-2500",
            kind: .shelf,
            airports: ["EGKK"],
            polygonFractions: [
                CGPoint(x: 0.28, y: 0.36), CGPoint(x: 0.42, y: 0.33), CGPoint(x: 0.56, y: 0.35),
                CGPoint(x: 0.65, y: 0.42), CGPoint(x: 0.68, y: 0.52), CGPoint(x: 0.65, y: 0.62),
                CGPoint(x: 0.56, y: 0.68), CGPoint(x: 0.44, y: 0.70), CGPoint(x: 0.34, y: 0.66),
                CGPoint(x: 0.28, y: 0.58), CGPoint(x: 0.26, y: 0.48)
            ],
            floorLabel: "2500",
            ceilingLabel: "4500"
        ),
        ControlledAirspaceRegion(
            id: "EGKK-CTA-4500",
            kind: .shelf,
            airports: ["EGKK"],
            polygonFractions: [
                CGPoint(x: 0.36, y: 0.42), CGPoint(x: 0.48, y: 0.40), CGPoint(x: 0.56, y: 0.44),
                CGPoint(x: 0.58, y: 0.52), CGPoint(x: 0.55, y: 0.60), CGPoint(x: 0.48, y: 0.64),
                CGPoint(x: 0.40, y: 0.62), CGPoint(x: 0.35, y: 0.54)
            ],
            floorLabel: "4500",
            ceilingLabel: "FL195"
        ),

        // London TMA umbrella (Heathrow-only in this overlay set)
        ControlledAirspaceRegion(
            id: "LTMA-OUTER",
            kind: .boundary,
            airports: ["EGLL"],
            polygonFractions: [
                CGPoint(x: 0.03, y: 0.22), CGPoint(x: 0.16, y: 0.10), CGPoint(x: 0.40, y: 0.06),
                CGPoint(x: 0.64, y: 0.08), CGPoint(x: 0.84, y: 0.18), CGPoint(x: 0.95, y: 0.34),
                CGPoint(x: 0.97, y: 0.52), CGPoint(x: 0.91, y: 0.70), CGPoint(x: 0.78, y: 0.84),
                CGPoint(x: 0.56, y: 0.92), CGPoint(x: 0.30, y: 0.93), CGPoint(x: 0.12, y: 0.86),
                CGPoint(x: 0.04, y: 0.72), CGPoint(x: 0.01, y: 0.52), CGPoint(x: 0.01, y: 0.36)
            ],
            floorLabel: nil,
            ceilingLabel: nil
        ),
        ControlledAirspaceRegion(
            id: "LTMA-2500",
            kind: .shelf,
            airports: ["EGLL"],
            polygonFractions: [
                CGPoint(x: 0.12, y: 0.28), CGPoint(x: 0.30, y: 0.18), CGPoint(x: 0.52, y: 0.14),
                CGPoint(x: 0.72, y: 0.18), CGPoint(x: 0.82, y: 0.30), CGPoint(x: 0.84, y: 0.48),
                CGPoint(x: 0.78, y: 0.62), CGPoint(x: 0.60, y: 0.72), CGPoint(x: 0.38, y: 0.76),
                CGPoint(x: 0.18, y: 0.66), CGPoint(x: 0.10, y: 0.50)
            ],
            floorLabel: "2500",
            ceilingLabel: "FL195"
        ),
        ControlledAirspaceRegion(
            id: "LTMA-3500",
            kind: .shelf,
            airports: ["EGLL"],
            polygonFractions: [
                CGPoint(x: 0.22, y: 0.34), CGPoint(x: 0.38, y: 0.28), CGPoint(x: 0.56, y: 0.26),
                CGPoint(x: 0.68, y: 0.34), CGPoint(x: 0.72, y: 0.48), CGPoint(x: 0.66, y: 0.62),
                CGPoint(x: 0.52, y: 0.70), CGPoint(x: 0.34, y: 0.66), CGPoint(x: 0.22, y: 0.54),
                CGPoint(x: 0.18, y: 0.44)
            ],
            floorLabel: "3500",
            ceilingLabel: "FL195"
        ),
        ControlledAirspaceRegion(
            id: "LTMA-4500",
            kind: .shelf,
            airports: ["EGLL"],
            polygonFractions: [
                CGPoint(x: 0.34, y: 0.40), CGPoint(x: 0.48, y: 0.36), CGPoint(x: 0.60, y: 0.40),
                CGPoint(x: 0.64, y: 0.50), CGPoint(x: 0.58, y: 0.60), CGPoint(x: 0.44, y: 0.64),
                CGPoint(x: 0.34, y: 0.56), CGPoint(x: 0.30, y: 0.46)
            ],
            floorLabel: "4500",
            ceilingLabel: "FL195"
        ),

        // Scottish TMA umbrella
        ControlledAirspaceRegion(
            id: "SCOTTISH-OUTER",
            kind: .boundary,
            airports: ["EGPF", "EGPH"],
            polygonFractions: [
                CGPoint(x: 0.05, y: 0.14), CGPoint(x: 0.24, y: 0.09), CGPoint(x: 0.48, y: 0.08),
                CGPoint(x: 0.68, y: 0.12), CGPoint(x: 0.84, y: 0.22), CGPoint(x: 0.92, y: 0.36),
                CGPoint(x: 0.94, y: 0.56), CGPoint(x: 0.90, y: 0.74), CGPoint(x: 0.80, y: 0.86),
                CGPoint(x: 0.64, y: 0.92), CGPoint(x: 0.42, y: 0.92), CGPoint(x: 0.24, y: 0.86),
                CGPoint(x: 0.10, y: 0.74), CGPoint(x: 0.04, y: 0.56), CGPoint(x: 0.04, y: 0.34)
            ],
            floorLabel: nil,
            ceilingLabel: nil
        ),
        ControlledAirspaceRegion(
            id: "SCOTTISH-3500",
            kind: .shelf,
            airports: ["EGPF", "EGPH"],
            polygonFractions: [
                CGPoint(x: 0.14, y: 0.24), CGPoint(x: 0.30, y: 0.20), CGPoint(x: 0.52, y: 0.20),
                CGPoint(x: 0.70, y: 0.26), CGPoint(x: 0.80, y: 0.38), CGPoint(x: 0.82, y: 0.54),
                CGPoint(x: 0.78, y: 0.68), CGPoint(x: 0.66, y: 0.78), CGPoint(x: 0.48, y: 0.82),
                CGPoint(x: 0.28, y: 0.74), CGPoint(x: 0.16, y: 0.58)
            ],
            floorLabel: "3500",
            ceilingLabel: "FL195"
        ),
        ControlledAirspaceRegion(
            id: "SCOTTISH-4500",
            kind: .shelf,
            airports: ["EGPF", "EGPH"],
            polygonFractions: [
                CGPoint(x: 0.24, y: 0.36), CGPoint(x: 0.38, y: 0.34), CGPoint(x: 0.52, y: 0.36),
                CGPoint(x: 0.62, y: 0.44), CGPoint(x: 0.64, y: 0.56), CGPoint(x: 0.58, y: 0.68),
                CGPoint(x: 0.44, y: 0.72), CGPoint(x: 0.30, y: 0.66), CGPoint(x: 0.22, y: 0.54)
            ],
            floorLabel: "4500",
            ceilingLabel: "FL195"
        ),
        ControlledAirspaceRegion(
            id: "SCOTTISH-5500",
            kind: .shelf,
            airports: ["EGPF", "EGPH"],
            polygonFractions: [
                CGPoint(x: 0.34, y: 0.42), CGPoint(x: 0.46, y: 0.42), CGPoint(x: 0.56, y: 0.48),
                CGPoint(x: 0.58, y: 0.58), CGPoint(x: 0.52, y: 0.66), CGPoint(x: 0.40, y: 0.68),
                CGPoint(x: 0.30, y: 0.60), CGPoint(x: 0.28, y: 0.50)
            ],
            floorLabel: "5500",
            ceilingLabel: "FL195"
        )
    ]

    static func overlays(for airportICAO: String) -> (boundary: [CGPoint]?, shelves: [AirspaceShelf]) {
        let airportRegions = regions.filter { $0.airports.contains(airportICAO) }

        let boundary = airportRegions
            .first(where: { $0.kind == .boundary })?
            .polygonFractions

        let shelves = airportRegions.compactMap(\.asShelf)

        return (boundary, shelves)
    }
}
