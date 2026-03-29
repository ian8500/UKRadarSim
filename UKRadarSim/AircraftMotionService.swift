import Foundation
import CoreGraphics

struct AircraftMotionConfig {
    let headingTurnRateDegreesPerSecond: Double
    let accelerationRateKnotsPerSecond: Double
    let decelerationRateKnotsPerSecond: Double
    let climbDescentRateFLPerSecond: Double

    static let `default` = AircraftMotionConfig(
        headingTurnRateDegreesPerSecond: 3.0,
        accelerationRateKnotsPerSecond: 2.0,
        decelerationRateKnotsPerSecond: 2.0,
        climbDescentRateFLPerSecond: 2.0
    )
}

struct AircraftMotionService {
    let config: AircraftMotionConfig

    init(config: AircraftMotionConfig = .default) {
        self.config = config
    }

    func applyControllerTargets(
        to aircraft: inout Aircraft,
        strip: EFPSStrip,
        dt: CGFloat,
        verticalProgress: inout Double
    ) {
        if aircraft.isInbound && strip.approachCleared && aircraft.approachCaptured {
            return
        }

        aircraft.selectedLevel = strip.selectedLevel

        let headingTarget = Double(strip.selectedHeading)
        aircraft.heading = moveAngle(
            aircraft.heading,
            toward: headingTarget,
            maxDelta: Double(dt) * config.headingTurnRateDegreesPerSecond
        )

        let speedTarget = strip.selectedSpeed
        if aircraft.groundSpeed < speedTarget {
            let increase = max(1, Int((Double(dt) * config.accelerationRateKnotsPerSecond).rounded()))
            aircraft.groundSpeed = min(speedTarget, aircraft.groundSpeed + increase)
        } else if aircraft.groundSpeed > speedTarget {
            let decrease = max(1, Int((Double(dt) * config.decelerationRateKnotsPerSecond).rounded()))
            aircraft.groundSpeed = max(speedTarget, aircraft.groundSpeed - decrease)
        }

        let levelTarget = strip.selectedLevel
        if aircraft.currentLevel != levelTarget {
            let direction = levelTarget > aircraft.currentLevel ? 1 : -1
            verticalProgress += config.climbDescentRateFLPerSecond * Double(dt)

            while verticalProgress >= 1.0, aircraft.currentLevel != levelTarget {
                aircraft.currentLevel += direction
                verticalProgress -= 1.0
            }

            aircraft.trend = aircraft.currentLevel == levelTarget
                ? .level
                : (direction > 0 ? .climb : .descend)
        } else {
            verticalProgress = 0
            aircraft.trend = .level
        }
    }

    func projectPosition(for aircraft: Aircraft, dt: CGFloat) -> CGPoint {
        MotionProjection.project(
            from: CGPoint(x: aircraft.trueX, y: aircraft.trueY),
            headingDegrees: aircraft.heading,
            groundSpeed: aircraft.groundSpeed,
            elapsedSeconds: dt
        )
    }

    func wrapIfNeeded(aircraft: inout Aircraft, wrapBounds: CGRect) {
        var didWrap = false

        if aircraft.trueX > wrapBounds.maxX {
            aircraft.trueX = wrapBounds.minX
            didWrap = true
        }
        if aircraft.trueX < wrapBounds.minX {
            aircraft.trueX = wrapBounds.maxX
            didWrap = true
        }
        if aircraft.trueY > wrapBounds.maxY {
            aircraft.trueY = wrapBounds.minY
            didWrap = true
        }
        if aircraft.trueY < wrapBounds.minY {
            aircraft.trueY = wrapBounds.maxY
            didWrap = true
        }

        if didWrap {
            aircraft.historyDots.removeAll()
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
