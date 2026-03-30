import Foundation
import CoreGraphics

struct PredictedAircraftState {
    let aircraftID: UUID
    let lookaheadSeconds: Double
    let projectedPosition: CGPoint
    let projectedLevel: Int
}

struct TrackIntent {
    let selectedHeading: Double
    let selectedSpeed: Int
    let selectedLevel: Int
}

struct IntentAwareTrackPredictor {
    private let headingTurnRateDegreesPerSecond: Double
    private let accelerationRateKnotsPerSecond: Double
    private let decelerationRateKnotsPerSecond: Double
    private let climbDescentRateFLPerSecond: Double
    private let integrationStepSeconds: Double
    private let performanceProvider: AircraftPerformanceProviding

    init(
        headingTurnRateDegreesPerSecond: Double = 3.0,
        accelerationRateKnotsPerSecond: Double = 2.0,
        decelerationRateKnotsPerSecond: Double = 2.0,
        climbDescentRateFLPerSecond: Double = 2.0,
        integrationStepSeconds: Double = 0.5,
        performanceProvider: AircraftPerformanceProviding = AircraftPerformanceCatalog()
    ) {
        self.headingTurnRateDegreesPerSecond = headingTurnRateDegreesPerSecond
        self.accelerationRateKnotsPerSecond = accelerationRateKnotsPerSecond
        self.decelerationRateKnotsPerSecond = decelerationRateKnotsPerSecond
        self.climbDescentRateFLPerSecond = climbDescentRateFLPerSecond
        self.integrationStepSeconds = integrationStepSeconds
        self.performanceProvider = performanceProvider
    }

    func predictedState(
        for aircraft: Aircraft,
        intent: TrackIntent,
        lookaheadSeconds: Double,
        startPosition: CGPoint
    ) -> PredictedAircraftState {
        var projectedHeading = aircraft.heading
        var projectedSpeed = Double(aircraft.groundSpeed)
        var projectedLevel = Double(aircraft.currentLevel)
        var projectedPosition = startPosition
        var elapsed: Double = 0
        let performance = performanceProvider.profile(for: aircraft.aircraftType)

        while elapsed < lookaheadSeconds {
            let dt = min(integrationStepSeconds, lookaheadSeconds - elapsed)
            let turnRate = min(headingTurnRateDegreesPerSecond, performance.maxTurnRateDegreesPerSecond)
            projectedHeading = moveAngle(
                projectedHeading,
                toward: intent.selectedHeading,
                maxDelta: dt * turnRate
            )

            if projectedSpeed < Double(intent.selectedSpeed) {
                let accelerationRate = min(accelerationRateKnotsPerSecond, performance.accelerationRateKnotsPerSecond)
                projectedSpeed = min(
                    Double(intent.selectedSpeed),
                    projectedSpeed + (dt * accelerationRate)
                )
            } else if projectedSpeed > Double(intent.selectedSpeed) {
                let decelerationRate = min(decelerationRateKnotsPerSecond, performance.decelerationRateKnotsPerSecond)
                projectedSpeed = max(
                    Double(intent.selectedSpeed),
                    projectedSpeed - (dt * decelerationRate)
                )
            }

            let levelDirection = intent.selectedLevel > Int(projectedLevel.rounded()) ? 1.0 : -1.0
            if Int(projectedLevel.rounded()) != intent.selectedLevel {
                let profileVerticalRate = levelDirection > 0
                    ? performance.climbRateFLPerSecond
                    : performance.descentRateFLPerSecond
                let verticalRate = min(climbDescentRateFLPerSecond, profileVerticalRate)
                let nextLevel = projectedLevel + (levelDirection * dt * verticalRate)
                if levelDirection > 0 {
                    projectedLevel = min(Double(intent.selectedLevel), nextLevel)
                } else {
                    projectedLevel = max(Double(intent.selectedLevel), nextLevel)
                }
            }

            let displacement = MotionProjection.displacement(
                headingDegrees: projectedHeading,
                groundSpeed: Int(projectedSpeed.rounded()),
                elapsedSeconds: CGFloat(dt)
            )
            projectedPosition = CGPoint(
                x: projectedPosition.x + displacement.dx,
                y: projectedPosition.y + displacement.dy
            )

            elapsed += dt
        }

        return PredictedAircraftState(
            aircraftID: aircraft.id,
            lookaheadSeconds: lookaheadSeconds,
            projectedPosition: projectedPosition,
            projectedLevel: Int(projectedLevel.rounded())
        )
    }

    func predictedStates(
        for aircraft: [Aircraft],
        intentByAircraftID: [UUID: TrackIntent],
        lookaheadSeconds: Double
    ) -> [PredictedAircraftState] {
        aircraft.map { item in
            predictedState(
                for: item,
                intent: intentByAircraftID[item.id] ?? TrackIntent(
                    selectedHeading: item.heading,
                    selectedSpeed: item.groundSpeed,
                    selectedLevel: item.currentLevel
                ),
                lookaheadSeconds: lookaheadSeconds,
                startPosition: CGPoint(x: item.trueX, y: item.trueY)
            )
        }
    }

    private func moveAngle(_ current: Double, toward target: Double, maxDelta: Double) -> Double {
        let delta = ((target - current + 540).truncatingRemainder(dividingBy: 360)) - 180
        let clamped = min(max(delta, -maxDelta), maxDelta)
        var adjusted = current + clamped

        if adjusted < 0 { adjusted += 360 }
        if adjusted >= 360 { adjusted -= 360 }

        return adjusted
    }
}
