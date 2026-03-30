import Foundation
import CoreGraphics

struct StripSyncService {
    func syncStrip(from aircraft: Aircraft, strip: inout EFPSStrip) {
        strip.currentLevel = aircraft.currentLevel
        strip.currentHeading = Int(aircraft.heading.rounded())
        strip.approachCaptured = aircraft.approachCaptured
        strip.isLanded = aircraft.isLanded
    }

    func appendRadarHistory(to aircraft: inout Aircraft, maxDots: Int = 6) {
        let previousDisplayPoint = CGPoint(x: aircraft.displayX, y: aircraft.displayY)
        aircraft.historyDots.insert(previousDisplayPoint, at: 0)
        aircraft.historyDots = Array(aircraft.historyDots.prefix(maxDots))
        aircraft.displayX = aircraft.trueX
        aircraft.displayY = aircraft.trueY
    }
}
