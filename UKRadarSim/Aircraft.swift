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

    var heading: Double
    var groundSpeed: Int

    var currentLevel: Int
    var selectedLevel: Int
    var trend: VerticalTrend

    var destination: String
    var isInbound: Bool
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
    var selectedSpeed: Int
    var approachType: String
    var approachCleared: Bool
    var instructionLog: [String]

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
