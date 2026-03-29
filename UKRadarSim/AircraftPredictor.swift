import Foundation
import CoreGraphics

struct PredictedAircraftState {
    let aircraftID: UUID
    let lookaheadSeconds: Double
    let projectedPosition: CGPoint
    let projectedLevel: Int
}

struct AircraftPredictor {
    private let speedScale: CGFloat

    init(speedScale: CGFloat = 0.02) {
        self.speedScale = speedScale
    }

    func predictedState(for aircraft: Aircraft, lookaheadSeconds: Double) -> PredictedAircraftState {
        let headingRad = CGFloat(aircraft.heading * .pi / 180.0)
        let distance = CGFloat(Double(aircraft.groundSpeed) * lookaheadSeconds) * speedScale

        let projectedPosition = CGPoint(
            x: aircraft.displayX + cos(headingRad) * distance,
            y: aircraft.displayY - sin(headingRad) * distance
        )

        return PredictedAircraftState(
            aircraftID: aircraft.id,
            lookaheadSeconds: lookaheadSeconds,
            projectedPosition: projectedPosition,
            projectedLevel: aircraft.selectedLevel
        )
    }

    func predictedStates(for aircraft: [Aircraft], lookaheadSeconds: Double) -> [PredictedAircraftState] {
        aircraft.map { predictedState(for: $0, lookaheadSeconds: lookaheadSeconds) }
    }
}
