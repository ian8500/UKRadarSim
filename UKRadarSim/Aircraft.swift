import Foundation
import CoreGraphics

enum VerticalTrend {
    case climb
    case level
    case descend
}

struct Aircraft: Identifiable {
    let id = UUID()
    var callsign: String
    var trueX: CGFloat
    var trueY: CGFloat
    var displayX: CGFloat
    var displayY: CGFloat
    var heading: Double
    var groundSpeed: Double
    var currentLevel: Int
    var selectedLevel: Int
    var trend: VerticalTrend
    var destination: String
}
