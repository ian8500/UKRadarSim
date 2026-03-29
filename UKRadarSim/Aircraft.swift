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
}
