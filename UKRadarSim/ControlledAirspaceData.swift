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

        // Scottish TMA umbrella (Glasgow-focused shared segment)
        ControlledAirspaceRegion(
            id: "SCOTTISH-OUTER",
            kind: .boundary,
            airports: ["EGPF"],
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
            airports: ["EGPF"],
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
            airports: ["EGPF"],
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
            airports: ["EGPF"],
            polygonFractions: [
                CGPoint(x: 0.34, y: 0.42), CGPoint(x: 0.46, y: 0.42), CGPoint(x: 0.56, y: 0.48),
                CGPoint(x: 0.58, y: 0.58), CGPoint(x: 0.52, y: 0.66), CGPoint(x: 0.40, y: 0.68),
                CGPoint(x: 0.30, y: 0.60), CGPoint(x: 0.28, y: 0.50)
            ],
            floorLabel: "5500",
            ceilingLabel: "FL195"
        ),

        // Edinburgh CTA segmentation (derived from EGPH CTA 1-4 coordinate table and chart shape)
        ControlledAirspaceRegion(
            id: "EGPH-CTA-OUTER",
            kind: .boundary,
            airports: ["EGPH"],
            polygonFractions: [
                CGPoint(x: 0.082, y: 0.000), CGPoint(x: 0.488, y: 0.000), CGPoint(x: 0.888, y: 0.000),
                CGPoint(x: 1.000, y: 0.268), CGPoint(x: 0.903, y: 1.000), CGPoint(x: 0.166, y: 1.000),
                CGPoint(x: 0.107, y: 0.906), CGPoint(x: 0.002, y: 0.739), CGPoint(x: 0.001, y: 0.497),
                CGPoint(x: 0.000, y: 0.375)
            ],
            floorLabel: nil,
            ceilingLabel: nil
        ),
        ControlledAirspaceRegion(
            id: "EGPH-CTA-1",
            kind: .shelf,
            airports: ["EGPH"],
            polygonFractions: [
                CGPoint(x: 0.223, y: 0.302), CGPoint(x: 0.237, y: 0.238), CGPoint(x: 0.259, y: 0.178),
                CGPoint(x: 0.288, y: 0.124), CGPoint(x: 0.323, y: 0.079), CGPoint(x: 0.364, y: 0.043),
                CGPoint(x: 0.408, y: 0.017), CGPoint(x: 0.454, y: 0.003), CGPoint(x: 0.501, y: 0.001),
                CGPoint(x: 0.549, y: 0.010), CGPoint(x: 0.594, y: 0.031), CGPoint(x: 0.636, y: 0.062),
                CGPoint(x: 0.673, y: 0.104), CGPoint(x: 0.705, y: 0.154), CGPoint(x: 0.730, y: 0.212),
                CGPoint(x: 0.748, y: 0.274), CGPoint(x: 0.758, y: 0.341), CGPoint(x: 0.760, y: 0.408),
                CGPoint(x: 0.754, y: 0.475), CGPoint(x: 0.740, y: 0.540), CGPoint(x: 0.718, y: 0.600),
                CGPoint(x: 0.689, y: 0.654), CGPoint(x: 0.654, y: 0.700), CGPoint(x: 0.615, y: 0.736),
                CGPoint(x: 0.571, y: 0.763), CGPoint(x: 0.525, y: 0.778), CGPoint(x: 0.478, y: 0.781),
                CGPoint(x: 0.432, y: 0.773), CGPoint(x: 0.387, y: 0.754), CGPoint(x: 0.345, y: 0.723),
                CGPoint(x: 0.307, y: 0.683), CGPoint(x: 0.274, y: 0.633), CGPoint(x: 0.248, y: 0.577),
                CGPoint(x: 0.229, y: 0.515), CGPoint(x: 0.218, y: 0.449), CGPoint(x: 0.002, y: 0.739),
                CGPoint(x: 0.107, y: 0.906), CGPoint(x: 0.331, y: 0.709)
            ],
            floorLabel: "2500",
            ceilingLabel: "6000"
        ),
        ControlledAirspaceRegion(
            id: "EGPH-CTA-2",
            kind: .shelf,
            airports: ["EGPH"],
            polygonFractions: [
                CGPoint(x: 0.488, y: 0.000), CGPoint(x: 0.888, y: 0.000), CGPoint(x: 1.000, y: 0.268),
                CGPoint(x: 0.752, y: 0.481), CGPoint(x: 0.738, y: 0.545), CGPoint(x: 0.716, y: 0.604),
                CGPoint(x: 0.687, y: 0.657), CGPoint(x: 0.652, y: 0.702), CGPoint(x: 0.613, y: 0.738),
                CGPoint(x: 0.569, y: 0.763), CGPoint(x: 0.524, y: 0.778), CGPoint(x: 0.477, y: 0.781),
                CGPoint(x: 0.431, y: 0.773), CGPoint(x: 0.386, y: 0.753), CGPoint(x: 0.344, y: 0.723),
                CGPoint(x: 0.307, y: 0.683), CGPoint(x: 0.275, y: 0.634), CGPoint(x: 0.249, y: 0.578),
                CGPoint(x: 0.230, y: 0.516), CGPoint(x: 0.219, y: 0.451), CGPoint(x: 0.215, y: 0.384),
                CGPoint(x: 0.220, y: 0.317), CGPoint(x: 0.233, y: 0.252), CGPoint(x: 0.253, y: 0.192),
                CGPoint(x: 0.280, y: 0.137), CGPoint(x: 0.314, y: 0.090), CGPoint(x: 0.353, y: 0.052),
                CGPoint(x: 0.395, y: 0.023), CGPoint(x: 0.441, y: 0.006)
            ],
            floorLabel: "2500",
            ceilingLabel: "6000"
        ),
        ControlledAirspaceRegion(
            id: "EGPH-CTA-3",
            kind: .shelf,
            airports: ["EGPH"],
            polygonFractions: [
                CGPoint(x: 0.082, y: 0.000), CGPoint(x: 0.488, y: 0.000), CGPoint(x: 0.534, y: 0.006),
                CGPoint(x: 0.579, y: 0.023), CGPoint(x: 0.622, y: 0.050), CGPoint(x: 0.660, y: 0.088),
                CGPoint(x: 0.694, y: 0.134), CGPoint(x: 0.721, y: 0.188), CGPoint(x: 0.742, y: 0.248),
                CGPoint(x: 0.755, y: 0.311), CGPoint(x: 0.760, y: 0.377), CGPoint(x: 0.758, y: 0.444),
                CGPoint(x: 0.748, y: 0.509), CGPoint(x: 0.730, y: 0.570), CGPoint(x: 0.705, y: 0.626),
                CGPoint(x: 0.674, y: 0.676), CGPoint(x: 0.638, y: 0.717), CGPoint(x: 0.597, y: 0.749),
                CGPoint(x: 0.553, y: 0.770), CGPoint(x: 0.508, y: 0.780), CGPoint(x: 0.461, y: 0.780),
                CGPoint(x: 0.416, y: 0.768), CGPoint(x: 0.372, y: 0.745), CGPoint(x: 0.332, y: 0.712),
                CGPoint(x: 0.297, y: 0.669), CGPoint(x: 0.267, y: 0.619), CGPoint(x: 0.243, y: 0.562),
                CGPoint(x: 0.226, y: 0.500), CGPoint(x: 0.217, y: 0.434), CGPoint(x: 0.216, y: 0.368),
                CGPoint(x: 0.222, y: 0.302), CGPoint(x: 0.001, y: 0.497), CGPoint(x: 0.000, y: 0.375)
            ],
            floorLabel: "3500",
            ceilingLabel: "6000"
        ),
        ControlledAirspaceRegion(
            id: "EGPH-CTA-4",
            kind: .shelf,
            airports: ["EGPH"],
            polygonFractions: [
                CGPoint(x: 1.000, y: 0.268), CGPoint(x: 0.903, y: 1.000), CGPoint(x: 0.166, y: 1.000),
                CGPoint(x: 0.107, y: 0.906), CGPoint(x: 0.331, y: 0.709), CGPoint(x: 0.488, y: 0.391)
            ],
            floorLabel: "3500",
            ceilingLabel: "6000"
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
